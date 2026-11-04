import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/repositories/employee_providers.dart';
import '../../home/presentation/widgets/manager_bottom_navigation.dart';
import '../../../data/repositories/employee_repository.dart';

/// Bộ lọc trạng thái vi phạm (ViolationView.status) và nhãn tiếng Việt.
const _statusFilters = <String, String>{
  'OPEN': 'Chờ xem xét',
  'CONFIRMED': 'Đã xác nhận',
  'DISMISSED': 'Đã bác bỏ',
  'RESOLVED': 'Đã xử lý',
  '': 'Tất cả',
};

/// Mức độ vi phạm theo RuleCatalog.Severity.
const _severityLabels = <String, String>{
  'MINOR': 'Nhẹ',
  'MAJOR': 'Nặng',
  'CRITICAL': 'Nghiêm trọng',
};

/// Xét duyệt vi phạm (quản lý, cần VIOLATION_REVIEW).
///
/// Máy chủ quyết định quyền thật. App chỉ ẩn nút khi người dùng rõ ràng không đủ quyền:
/// - Mức CRITICAL cần REWARD_APPROVE_CRITICAL (Giám đốc vận hành).
/// - Mức khác cần REWARD_APPROVE.
/// Không tự xem xét vi phạm của chính mình: máy chủ trả lỗi và app hiển thị thông báo đó.
class ManagerViolationReviewPage extends ConsumerStatefulWidget {
  const ManagerViolationReviewPage({super.key});

  @override
  ConsumerState<ManagerViolationReviewPage> createState() =>
      _ManagerViolationReviewPageState();
}

class _ManagerViolationReviewPageState
    extends ConsumerState<ManagerViolationReviewPage> {
  CurrentAccess _access = const CurrentAccess(roles: {}, permissions: {});
  bool _accessLoaded = false;

  String _status = 'OPEN';

  List<Map<String, dynamic>> _rows = [];
  final Map<int, List<Map<String, dynamic>>> _employeeExplanations = {};
  final Map<int, String> _explanationErrors = {};
  final Set<int> _loadingExplanations = {};
  int _page = 0;
  int _totalPages = 0;
  int _totalElements = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _acting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _access = await ref.read(employeeRepositoryProvider).getCurrentAccess();
    } catch (_) {
      // Không đọc được quyền: giữ quyền rỗng, màn sẽ báo không có quyền xem.
    }
    if (!mounted) return;
    setState(() => _accessLoaded = true);
    if (_access.canReviewViolations) {
      _fetch(0, replace: true);
    } else {
      setState(() => _loading = false);
    }
  }

  /// Nút xác nhận/bác bỏ theo mức độ. Máy chủ vẫn kiểm tra lại.
  bool _canDecide(String severity) => severity == 'CRITICAL'
      ? _access.canApproveCritical
      : _access.canApproveRewards;

  int _fetchSeq = 0;

  Future<void> _loadEmployeeExplanations(
    int violationId, {
    bool retry = false,
  }) async {
    if (_loadingExplanations.contains(violationId) ||
        (!retry && _employeeExplanations.containsKey(violationId))) {
      return;
    }
    setState(() {
      _loadingExplanations.add(violationId);
      _explanationErrors.remove(violationId);
    });
    try {
      final rows = await ref
          .read(employeeRepositoryProvider)
          .getViolationExplanationsForReview(violationId);
      if (!mounted) return;
      setState(() => _employeeExplanations[violationId] = rows);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _explanationErrors[violationId] = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _explanationErrors[violationId] =
            'Không tải được giải trình của nhân viên.',
      );
    } finally {
      if (mounted) setState(() => _loadingExplanations.remove(violationId));
    }
  }

  Future<void> _openEmployeeEvidence(Object? value) async {
    final uri = value is String ? Uri.tryParse(value) : null;
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      _snack('Liên kết minh chứng không hợp lệ.');
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        _snack('Không mở được minh chứng trên thiết bị này.');
      }
    } catch (_) {
      if (mounted) _snack('Không mở được minh chứng trên thiết bị này.');
    }
  }

  Future<void> _fetch(int page, {required bool replace}) async {
    final seq = ++_fetchSeq;
    setState(() {
      _error = null;
      if (replace) {
        _loading = true;
        _loadingMore = false;
      } else {
        _loadingMore = true;
      }
    });
    try {
      final data = await ref
          .read(employeeRepositoryProvider)
          .getViolations(status: _status, page: page);
      if (!mounted || seq != _fetchSeq) return;
      final items = (data['items'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      setState(() {
        _rows = replace ? items : [..._rows, ...items];
        _page = (data['page'] as num?)?.toInt() ?? page;
        _totalPages = (data['totalPages'] as num?)?.toInt() ?? 0;
        _totalElements = (data['totalElements'] as num?)?.toInt() ?? 0;
        _loading = false;
        _loadingMore = false;
      });
    } on ApiException catch (e) {
      if (!mounted || seq != _fetchSeq) return;
      setState(() {
        _error = e.message;
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted || seq != _fetchSeq) return;
      setState(() {
        _error = 'Không tải được danh sách vi phạm.';
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _selectStatus(String status) {
    if (status == _status) return;
    setState(() => _status = status);
    _fetch(0, replace: true);
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Hộp nhập văn bản. Trả về null nếu người dùng hủy.
  Future<String?> _askText({
    required String title,
    required String label,
    required bool required,
  }) => showDialog<String>(
    context: context,
    builder: (_) => _ViolationDecisionTextDialog(
      title: title,
      label: label,
      requiredInput: required,
      onInvalid: () => _snack('Vui lòng nhập lý do.'),
    ),
  );

  Future<void> _runAction(
    Future<Object> Function() action,
    String success,
  ) async {
    setState(() => _acting = true);
    try {
      await action();
      _snack(success);
      if (mounted) await _fetch(0, replace: true);
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _confirm(Map<String, dynamic> row) async {
    final id = (row['violationId'] as num?)?.toInt();
    if (id == null) return;
    final note = await _askText(
      title: 'Xác nhận vi phạm',
      label: 'Ghi chú (không bắt buộc)',
      required: false,
    );
    if (note == null || !mounted) return;
    await _runAction(
      () =>
          ref.read(employeeRepositoryProvider).confirmViolation(id, note: note),
      'Đã xác nhận vi phạm.',
    );
  }

  Future<void> _showViolationDetail(int id) async {
    try {
      final detail = await ref
          .read(employeeRepositoryProvider)
          .getViolation(id);
      if (!mounted) return;
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text(
                'Chi tiết vi phạm #$id',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              for (final entry in detail.entries)
                ListTile(
                  dense: true,
                  title: Text(entry.key),
                  subtitle: SelectableText('${entry.value ?? '—'}'),
                ),
            ],
          ),
        ),
      );
    } catch (error) {
      _snack(
        error is ApiException
            ? error.message
            : 'Không tải được chi tiết vi phạm.',
      );
    }
  }

  Future<void> _dismiss(Map<String, dynamic> row) async {
    final id = (row['violationId'] as num?)?.toInt();
    if (id == null) return;
    final reason = await _askText(
      title: 'Bác bỏ vi phạm',
      label: 'Lý do bác bỏ *',
      required: true,
    );
    if (reason == null || !mounted) return;
    await _runAction(
      () => ref
          .read(employeeRepositoryProvider)
          .dismissViolation(id, reason: reason),
      'Đã bác bỏ vi phạm.',
    );
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RouteNames.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Xét duyệt vi phạm'),
        leading: IconButton(
          tooltip: 'Quay lại',
          onPressed: _back,
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed:
                (_loading || !_accessLoaded || !_access.canReviewViolations)
                ? null
                : () => _fetch(0, replace: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: !_accessLoaded
          ? const Center(child: CircularProgressIndicator())
          : !_access.canReviewViolations
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Tài khoản này không có quyền xét duyệt vi phạm.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Row(
                    children: [
                      for (final entry in _statusFilters.entries)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(entry.value),
                            selected: _status == entry.key,
                            onSelected: _loading
                                ? null
                                : (_) => _selectStatus(entry.key),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(child: _body()),
              ],
            ),
      bottomNavigationBar: const ManagerBottomNavigation(selectedIndex: 4),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _fetch(0, replace: true),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }
    if (_rows.isEmpty) {
      return const Center(child: Text('Không có vi phạm nào trong mục này.'));
    }

    final canLoadMore = _page + 1 < _totalPages;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Hiển thị ${_rows.length} / $_totalElements vi phạm',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _error!,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            itemCount: _rows.length + (canLoadMore ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == _rows.length) {
                return Center(
                  child: _loadingMore
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(),
                        )
                      : OutlinedButton(
                          onPressed: () => _fetch(_page + 1, replace: false),
                          child: const Text('Tải thêm'),
                        ),
                );
              }
              return _row(_rows[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _row(Map<String, dynamic> row) {
    final id = (row['violationId'] as num?)?.toInt();
    final severity = _s(row['severity']);
    final status = _s(row['status']);
    final open = status == 'OPEN';
    final auto = row['autoGenerated'] == true;
    final note = _s(row['reviewNote']);
    final details = _s(row['details']);
    final allowed = _canDecide(severity);

    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _s(row['ruleName']).isEmpty
                        ? _s(row['ruleCode'])
                        : _s(row['ruleName']),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                _severityChip(severity),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${_s(row['employeeName']).isEmpty ? 'Nhân viên #${row['employeeId'] ?? '—'}' : _s(row['employeeName'])}'
              ' · ${_vnDmyHm(row['incidentAt'])}'
              '${auto ? ' · Tự động ghi nhận' : ''}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(details, style: const TextStyle(fontSize: 13)),
            ],
            if (id != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _showViolationDetail(id),
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: const Text('Xem chi tiết'),
                ),
              ),
            if (id != null) _employeeExplanationSection(id),
            if (!open) ...[
              const SizedBox(height: 6),
              Text(
                '${_statusFilters[status] ?? status}'
                '${_vnDmyHm(row['reviewedAt']) == '—' ? '' : ' · ${_vnDmyHm(row['reviewedAt'])}'}'
                '${note.isEmpty ? '' : '\nGhi chú: $note'}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
            if (open) ...[
              const SizedBox(height: 10),
              if (allowed)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _acting ? null : () => _dismiss(row),
                      child: const Text('Bác bỏ'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _acting ? null : () => _confirm(row),
                      child: const Text('Xác nhận'),
                    ),
                  ],
                )
              else
                const Text(
                  'Mức nghiêm trọng này cần Giám đốc vận hành xem xét.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _employeeExplanationSection(int violationId) => ExpansionTile(
    key: PageStorageKey('manager-violation-explanations-$violationId'),
    tilePadding: EdgeInsets.zero,
    childrenPadding: const EdgeInsets.only(bottom: 8),
    title: const Text('Giải trình của nhân viên'),
    subtitle: Text(
      '${_employeeExplanations[violationId]?.length ?? 0} lần gửi',
    ),
    onExpansionChanged: (expanded) {
      if (expanded) _loadEmployeeExplanations(violationId);
    },
    children: [_employeeExplanationContent(violationId)],
  );

  Widget _employeeExplanationContent(int violationId) {
    if (_loadingExplanations.contains(violationId)) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final error = _explanationErrors[violationId];
    if (error != null) {
      return Column(
        children: [
          Text(error),
          TextButton(
            onPressed: () =>
                _loadEmployeeExplanations(violationId, retry: true),
            child: const Text('Thử lại'),
          ),
        ],
      );
    }
    if (!_employeeExplanations.containsKey(violationId)) {
      return const SizedBox.shrink();
    }
    final rows = _employeeExplanations[violationId]!;
    if (rows.isEmpty) return const Text('Nhân viên chưa gửi giải trình.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final explanation in rows)
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
                Text(explanation['explanation']?.toString() ?? ''),
                if (explanation['submittedAt'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Đã gửi: ${_vnDmyHm(explanation['submittedAt'])}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                if ((explanation['evidenceViewUrl']?.toString() ?? '')
                    .isNotEmpty)
                  TextButton.icon(
                    onPressed: () =>
                        _openEmployeeEvidence(explanation['evidenceViewUrl']),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Mở minh chứng'),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _severityChip(String severity) {
    final color = switch (severity) {
      'CRITICAL' => AppColors.error,
      'MAJOR' => const Color(0xFFB96D17),
      _ => AppColors.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _severityLabels[severity] ?? (severity.isEmpty ? 'Không rõ' : severity),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ViolationDecisionTextDialog extends StatefulWidget {
  const _ViolationDecisionTextDialog({
    required this.title,
    required this.label,
    required this.requiredInput,
    required this.onInvalid,
  });

  final String title;
  final String label;
  final bool requiredInput;
  final VoidCallback onInvalid;

  @override
  State<_ViolationDecisionTextDialog> createState() =>
      _ViolationDecisionTextDialogState();
}

class _ViolationDecisionTextDialogState
    extends State<_ViolationDecisionTextDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      maxLines: 3,
      maxLength: 500,
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () {
          final text = _controller.text.trim();
          if (widget.requiredInput && text.isEmpty) {
            widget.onInvalid();
            return;
          }
          Navigator.pop(context, text);
        },
        child: const Text('Xác nhận'),
      ),
    ],
  );
}

// ---------- Tiện ích ----------

String _s(Object? value) => value?.toString().trim() ?? '';

const _vnOffset = Duration(hours: 7);

String _two(int value) => value.toString().padLeft(2, '0');

/// dd/MM/yyyy HH:mm theo giờ Việt Nam, bất kể múi giờ của máy. Trả về '—' nếu không đọc được.
String _vnDmyHm(Object? value) {
  final parsed = DateTime.tryParse(_s(value));
  if (parsed == null) return '—';
  final clock = parsed.toUtc().add(_vnOffset);
  return '${_two(clock.day)}/${_two(clock.month)}/${clock.year} ${_two(clock.hour)}:${_two(clock.minute)}';
}
