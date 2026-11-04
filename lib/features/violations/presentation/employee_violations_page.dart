import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/repositories/employee_providers.dart';
import '../../../shared/widgets/employee_bottom_navigation.dart';
import '../../documents/presentation/employee_documents_tab.dart';

class EmployeeViolationsPage extends ConsumerStatefulWidget {
  const EmployeeViolationsPage({
    super.key,
    this.picker = const PlatformDocumentPicker(),
  });

  final DocumentPicker picker;

  @override
  ConsumerState<EmployeeViolationsPage> createState() =>
      _EmployeeViolationsPageState();
}

class _EmployeeViolationsPageState
    extends ConsumerState<EmployeeViolationsPage> {
  List<Map<String, dynamic>> _violations = const [];
  final Map<int, List<Map<String, dynamic>>> _history = {};
  final Map<int, String> _historyErrors = {};
  final Map<int, TextEditingController> _controllers = {};
  final Map<int, PickedDocument> _pickedEvidence = {};
  final Map<int, String> _uploadedEvidenceKeys = {};
  final Set<int> _loadingHistory = {};
  bool _loading = true;
  String? _error;
  int? _submittingId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(int id) =>
      _controllers.putIfAbsent(id, TextEditingController.new);

  Future<void> _load({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final response = await ref
          .read(employeeRepositoryProvider)
          .getMyViolations();
      if (!mounted) return;
      final rows = (response['items'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      setState(() {
        _violations = rows;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is ApiException
            ? error.message
            : 'Không tải được danh sách vi phạm.';
        _loading = false;
      });
    }
  }

  int? _id(Map<String, dynamic> row) {
    final value = row['violationId'];
    return value is num ? value.toInt() : int.tryParse('$value');
  }

  Future<void> _loadHistory(int id, {bool force = false}) async {
    if (_loadingHistory.contains(id) || (!force && _history.containsKey(id))) {
      return;
    }
    setState(() {
      _loadingHistory.add(id);
      _historyErrors.remove(id);
    });
    try {
      final rows = await ref
          .read(employeeRepositoryProvider)
          .getMyViolationExplanations(id);
      if (!mounted) return;
      setState(() => _history[id] = rows);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _historyErrors[id] = error is ApiException
            ? error.message
            : 'Không tải được lịch sử giải trình.';
      });
    } finally {
      if (mounted) setState(() => _loadingHistory.remove(id));
    }
  }

  Future<void> _pickEvidence(int id) async {
    try {
      final picked = await widget.picker.pickDocument();
      if (!mounted || picked == null) return;
      if (picked.bytes.isEmpty || picked.bytes.length > 10 * 1024 * 1024) {
        _message('Tệp minh chứng phải có dung lượng từ 1 byte đến 10 MB.');
        return;
      }
      setState(() {
        _pickedEvidence[id] = picked;
        _uploadedEvidenceKeys.remove(id);
        _historyErrors.remove(id);
      });
    } catch (error) {
      if (mounted) {
        _message(
          error is ApiException
              ? error.message
              : 'Không đọc được tệp minh chứng.',
        );
      }
    }
  }

  Future<void> _submit(int id) async {
    final explanation = _controllerFor(id).text.trim();
    if (explanation.isEmpty || _submittingId != null) {
      if (explanation.isEmpty) _message('Vui lòng nhập nội dung giải trình.');
      return;
    }
    setState(() => _submittingId = id);
    try {
      var key = _uploadedEvidenceKeys[id];
      final picked = _pickedEvidence[id];
      if (picked != null && key == null) {
        key = await ref
            .read(employeeRepositoryProvider)
            .uploadDocument(
              bytes: picked.bytes,
              contentType: picked.contentType,
            );
        if (!mounted) return;
        setState(() => _uploadedEvidenceKeys[id] = key!);
      }
      await ref
          .read(employeeRepositoryProvider)
          .submitViolationExplanation(
            id,
            explanation: explanation,
            evidenceStorageKey: key,
          );
      if (!mounted) return;
      _controllerFor(id).clear();
      setState(() {
        _pickedEvidence.remove(id);
        _uploadedEvidenceKeys.remove(id);
      });
      await _loadHistory(id, force: true);
      await _load(showLoading: false);
      if (mounted) {
        _message(
          'Đã lưu giải trình. Trạng thái vi phạm vẫn do quản lý quyết định.',
        );
      }
    } catch (error) {
      if (mounted) {
        _message(
          error is ApiException
              ? error.message
              : 'Không gửi được giải trình. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _submittingId = null);
    }
  }

  Future<void> _openEvidence(Object? value) async {
    final uri = value is String ? Uri.tryParse(value) : null;
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      _message('Liên kết minh chứng không hợp lệ.');
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        _message('Không mở được minh chứng trên thiết bị này.');
      }
    } catch (_) {
      if (mounted) _message('Không mở được minh chứng trên thiết bị này.');
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  String _statusLabel(String status) => switch (status) {
    'OPEN' => 'Chờ xem xét',
    'CONFIRMED' => 'Đã xác nhận',
    'DISMISSED' => 'Đã bác bỏ',
    'RESOLVED' => 'Đã xử lý',
    _ => status.isEmpty ? 'Chưa rõ trạng thái' : status,
  };

  Color _statusColor(String status) => switch (status) {
    'OPEN' => const Color(0xFF9A6718),
    'CONFIRMED' => AppColors.error,
    'DISMISSED' || 'RESOLVED' => const Color(0xFF25804B),
    _ => AppColors.textSecondary,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Vi phạm và giải trình'),
        leading: IconButton(
          tooltip: 'Quay lại trang chủ',
          onPressed: () => context.go(RouteNames.employeeHome),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _loading ? null : () => _load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _violations.isEmpty
          ? _loadError()
          : _violations.isEmpty
          ? const Center(child: Text('Bạn chưa có vi phạm nào.'))
          : RefreshIndicator(
              onRefresh: () => _load(showLoading: false),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _violations.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) =>
                    _violationCard(_violations[index]),
              ),
            ),
      bottomNavigationBar: const EmployeeBottomNavigation(selectedIndex: 0),
    );
  }

  Widget _loadError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 42),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => _load(), child: const Text('Thử lại')),
        ],
      ),
    ),
  );

  Widget _violationCard(Map<String, dynamic> row) {
    final id = _id(row);
    final status = row['status']?.toString() ?? '';
    final open = status == 'OPEN';
    final title = (row['ruleName'] ?? row['ruleCode'] ?? 'Vi phạm').toString();
    final note = row['reviewNote']?.toString().trim() ?? '';
    final card = Card(
      key: id == null ? null : ValueKey('violation-card-$id'),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                _statusChip(status),
              ],
            ),
            const SizedBox(height: 6),
            if ((row['details']?.toString() ?? '').trim().isNotEmpty)
              Text(row['details'].toString()),
            if (row['incidentAt'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Thời điểm: ${_dateTime(row['incidentAt'])}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            if (!open && note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Ghi chú của quản lý: $note'),
              ),
            if (id != null) ...[
              ExpansionTile(
                key: PageStorageKey('violation-history-$id'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: const Text('Lịch sử giải trình'),
                subtitle: Text('${(_history[id]?.length ?? 0)} lần gửi'),
                onExpansionChanged: (expanded) {
                  if (expanded) _loadHistory(id);
                },
                children: [_historyContent(id)],
              ),
              if (open)
                _submissionForm(id)
              else
                const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: Text(
                    'Bạn không thể gửi thêm giải trình cho vi phạm đã xử lý.',
                  ),
                ),
            ],
          ],
        ),
      ),
    );
    return card;
  }

  Widget _statusChip(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _historyContent(int id) {
    if (_loadingHistory.contains(id)) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final error = _historyErrors[id];
    if (error != null) {
      return Column(
        children: [
          Text(error),
          TextButton(
            onPressed: () => _loadHistory(id, force: true),
            child: const Text('Thử lại'),
          ),
        ],
      );
    }
    if (!_history.containsKey(id)) return const SizedBox.shrink();
    final rows = _history[id]!;
    if (rows.isEmpty) return const Text('Chưa có giải trình.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in rows)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F5F1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['explanation']?.toString() ?? ''),
                if (item['submittedAt'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Đã gửi: ${_dateTime(item['submittedAt'])}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                if ((item['evidenceViewUrl']?.toString() ?? '').isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _openEvidence(item['evidenceViewUrl']),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Mở minh chứng'),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _submissionForm(int id) {
    final submitting = _submittingId == id;
    final picked = _pickedEvidence[id];
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: Key('violation-explanation-field-$id'),
            controller: _controllerFor(id),
            minLines: 2,
            maxLines: 5,
            maxLength: 2000,
            enabled: !submitting,
            decoration: const InputDecoration(
              labelText: 'Nội dung giải trình',
              border: OutlineInputBorder(),
            ),
          ),
          Row(
            children: [
              OutlinedButton.icon(
                key: Key('attach-violation-evidence-$id'),
                onPressed: submitting ? null : () => _pickEvidence(id),
                icon: const Icon(Icons.attach_file),
                label: const Text('Đính kèm minh chứng'),
              ),
              if (picked != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    picked.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Bỏ minh chứng',
                  onPressed: submitting
                      ? null
                      : () => setState(() {
                          _pickedEvidence.remove(id);
                          _uploadedEvidenceKeys.remove(id);
                        }),
                  icon: const Icon(Icons.close),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              key: Key('submit-violation-explanation-$id'),
              onPressed: submitting ? null : () => _submit(id),
              icon: submitting
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: const Text('Gửi giải trình'),
            ),
          ),
        ],
      ),
    );
  }

  String _dateTime(Object? value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return '—';
    final local = parsed.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }
}
