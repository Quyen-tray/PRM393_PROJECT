import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/repositories/employee_providers.dart';
import '../../../data/repositories/employee_repository.dart';

/// Nhãn trạng thái kỳ công theo SRS 8.5 (PeriodView.status).
const _statusLabels = <String, String>{
  'DRAFT': 'Nháp',
  'REVIEWING': 'Đang xét duyệt',
  'READY': 'Đã duyệt, chờ HR chốt',
  'FINALIZED': 'Đã chốt',
  'REOPENED': 'Đã mở lại',
};

/// Bước hiện tại của kỳ (ReadinessView.periodStatus).
const _stageLabels = <String, String>{
  'OPEN': 'Chờ quản lý xác nhận',
  'MANAGER_REVIEW': 'Đang xét duyệt',
  'HR_REVIEW': 'Chờ HR chốt',
  'APPROVED': 'Đã duyệt',
  'LOCKED': 'Đã khóa',
};

/// Loại điều kiện chặn chốt (ReadinessView.blockers[].type).
const _blockerLabels = <String, String>{
  'PENDING_ADJUSTMENT': 'Điều chỉnh công đang chờ duyệt',
  'PENDING_OVERTIME': 'Tăng ca đang chờ duyệt',
  'UNRESOLVED_EXCEPTION': 'Giải trình chưa xử lý',
  'MISSING_CHECK_OUT': 'Quên check-out',
  'MISSING_ABSENCE_REQUEST': 'Ca vắng chưa có đơn ABSENCE',
  'PENDING_ABSENCE': 'Đơn ABSENCE đang chờ duyệt',
  'REJECTED_ABSENCE': 'Đơn ABSENCE đã bị từ chối',
};

String _s(Object? value) => value?.toString() ?? '';

int _i(Object? value) => value is num ? value.toInt() : int.tryParse(_s(value)) ?? 0;

/// Chuyển yyyy-MM-dd (hoặc ISO) sang dd/MM/yyyy. Không đọc được thì giữ nguyên.
String _fmtDate(Object? raw) {
  final date = DateTime.tryParse(_s(raw));
  if (date == null) return _s(raw);
  final dd = date.day.toString().padLeft(2, '0');
  final mm = date.month.toString().padLeft(2, '0');
  return '$dd/$mm/${date.year}';
}

/// Ngày dạng yyyy-MM-dd, đúng định dạng máy chủ nhận.
String _isoDate(DateTime date) {
  final yyyy = date.year.toString().padLeft(4, '0');
  final mm = date.month.toString().padLeft(2, '0');
  final dd = date.day.toString().padLeft(2, '0');
  return '$yyyy-$mm-$dd';
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Kỳ công (quản lý, HR, giám đốc vận hành, admin). Nút thao tác hiện theo quyền và bước của kỳ.
/// Máy chủ vẫn là bên quyết định: app chỉ ẩn nút khi thiếu quyền hoặc sai bước rõ ràng.
class ManagerPayrollPage extends ConsumerStatefulWidget {
  const ManagerPayrollPage({super.key});

  @override
  ConsumerState<ManagerPayrollPage> createState() => _ManagerPayrollPageState();
}

class _ManagerPayrollPageState extends ConsumerState<ManagerPayrollPage> {
  CurrentAccess _access = const CurrentAccess(roles: {}, permissions: {});
  bool _accessLoaded = false;

  List<Map<String, dynamic>> _periods = [];
  bool _loading = true;
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
      // Không đọc được quyền: màn báo không có quyền xem.
    }
    if (!mounted) return;
    setState(() => _accessLoaded = true);
    if (_access.canViewPayroll) {
      _load();
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await ref.read(employeeRepositoryProvider).getPayrollPeriods();
      if (!mounted) return;
      setState(() {
        _periods = rows;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Không tải được danh sách kỳ công.';
        _loading = false;
      });
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RouteNames.home);
    }
  }

  Future<void> _createPeriod() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _CreatePeriodDialog(),
    );
    if (result == null || !mounted) return;
    try {
      await ref.read(employeeRepositoryProvider).createPayrollPeriod(
            periodCode: result['periodCode']!,
            startDate: result['startDate']!,
            endDate: result['endDate']!,
            note: result['note'],
          );
      if (!mounted) return;
      _showSnack(context, 'Đã tạo kỳ công.');
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(context, e.message);
    } catch (_) {
      if (!mounted) return;
      _showSnack(context, 'Không tạo được kỳ công.');
    }
  }

  void _openPeriod(Map<String, dynamic> row) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PeriodSheet(
        periodId: _i(row['periodId']),
        periodCode: _s(row['periodCode']),
        endDate: _s(row['endDate']),
        access: _access,
        onChanged: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canUse = _accessLoaded && _access.canViewPayroll;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Kỳ công'),
        leading: IconButton(
          tooltip: 'Quay lại',
          onPressed: _back,
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: (_loading || !canUse) ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: (canUse && _access.canCreatePayroll)
          ? FloatingActionButton.extended(
              onPressed: _createPeriod,
              icon: const Icon(Icons.add),
              label: const Text('Tạo kỳ'),
            )
          : null,
      body: !_accessLoaded
          ? const Center(child: CircularProgressIndicator())
          : !canUse
              ? const _CenteredMessage('Tài khoản này không có quyền xem kỳ công.')
              : _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _ErrorView(message: _error!, onRetry: _load)
                      : _periods.isEmpty
                          ? const _CenteredMessage('Chưa có kỳ công nào.')
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                                itemCount: _periods.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, index) => _PeriodCard(
                                  row: _periods[index],
                                  onTap: () => _openPeriod(_periods[index]),
                                ),
                              ),
                            ),
    );
  }
}

class _PeriodCard extends StatelessWidget {
  const _PeriodCard({required this.row, required this.onTap});

  final Map<String, dynamic> row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = _s(row['status']);
    final range = '${_fmtDate(row['startDate'])} – ${_fmtDate(row['endDate'])}';
    final managerConfirmed = _s(row['managerApprovedAt']).isNotEmpty;
    return Card(
      color: AppColors.surface,
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          _s(row['periodCode']),
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(range, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(
              [
                _statusLabels[status] ?? status,
                if (managerConfirmed) 'Quản lý đã xác nhận',
              ].join(' · '),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

/// Bảng chi tiết một kỳ: điều kiện chặn và các nút thao tác theo quyền và bước.
class _PeriodSheet extends ConsumerStatefulWidget {
  const _PeriodSheet({
    required this.periodId,
    required this.periodCode,
    required this.endDate,
    required this.access,
    required this.onChanged,
  });

  final int periodId;
  final String periodCode;
  final String endDate;
  final CurrentAccess access;
  final VoidCallback onChanged;

  @override
  ConsumerState<_PeriodSheet> createState() => _PeriodSheetState();
}

class _PeriodSheetState extends ConsumerState<_PeriodSheet> {
  late Future<Map<String, dynamic>> _readiness;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    _readiness = _fetch();
  }

  Future<Map<String, dynamic>> _fetch() =>
      ref.read(employeeRepositoryProvider).getPayrollReadiness(widget.periodId);

  void _reload() {
    setState(() => _readiness = _fetch());
  }

  /// Chạy một thao tác: khóa nút, hiện thông báo, làm mới điều kiện và danh sách cha.
  /// Thao tác trả về thông báo thành công; lỗi từ máy chủ được hiện nguyên văn.
  Future<void> _run(Future<String> Function() action) async {
    setState(() => _acting = true);
    try {
      final message = await action();
      if (!mounted) return;
      _showSnack(context, message);
      widget.onChanged();
      _reload();
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(context, e.message);
      _reload();
    } catch (_) {
      if (!mounted) return;
      _showSnack(context, 'Thao tác không thành công.');
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _confirmManager() async {
    final ok = await _confirmDialog(
      title: 'Xác nhận kỳ công',
      body: 'Xác nhận kỳ ${widget.periodCode} và chuyển cho HR chốt?',
      action: 'Xác nhận',
    );
    if (!ok) return;
    await _run(() async {
      await ref.read(employeeRepositoryProvider).managerConfirmPayroll(widget.periodId);
      return 'Đã xác nhận, chờ HR chốt.';
    });
  }

  Future<void> _generateAbsence() async {
    await _run(() async {
      final data = await ref.read(employeeRepositoryProvider).generatePayrollAbsenceRequests(widget.periodId);
      return 'Đã tạo ${_i(data['created'])} đơn ABSENCE chờ duyệt.';
    });
  }

  Future<void> _finalize() async {
    final ok = await _confirmDialog(
      title: 'Chốt kỳ công',
      body: 'Chốt kỳ ${widget.periodCode}? Sau khi chốt, chấm công trong kỳ bị khóa.',
      action: 'Chốt',
    );
    if (!ok) return;
    await _run(() async {
      await ref.read(employeeRepositoryProvider).hrFinalizePayroll(widget.periodId);
      return 'Đã chốt kỳ công.';
    });
  }

  Future<void> _reopen() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _ReasonDialog(),
    );
    if (reason == null) return;
    await _run(() async {
      await ref.read(employeeRepositoryProvider).reopenPayroll(widget.periodId, reason: reason);
      return 'Đã mở lại kỳ công.';
    });
  }

  Future<bool> _confirmDialog({
    required String title,
    required String body,
    required String action,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result == true;
  }

  bool get _ended {
    final end = DateTime.tryParse(widget.endDate);
    if (end == null) return false;
    final today = DateTime.now();
    return DateTime(end.year, end.month, end.day)
        .isBefore(DateTime(today.year, today.month, today.day));
  }

  Widget _actions(Map<String, dynamic> data) {
    final stage = _s(data['periodStatus']);
    final locked = stage == 'LOCKED';
    final canFinalize = data['canFinalize'] == true;
    final access = widget.access;

    final showConfirm = access.isStoreManager && (stage == 'OPEN' || stage == 'MANAGER_REVIEW');
    final showAbsence = access.isStoreManager && !locked;
    final showFinalize = access.canFinalizePayroll && stage == 'HR_REVIEW' && canFinalize && _ended;
    final showReopen = access.canReopenPayroll && locked;
    final waitingForEnd = access.canFinalizePayroll && stage == 'HR_REVIEW' && !_ended;

    final buttons = <Widget>[
      if (showAbsence)
        OutlinedButton(
          onPressed: _acting ? null : _generateAbsence,
          child: const Text('Tạo đơn vắng ABSENCE'),
        ),
      if (showConfirm)
        FilledButton(
          onPressed: _acting ? null : _confirmManager,
          child: const Text('Quản lý xác nhận'),
        ),
      if (showFinalize)
        FilledButton(
          onPressed: _acting ? null : _finalize,
          child: const Text('HR chốt kỳ công'),
        ),
      if (showReopen)
        OutlinedButton(
          onPressed: _acting ? null : _reopen,
          child: const Text('Mở lại kỳ'),
        ),
    ];

    if (buttons.isEmpty && !waitingForEnd) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 24),
        if (waitingForEnd)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Kỳ chưa kết thúc nên chưa chốt được.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
        for (final button in buttons) ...[
          button,
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: SingleChildScrollView(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _readiness,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                final error = snapshot.error;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    error is ApiException ? error.message : 'Không tải được điều kiện chốt.',
                    style: const TextStyle(color: AppColors.error),
                  ),
                );
              }
              final data = snapshot.data ?? const <String, dynamic>{};
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ReadinessBody(periodCode: widget.periodCode, data: data),
                  _actions(data),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ReadinessBody extends StatelessWidget {
  const _ReadinessBody({required this.periodCode, required this.data});

  final String periodCode;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final canFinalize = data['canFinalize'] == true;
    final stage = _s(data['periodStatus']);
    final blockers = (data['blockers'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kỳ công · $periodCode',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Bước hiện tại: ${_stageLabels[stage] ?? stage}',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _CountChip(label: 'Nhân viên', value: _i(data['totalEmployees'])),
            _CountChip(label: 'Ca vắng', value: _i(data['absentShifts'])),
          ],
        ),
        const Divider(height: 24),
        if (canFinalize)
          const Row(
            children: [
              Icon(Icons.check_circle_outline, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(child: Text('Không còn điều kiện chặn chốt.')),
            ],
          )
        else ...[
          Text(
            'Còn ${blockers.length} điều kiện chặn chốt:',
            style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          for (final blocker in blockers)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.error_outline, color: AppColors.error),
              title: Text(_blockerLabels[_s(blocker['type'])] ?? _s(blocker['type'])),
              trailing: Text('${_i(blocker['count'])}'),
            ),
        ],
      ],
    );
  }
}

/// Dialog tạo kỳ công. Trả về map có periodCode, startDate, endDate (yyyy-MM-dd) và note.
class _CreatePeriodDialog extends StatefulWidget {
  const _CreatePeriodDialog();

  @override
  State<_CreatePeriodDialog> createState() => _CreatePeriodDialogState();
}

class _CreatePeriodDialogState extends State<_CreatePeriodDialog> {
  final _code = TextEditingController();
  final _note = TextEditingController();
  DateTime? _start;
  DateTime? _end;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick({required bool start}) async {
    final initial = (start ? _start : _end) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  void _submit() {
    final code = _code.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Nhập mã kỳ công.');
      return;
    }
    if (_start == null || _end == null) {
      setState(() => _error = 'Chọn ngày bắt đầu và ngày kết thúc.');
      return;
    }
    if (_end!.isBefore(_start!)) {
      setState(() => _error = 'Ngày kết thúc phải sau ngày bắt đầu.');
      return;
    }
    Navigator.pop(context, {
      'periodCode': code,
      'startDate': _isoDate(_start!),
      'endDate': _isoDate(_end!),
      'note': _note.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    String label(DateTime? d) => d == null ? 'Chọn ngày' : _isoDate(d);
    return AlertDialog(
      title: const Text('Tạo kỳ công'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _code,
              maxLength: 20,
              decoration: const InputDecoration(labelText: 'Mã kỳ công', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _pick(start: true),
              child: Text('Bắt đầu: ${label(_start)}'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _pick(start: false),
              child: Text('Kết thúc: ${label(_end)}'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              maxLines: 2,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Ghi chú (không bắt buộc)', border: OutlineInputBorder()),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        FilledButton(onPressed: _submit, child: const Text('Tạo')),
      ],
    );
  }
}

/// Dialog lý do mở lại kỳ công. Lý do bắt buộc. Trả về null nếu hủy.
class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog();

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _reason.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Nhập lý do mở lại kỳ công.');
      return;
    }
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mở lại kỳ công'),
      content: TextField(
        controller: _reason,
        maxLines: 3,
        maxLength: 500,
        decoration: InputDecoration(
          labelText: 'Lý do',
          border: const OutlineInputBorder(),
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        FilledButton(onPressed: _submit, child: const Text('Mở lại')),
      ],
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      backgroundColor: AppColors.surface,
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
