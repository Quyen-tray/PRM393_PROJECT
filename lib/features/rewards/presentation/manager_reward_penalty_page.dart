import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/repositories/employee_providers.dart';
import '../../home/presentation/widgets/manager_bottom_navigation.dart';
import '../../../data/repositories/employee_repository.dart';

/// Bộ lọc trạng thái quyết định (DecisionView.status) và nhãn tiếng Việt.
const _statusFilters = <String, String>{
  'PENDING_APPROVAL': 'Chờ duyệt',
  'APPROVED': 'Đã duyệt',
  'REJECTED': 'Đã từ chối',
  'CANCELLED': 'Đã hủy',
  'APPLIED': 'Đã vào lương',
  '': 'Tất cả',
};

const _typeFilters = <String, String>{
  '': 'Tất cả',
  'REWARD': 'Thưởng',
  'PENALTY': 'Phạt',
};

const _severityLabels = <String, String>{
  'MINOR': 'Nhẹ',
  'MAJOR': 'Nặng',
  'CRITICAL': 'Nghiêm trọng',
};

/// Thưởng/phạt (quản lý). Quyền thật do máy chủ kiểm tra; app chỉ ẩn nút khi thiếu quyền rõ ràng.
///
/// Quy tắc máy chủ (RewardPenaltyService):
/// - Mức CRITICAL, hoặc số tiền từ ngưỡng của cửa hàng trở lên: cần REWARD_APPROVE_CRITICAL.
/// - Còn lại: cần REWARD_APPROVE.
/// - Người đề xuất không được tự duyệt. Không xử lý quyết định về chính mình.
/// - Quyết định đã vào lương (APPLIED) không sửa được.
///
/// App không biết ngưỡng số tiền của cửa hàng (không có trong StoreView), nên với số tiền lớn
/// máy chủ có thể từ chối; khi đó app hiển thị thông báo của máy chủ.
class ManagerRewardPenaltyPage extends ConsumerStatefulWidget {
  const ManagerRewardPenaltyPage({super.key});

  @override
  ConsumerState<ManagerRewardPenaltyPage> createState() =>
      _ManagerRewardPenaltyPageState();
}

class _ManagerRewardPenaltyPageState
    extends ConsumerState<ManagerRewardPenaltyPage> {
  CurrentAccess _access = const CurrentAccess(roles: {}, permissions: {});
  bool _accessLoaded = false;

  String _status = 'PENDING_APPROVAL';
  String _type = '';

  List<Map<String, dynamic>> _rows = [];
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
      // Không đọc được quyền: màn báo không có quyền xem.
    }
    if (!mounted) return;
    setState(() => _accessLoaded = true);
    if (_access.canViewRewards) {
      _fetch(0, replace: true);
    } else {
      setState(() => _loading = false);
    }
  }

  bool _canDecide(String severity) => severity == 'CRITICAL'
      ? _access.canApproveCritical
      : _access.canApproveRewards;

  int _fetchSeq = 0;

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
          .getDecisions(type: _type, status: _status, page: page);
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
        _error = 'Không tải được danh sách thưởng/phạt.';
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

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

  /// Hộp nhập văn bản. Trả về null nếu hủy.
  Future<String?> _askText({
    required String title,
    required String label,
    required bool required,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: _DialogControllerOwner(
          controller: controller,
          child: TextField(
            controller: controller,
            maxLines: 3,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (required && text.isEmpty) {
                _snack('Vui lòng nhập lý do.');
                return;
              }
              Navigator.pop(dialogContext, text);
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    return result;
  }

  Future<void> _approve(Map<String, dynamic> row) async {
    final id = _s(row['decisionId']);
    if (id.isEmpty) return;
    final note = await _askText(
      title: 'Duyệt quyết định',
      label: 'Ghi chú (không bắt buộc)',
      required: false,
    );
    if (note == null || !mounted) return;
    await _runAction(
      () =>
          ref.read(employeeRepositoryProvider).approveDecision(id, note: note),
      'Đã duyệt.',
    );
  }

  Future<void> _reject(Map<String, dynamic> row) async {
    final id = _s(row['decisionId']);
    if (id.isEmpty) return;
    final reason = await _askText(
      title: 'Từ chối quyết định',
      label: 'Lý do từ chối *',
      required: true,
    );
    if (reason == null || !mounted) return;
    await _runAction(
      () => ref
          .read(employeeRepositoryProvider)
          .rejectDecision(id, reason: reason),
      'Đã từ chối.',
    );
  }

  Future<void> _cancel(Map<String, dynamic> row) async {
    final id = _s(row['decisionId']);
    if (id.isEmpty) return;
    final reason = await _askText(
      title: 'Hủy quyết định',
      label: 'Lý do hủy *',
      required: true,
    );
    if (reason == null || !mounted) return;
    await _runAction(
      () => ref
          .read(employeeRepositoryProvider)
          .cancelDecision(id, reason: reason),
      'Đã hủy quyết định.',
    );
  }

  Future<void> _propose() async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _ProposeDecisionDialog(),
    );
    if (payload == null || !mounted) return;
    await _runAction(
      () => ref
          .read(employeeRepositoryProvider)
          .proposeDecision(
            decisionType: payload['decisionType'] as String,
            employeeId: payload['employeeId'] as int,
            reasonCode: payload['reasonCode'] as String,
            description: payload['description'] as String,
            amount: payload['amount'] as num?,
            effectiveDate: payload['effectiveDate'] as String?,
          ),
      'Đã gửi đề xuất, chờ duyệt.',
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
    final canUse = _accessLoaded && _access.canViewRewards;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Thưởng/phạt'),
        leading: IconButton(
          tooltip: 'Quay lại',
          onPressed: _back,
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: (_loading || !canUse)
                ? null
                : () => _fetch(0, replace: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: !_accessLoaded
          ? const Center(child: CircularProgressIndicator())
          : !canUse
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Tài khoản này không có quyền xem thưởng/phạt.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              children: [
                _filters(),
                Expanded(child: _body()),
              ],
            ),
      floatingActionButton: (canUse && _access.canProposeRewards)
          ? FloatingActionButton.extended(
              onPressed: (_loading || _acting) ? null : _propose,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Đề xuất'),
            )
          : null,
      bottomNavigationBar: const ManagerBottomNavigation(selectedIndex: 4),
    );
  }

  Widget _filters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
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
                        : (_) {
                            if (_status == entry.key) return;
                            setState(() => _status = entry.key);
                            _fetch(0, replace: true);
                          },
                  ),
                ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Row(
            children: [
              for (final entry in _typeFilters.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(entry.value),
                    selected: _type == entry.key,
                    onSelected: _loading
                        ? null
                        : (_) {
                            if (_type == entry.key) return;
                            setState(() => _type = entry.key);
                            _fetch(0, replace: true);
                          },
                  ),
                ),
            ],
          ),
        ),
      ],
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
      return const Center(
        child: Text('Không có quyết định nào trong mục này.'),
      );
    }

    final canLoadMore = _page + 1 < _totalPages;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Hiển thị ${_rows.length} / $_totalElements quyết định',
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
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
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
    final isReward = _s(row['decisionType']) == 'REWARD';
    final severity = _s(row['severity']);
    final status = _s(row['status']);
    final ruleName = _s(row['reasonName']).isEmpty
        ? _s(row['reasonCode'])
        : _s(row['reasonName']);
    final employee = _s(row['employeeName']).isEmpty
        ? 'Nhân viên #${row['employeeId'] ?? '—'}'
        : _s(row['employeeName']);
    final note = _s(row['reviewNote']);
    final allowed = _canDecide(severity);
    final pending = status == 'PENDING_APPROVAL';
    final approved = status == 'APPROVED';
    final canAct = (pending || approved) && allowed;

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
                    '${isReward ? 'Thưởng' : 'Phạt'} · $ruleName',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                _chip(_statusFilters[status] ?? status, _statusColor(status)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '$employee · ${_money(row['amount'])}'
              '${severity.isEmpty ? '' : ' · ${_severityLabels[severity] ?? severity}'}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            if (_s(row['description']).isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                _s(row['description']),
                style: const TextStyle(fontSize: 13),
              ),
            ],
            if (note.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Ghi chú: $note',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
            if (canAct) ...[
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (pending)
                    OutlinedButton(
                      onPressed: _acting ? null : () => _reject(row),
                      child: const Text('Từ chối'),
                    ),
                  if (pending)
                    FilledButton(
                      onPressed: _acting ? null : () => _approve(row),
                      child: const Text('Duyệt'),
                    ),
                  OutlinedButton(
                    onPressed: _acting ? null : () => _cancel(row),
                    child: const Text('Hủy quyết định'),
                  ),
                ],
              ),
            ] else if ((pending || approved) && !allowed) ...[
              const SizedBox(height: 10),
              Text(
                severity == 'CRITICAL'
                    ? 'Mức nghiêm trọng cần Giám đốc vận hành xử lý.'
                    : 'Bạn không có quyền duyệt quyết định này.',
                style: const TextStyle(
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

  Color _statusColor(String status) => switch (status) {
    'APPROVED' || 'APPLIED' => const Color(0xFF25804B),
    'REJECTED' => AppColors.error,
    'PENDING_APPROVAL' => const Color(0xFFB96D17),
    _ => AppColors.textSecondary,
  };

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );
}

/// Form đề xuất. Trả về payload khi xác nhận, hoặc null nếu hủy. Việc gọi API do màn cha làm.
class _ProposeDecisionDialog extends ConsumerStatefulWidget {
  const _ProposeDecisionDialog();

  @override
  ConsumerState<_ProposeDecisionDialog> createState() =>
      _ProposeDecisionDialogState();
}

class _ProposeDecisionDialogState
    extends ConsumerState<_ProposeDecisionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _search = TextEditingController();
  final _amount = TextEditingController();
  final _description = TextEditingController();

  String _type = 'REWARD';
  int? _employeeId;
  Map<String, dynamic>? _selectedEmployee;
  String? _reasonCode;
  DateTime? _effectiveDate;

  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _rules = [];
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    _loadRules();
  }

  @override
  void dispose() {
    _search.dispose();
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    try {
      final rows = await ref
          .read(employeeRepositoryProvider)
          .getEmployees(q: _search.text.trim());
      if (!mounted) return;
      setState(() {
        _employees = rows;
        _loadError = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    }
  }

  Future<void> _loadRules() async {
    final requestedType = _type;
    try {
      final rows = await ref
          .read(employeeRepositoryProvider)
          .getRuleCatalog(ruleType: requestedType);
      // Bỏ qua kết quả của loại cũ nếu người dùng đã đổi Thưởng/Phạt trong lúc chờ.
      if (!mounted || requestedType != _type) return;
      setState(() {
        _rules = rows;
        if (!rows.any((r) => _s(r['ruleCode']) == _reasonCode)) {
          _reasonCode = null;
        }
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    }
  }

  /// Danh sách nhân viên phải có cả người đã chọn, kể cả khi bộ lọc tìm kiếm đã loại họ ra.
  List<Map<String, dynamic>> get _employeeOptions {
    final selected = _selectedEmployee;
    if (selected == null) return _employees;
    final id = _intOf(selected['employeeId']);
    if (_employees.any((e) => _intOf(e['employeeId']) == id)) return _employees;
    return [selected, ..._employees];
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final amountText = _amount.text.trim();
    final amount = amountText.isEmpty ? null : num.parse(amountText);
    Navigator.pop(context, {
      'decisionType': _type,
      'employeeId': _employeeId,
      'reasonCode': _reasonCode,
      'description': _description.text.trim(),
      'amount': amount,
      'effectiveDate': _effectiveDate == null
          ? null
          : _isoDate(_effectiveDate!),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Đề xuất thưởng/phạt'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_loadError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _loadError!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              Wrap(
                spacing: 8,
                children: [
                  for (final entry in const {
                    'REWARD': 'Thưởng',
                    'PENALTY': 'Phạt',
                  }.entries)
                    ChoiceChip(
                      label: Text(entry.value),
                      selected: _type == entry.key,
                      onSelected: (_) {
                        if (_type == entry.key) return;
                        setState(() {
                          _type = entry.key;
                          _reasonCode = null;
                          _rules = [];
                        });
                        _loadRules();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _loadEmployees(),
                decoration: InputDecoration(
                  labelText: 'Tìm nhân viên',
                  hintText: 'Tên hoặc mã nhân viên, nhấn Enter',
                  isDense: true,
                  suffixIcon: IconButton(
                    tooltip: 'Tìm',
                    icon: const Icon(Icons.search),
                    onPressed: _loadEmployees,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: _employeeId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Nhân viên *'),
                items: [
                  for (final e in _employeeOptions)
                    DropdownMenuItem<int>(
                      value: _intOf(e['employeeId']),
                      child: Text(
                        '${_s(e['fullName']).isEmpty ? 'Chưa có tên' : _s(e['fullName'])}'
                        '${_s(e['employeeCode']).isEmpty ? '' : ' (${_s(e['employeeCode'])})'}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) {
                  setState(() {
                    _employeeId = value;
                    final matches = _employeeOptions.where(
                      (e) => _intOf(e['employeeId']) == value,
                    );
                    _selectedEmployee = matches.isEmpty ? null : matches.first;
                  });
                },
                validator: (value) =>
                    value == null ? 'Vui lòng chọn nhân viên.' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _reasonCode,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Lý do *'),
                items: [
                  for (final rule in _rules)
                    DropdownMenuItem<String>(
                      value: _s(rule['ruleCode']),
                      child: Text(
                        rule['defaultAmount'] == null
                            ? _s(rule['ruleName'])
                            : '${_s(rule['ruleName'])} · mặc định ${_money(rule['defaultAmount'])}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _reasonCode = value),
                validator: (value) =>
                    value == null ? 'Vui lòng chọn lý do.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Số tiền (VND)',
                  helperText: 'Để trống để dùng mức mặc định của lý do.',
                ),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return null;
                  final amount = num.tryParse(text);
                  if (amount == null) return 'Số tiền không hợp lệ.';
                  if (amount < 0 || amount > 1000000000) {
                    return 'Từ 0 đến 1.000.000.000.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _effectiveDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null && mounted) {
                    setState(() => _effectiveDate = picked);
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Ngày áp dụng',
                    helperText: 'Để trống để tính từ hôm nay.',
                    suffixIcon: _effectiveDate == null
                        ? const Icon(Icons.calendar_today_outlined, size: 18)
                        : IconButton(
                            tooltip: 'Bỏ ngày',
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () =>
                                setState(() => _effectiveDate = null),
                          ),
                  ),
                  child: Text(
                    _effectiveDate == null
                        ? 'Hôm nay'
                        : _dmyOf(_effectiveDate!),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                maxLines: 3,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Mô tả *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Vui lòng mô tả.' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Gửi đề xuất')),
      ],
    );
  }
}

// ---------- Tiện ích ----------

class _DialogControllerOwner extends StatefulWidget {
  const _DialogControllerOwner({required this.controller, required this.child});

  final TextEditingController controller;
  final Widget child;

  @override
  State<_DialogControllerOwner> createState() => _DialogControllerOwnerState();
}

class _DialogControllerOwnerState extends State<_DialogControllerOwner> {
  @override
  Widget build(BuildContext context) => widget.child;

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }
}

String _s(Object? value) => value?.toString().trim() ?? '';

int? _intOf(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(_s(value));
}

/// Số tiền dạng 50.000 ₫ (dấu chấm ngăn cách nhóm ba chữ số).
String _money(Object? value) {
  final number = value is num ? value : num.tryParse(_s(value));
  if (number == null) return '—';
  final digits = number.round().abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return '${number < 0 ? '-' : ''}$buffer ₫';
}

String _two(int value) => value.toString().padLeft(2, '0');

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${_two(date.month)}-${_two(date.day)}';

String _dmyOf(DateTime date) =>
    '${_two(date.day)}/${_two(date.month)}/${date.year}';
