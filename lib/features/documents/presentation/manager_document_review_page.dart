import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/repositories/employee_providers.dart';

class ManagerDocumentReviewPage extends ConsumerStatefulWidget {
  const ManagerDocumentReviewPage({super.key});

  @override
  ConsumerState<ManagerDocumentReviewPage> createState() =>
      _ManagerDocumentReviewPageState();
}

class _ManagerDocumentReviewPageState
    extends ConsumerState<ManagerDocumentReviewPage> {
  List<Map<String, dynamic>> _pending = const [];
  bool _loading = true;
  bool _canReview = false;
  String? _error;
  int? _busyDocumentId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(employeeRepositoryProvider);
      final access = await repo.getCurrentAccess();
      if (!access.canReviewDocuments) {
        if (mounted) {
          setState(() {
            _canReview = false;
            _pending = const [];
          });
        }
        return;
      }
      final pending = await repo.getPendingDocuments();
      if (!mounted) return;
      setState(() {
        _canReview = true;
        _pending = pending;
      });
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _errorMessage(Object error) => error is ApiException
      ? error.message
      : 'Không tải hoặc xử lý được hàng đợi hồ sơ.';

  int? _documentId(Map<String, dynamic> document) {
    final value = document['documentId'];
    return value is num ? value.toInt() : int.tryParse('$value');
  }

  String _typeName(Map<String, dynamic> document) {
    final type = document['documentType'];
    return type is Map ? (type['documentName'] ?? 'Hồ sơ').toString() : 'Hồ sơ';
  }

  Future<void> _showDocument(Map<String, dynamic> document) async {
    final id = _documentId(document);
    if (id == null) return;
    setState(() => _busyDocumentId = id);
    try {
      final detail = await ref.read(employeeRepositoryProvider).getDocument(id);
      if (!mounted) return;
      setState(() => _busyDocumentId = null);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          final viewUrl = detail['viewUrl']?.toString();
          return AlertDialog(
            title: Text(_typeName(detail)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nhân viên: ${(detail['employeeName'] ?? detail['employeeId'] ?? '—').toString()}',
                ),
                const SizedBox(height: 6),
                Text('Tệp: ${(detail['fileName'] ?? '—').toString()}'),
                const SizedBox(height: 12),
                if (viewUrl != null && viewUrl.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => _openSignedFile(viewUrl),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Mở tệp'),
                  )
                else
                  const Text('Không có liên kết xem tệp.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Đóng'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      if (mounted) _showMessage(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _busyDocumentId = null);
    }
  }

  Future<void> _openSignedFile(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) {
      _showMessage('Liên kết xem tệp không hợp lệ.');
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        _showMessage('Không mở được tệp trên thiết bị này.');
      }
    } catch (_) {
      if (mounted) _showMessage('Không mở được tệp trên thiết bị này.');
    }
  }

  Future<void> _approve(Map<String, dynamic> document) async {
    final id = _documentId(document);
    if (id == null || _busyDocumentId != null) return;
    setState(() {
      _busyDocumentId = id;
      _error = null;
    });
    try {
      final result = await ref
          .read(employeeRepositoryProvider)
          .approveDocument(id);
      await _load();
      if (!mounted) return;
      _showMessage(
        'Đã lưu kết quả: ${(result['reviewStatus'] ?? 'APPROVED').toString()}.',
      );
    } catch (error) {
      if (mounted) _showMessage(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _busyDocumentId = null);
    }
  }

  Future<void> _reject(Map<String, dynamic> document) async {
    final id = _documentId(document);
    if (id == null || _busyDocumentId != null) return;
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => const _RejectDocumentDialog(),
    );
    if (!mounted || reason == null || reason.trim().isEmpty) return;
    setState(() {
      _busyDocumentId = id;
      _error = null;
    });
    try {
      final result = await ref
          .read(employeeRepositoryProvider)
          .rejectDocument(documentId: id, reason: reason.trim());
      await _load();
      if (!mounted) return;
      _showMessage(
        'Đã lưu kết quả: ${(result['reviewStatus'] ?? 'REJECTED').toString()}.',
      );
    } catch (error) {
      if (mounted) _showMessage(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _busyDocumentId = null);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Duyệt hồ sơ'),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : !_canReview
            ? const _ReviewState(
                icon: Icons.lock_outline,
                message: 'Tài khoản chưa được cấp quyền duyệt hồ sơ.',
              )
            : _error != null
            ? _ReviewState(
                icon: Icons.cloud_off_outlined,
                message: _error!,
                action: FilledButton(
                  onPressed: _load,
                  child: const Text('Thử lại'),
                ),
              )
            : _pending.isEmpty
            ? const _ReviewState(
                icon: Icons.task_alt,
                message: 'Không có hồ sơ nào đang chờ duyệt.',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _pending.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _pendingCard(_pending[index]),
              ),
      ),
    );
  }

  Widget _pendingCard(Map<String, dynamic> document) {
    final id = _documentId(document);
    final busy = id != null && id == _busyDocumentId;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _typeName(document),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Nhân viên: ${(document['employeeName'] ?? document['employeeId'] ?? '—').toString()}',
            ),
            Text('Tệp: ${(document['fileName'] ?? '—').toString()}'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : () => _showDocument(document),
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.visibility_outlined),
                  label: const Text('Xem hồ sơ'),
                ),
                FilledButton.tonalIcon(
                  onPressed: busy ? null : () => _approve(document),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Duyệt'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => _reject(document),
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Từ chối'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewState extends StatelessWidget {
  const _ReviewState({required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    ),
  );
}

class _RejectDocumentDialog extends StatefulWidget {
  const _RejectDocumentDialog();

  @override
  State<_RejectDocumentDialog> createState() => _RejectDocumentDialogState();
}

class _RejectDocumentDialogState extends State<_RejectDocumentDialog> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Từ chối hồ sơ'),
    content: TextField(
      key: const Key('document-rejection-reason'),
      controller: _reasonController,
      autofocus: true,
      maxLength: 500,
      maxLines: 3,
      decoration: const InputDecoration(labelText: 'Lý do từ chối'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () {
          final value = _reasonController.text.trim();
          if (value.isNotEmpty) Navigator.pop(context, value);
        },
        child: const Text('Gửi từ chối'),
      ),
    ],
  );
}
