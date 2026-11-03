import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/repositories/employee_providers.dart';

const _maximumDocumentBytes = 10 * 1024 * 1024;

@immutable
class PickedDocument {
  const PickedDocument({
    required this.name,
    required this.contentType,
    required this.bytes,
  });

  final String name;
  final String contentType;
  final Uint8List bytes;
}

abstract interface class DocumentPicker {
  Future<PickedDocument?> pickDocument();
}

class PlatformDocumentPicker implements DocumentPicker {
  const PlatformDocumentPicker();

  @override
  Future<PickedDocument?> pickDocument() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );
    if (file == null) return null;

    final length = await file.length();
    if (length == null) {
      throw const ApiException(
        message: 'Không đọc được dung lượng tệp đã chọn.',
      );
    }
    if (length == 0 || length > _maximumDocumentBytes) {
      throw const ApiException(
        message: 'Tệp phải có dung lượng từ 1 byte đến 10 MB.',
      );
    }

    final bytes = await file.readAsBytes();
    if (bytes.length != length) {
      throw const ApiException(
        message: 'Không đọc đủ dữ liệu của tệp đã chọn. Vui lòng chọn lại.',
      );
    }
    final extension = (file.extension ?? '').toLowerCase();
    final contentType = switch (extension) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => throw const ApiException(
        message: 'Chỉ nhận PDF, JPEG, PNG hoặc WebP.',
      ),
    };
    return PickedDocument(
      name: file.name,
      contentType: contentType,
      bytes: bytes,
    );
  }
}

class EmployeeDocumentsTab extends ConsumerStatefulWidget {
  const EmployeeDocumentsTab({
    super.key,
    this.picker = const PlatformDocumentPicker(),
  });

  final DocumentPicker picker;

  @override
  ConsumerState<EmployeeDocumentsTab> createState() =>
      _EmployeeDocumentsTabState();
}

class _EmployeeDocumentsTabState extends ConsumerState<EmployeeDocumentsTab> {
  Map<String, dynamic>? _catalog;
  List<Map<String, dynamic>> _history = const [];
  bool _loading = true;
  String? _error;
  int? _submittingTypeId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final repo = ref.read(employeeRepositoryProvider);
      final results = await Future.wait<Object>([
        repo.getMyDocumentCatalog(),
        repo.getMyDocuments(),
      ]);
      if (!mounted) return;
      setState(() {
        _catalog = results[0] as Map<String, dynamic>;
        _history = results[1] as List<Map<String, dynamic>>;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted && showLoading) setState(() => _loading = false);
    }
  }

  Future<void> _submit(Map<String, dynamic> item) async {
    final typeId = _asInt(item['documentTypeId']);
    if (typeId == null ||
        item['canSubmit'] != true ||
        _submittingTypeId != null) {
      return;
    }
    setState(() {
      _submittingTypeId = typeId;
      _error = null;
    });
    try {
      final file = await widget.picker.pickDocument();
      if (!mounted || file == null) return;
      if (file.bytes.isEmpty || file.bytes.length > _maximumDocumentBytes) {
        throw const ApiException(
          message: 'Tệp phải có dung lượng từ 1 byte đến 10 MB.',
        );
      }

      final repo = ref.read(employeeRepositoryProvider);
      final storageKey = await repo.uploadDocument(
        bytes: file.bytes,
        contentType: file.contentType,
      );
      final result = await repo.submitDocument(
        documentTypeId: typeId,
        storageKey: storageKey,
      );
      await _load(showLoading: false);
      if (!mounted) return;
      final status = _statusLabel(result['reviewStatus']?.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã gửi hồ sơ. Trạng thái: $status.')),
      );
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _submittingTypeId = null);
    }
  }

  String _errorMessage(Object error) => error is ApiException
      ? error.message
      : 'Không xử lý được hồ sơ. Vui lòng thử lại.';

  int? _asInt(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value');

  String _statusLabel(String? status) => switch (status) {
    'PENDING' => 'Đang chờ duyệt',
    'APPROVED' => 'Đã duyệt',
    'REJECTED' => 'Bị từ chối',
    'EXPIRED' => 'Hết hạn',
    _ => 'Chưa nộp',
  };

  List<Map<String, dynamic>> _asMapList(Object? value) => value is List
      ? value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
      : const [];

  int? _historyTypeId(Map<String, dynamic> item) {
    final type = item['documentType'];
    return type is Map ? _asInt(type['documentTypeId']) : null;
  }

  List<Map<String, dynamic>> _historyFor(int typeId) =>
      _history.where((item) => _historyTypeId(item) == typeId).toList();

  @override
  Widget build(BuildContext context) {
    if (_loading && _catalog == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null && _catalog == null) {
      return _StateMessage(
        icon: Icons.cloud_off_outlined,
        message: _error!,
        actionLabel: 'Thử lại',
        onAction: _load,
      );
    }

    final items = _asMapList(_catalog?['documents']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Hồ sơ theo chức danh',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          _catalog?['asOfDate'] == null
              ? 'Trạng thái và yêu cầu hồ sơ được tải từ máy chủ.'
              : 'Yêu cầu hồ sơ áp dụng ngày ${_catalog!['asOfDate']}.',
          style: const TextStyle(color: Color(0xFF68635D), fontSize: 12),
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          const _StateMessage(
            icon: Icons.folder_open_outlined,
            message: 'Hiện chưa có loại hồ sơ đang hoạt động.',
          )
        else
          for (final item in items) _documentTypeCard(item),
        if (_history.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Lịch sử đã nộp',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          for (final document in _history) _historyCard(document),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Tải lại'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _documentTypeCard(Map<String, dynamic> item) {
    final typeId = _asInt(item['documentTypeId']);
    final status = item['latestStatus']?.toString();
    final ownHistory = typeId == null
        ? const <Map<String, dynamic>>[]
        : _historyFor(typeId);
    final rejection = status == 'REJECTED'
        ? ownHistory
              .where((record) => record['reviewStatus'] == 'REJECTED')
              .map((record) => record['rejectionReason']?.toString())
              .whereType<String>()
              .firstOrNull
        : null;
    final canSubmit = item['canSubmit'] == true;
    final busy = typeId != null && _submittingTypeId == typeId;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.description_outlined,
                  color: Color(0xFF8A5032),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (item['documentName'] ?? 'Hồ sơ').toString(),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['required'] == true ? 'Bắt buộc' : 'Tùy chọn',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF68635D),
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusChip(label: _statusLabel(status), status: status),
              ],
            ),
            if (item['blockReason'] is String &&
                (item['blockReason'] as String).isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                item['blockReason'].toString(),
                style: const TextStyle(fontSize: 12, color: Color(0xFF68635D)),
              ),
            ],
            if (rejection != null && rejection.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Lý do từ chối: $rejection',
                style: const TextStyle(fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: canSubmit && !busy ? () => _submit(item) : null,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file_outlined),
                label: Text(busy ? 'Đang gửi...' : 'Nộp hồ sơ'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyCard(Map<String, dynamic> item) {
    final type = item['documentType'];
    final name = type is Map ? type['documentName']?.toString() : null;
    final status = item['reviewStatus']?.toString();
    final reason = item['rejectionReason']?.toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.history),
        title: Text(
          name?.isNotEmpty == true
              ? name!
              : (item['fileName'] ?? 'Hồ sơ').toString(),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tệp: ${(item['fileName'] ?? '—').toString()}'),
            if (reason?.isNotEmpty == true) Text('Lý do từ chối: $reason'),
          ],
        ),
        trailing: _StatusChip(label: _statusLabel(status), status: status),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.status});

  final String label;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'APPROVED' => const Color(0xFF23804A),
      'REJECTED' || 'EXPIRED' => const Color(0xFFB64B42),
      'PENDING' => const Color(0xFF9A6A13),
      _ => const Color(0xFF68635D),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 32, color: const Color(0xFF8A5032)),
        const SizedBox(height: 8),
        Text(message, textAlign: TextAlign.center),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    ),
  );
}
