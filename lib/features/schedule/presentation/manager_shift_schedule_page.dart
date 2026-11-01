import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/repositories/employee_providers.dart';
import '../../../data/repositories/employee_repository.dart';
import '../../home/presentation/widgets/manager_more_menu.dart';

const _borderColor = Color(0xFFEDE8E3);
const _morningColor = Color(0xFFE4F4D7);
const _morningText = Color(0xFF287A38);
const _afternoonColor = Color(0xFFFFE8C2);
const _afternoonText = Color(0xFF98600B);

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Tuần bắt đầu thứ ba (giữ nguyên cách tính của bản demo).
DateTime _tuesdayOnOrBefore(DateTime date) {
  final daysSinceTuesday = (date.weekday - 2 + 7) % 7;
  return date.subtract(Duration(days: daysSinceTuesday));
}

/// "08:00:00" -> "08:00".
String _hhmm(Object? value) {
  final text = value?.toString() ?? '';
  return text.length >= 5 ? text.substring(0, 5) : '--:--';
}

/// Một ca đã phân cho nhân viên, từ GET /shift-assignments.
class _Assignment {
  const _Assignment({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.workDate,
    required this.shiftId,
    required this.shiftName,
    required this.startLabel,
    required this.endLabel,
    required this.status,
    required this.note,
    required this.attendanceId,
  });

  /// Bỏ qua bản ghi thiếu mã ca hoặc mã nhân viên thay vì làm app lỗi khi ép kiểu.
  static _Assignment? tryFromMap(Map<String, dynamic> row) {
    if (row['assignmentId'] is! num || row['employeeId'] is! num) return null;
    return _Assignment.fromMap(row);
  }

  factory _Assignment.fromMap(Map<String, dynamic> row) {
    final shift = row['workShift'] is Map
        ? Map<String, dynamic>.from(row['workShift'] as Map)
        : <String, dynamic>{};
    final workDate = DateTime.tryParse('${row['workDate']}') ?? DateTime.now();
    return _Assignment(
      id: (row['assignmentId'] as num).toInt(),
      employeeId: (row['employeeId'] as num).toInt(),
      employeeName: (row['employeeName'] ?? 'Mã ${row['employeeId']}').toString(),
      workDate: _dateOnly(workDate),
      shiftId: (shift['shiftId'] as num?)?.toInt(),
      shiftName: (shift['shiftName'] ?? 'Ca làm').toString(),
      startLabel: _hhmm(shift['startTime']),
      endLabel: _hhmm(shift['endTime']),
      status: (row['status'] ?? '').toString(),
      note: row['note']?.toString(),
      attendanceId: (row['attendanceId'] as num?)?.toInt(),
    );
  }

  final int id;
  final int employeeId;
  final String employeeName;
  final DateTime workDate;
  final int? shiftId;
  final String shiftName;
  final String startLabel;
  final String endLabel;
  final String status;
  final String? note;
  final int? attendanceId;

  bool get isCancelled => status == 'CANCELLED';
  bool get isMorning => (int.tryParse(startLabel.split(':').first) ?? 0) < 12;
  bool get hasAttendance => attendanceId != null;
}

enum _ScheduleView { week, month }

class ManagerShiftSchedulePage extends ConsumerStatefulWidget {
  const ManagerShiftSchedulePage({super.key});

  @override
  ConsumerState<ManagerShiftSchedulePage> createState() => _ManagerShiftSchedulePageState();
}

class _ManagerShiftSchedulePageState extends ConsumerState<ManagerShiftSchedulePage> {
  late DateTime _anchorDate;
  late DateTime _selectedDate;
  _ScheduleView _view = _ScheduleView.week;

  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _shifts = [];
  List<_Assignment> _assignments = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final today = _dateOnly(DateTime.now());
    _selectedDate = today;
    _anchorDate = _tuesdayOnOrBefore(today);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  /// Khoảng ngày đang hiển thị: 7 ngày của tuần, hoặc cả tháng.
  ({DateTime start, DateTime end}) get _range {
    if (_view == _ScheduleView.week) {
      return (start: _anchorDate, end: _anchorDate.add(const Duration(days: 6)));
    }
    return (
      start: DateTime(_anchorDate.year, _anchorDate.month, 1),
      end: DateTime(_anchorDate.year, _anchorDate.month + 1, 0),
    );
  }

  List<DateTime> get _weekDays =>
      List.generate(7, (index) => _anchorDate.add(Duration(days: index)));

  Future<List<Map<String, dynamic>>> _allActiveEmployees(EmployeeRepository repo) async {
    final all = <Map<String, dynamic>>[];
    for (var page = 0; page < 20; page++) {
      final items = await repo.getEmployees(status: 'ACTIVE', page: page);
      all.addAll(items);
      if (items.length < 50) break;
    }
    return all;
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(employeeRepositoryProvider);
      final range = _range;
      final results = await Future.wait<Object>([
        _allActiveEmployees(repo),
        repo.getWorkShifts(),
        repo.getShiftAssignments(from: _isoDate(range.start), to: _isoDate(range.end)),
      ]);
      if (!mounted) return;
      setState(() {
        _employees = results[0] as List<Map<String, dynamic>>;
        _shifts = results[1] as List<Map<String, dynamic>>;
        _assignments = (results[2] as List<Map<String, dynamic>>)
            .map(_Assignment.tryFromMap)
            .whereType<_Assignment>()
            .where((item) => !item.isCancelled)
            .toList();
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error =
            error is ApiException ? error.message : 'Không tải được lịch phân ca. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeView(_ScheduleView view) {
    setState(() {
      _view = view;
      if (view == _ScheduleView.month) {
        _selectedDate = _anchorDate;
      } else {
        _anchorDate = _tuesdayOnOrBefore(_selectedDate);
      }
    });
    _load();
  }

  void _changePeriod(int direction) {
    setState(() {
      if (_view == _ScheduleView.week) {
        _anchorDate = _anchorDate.add(Duration(days: 7 * direction));
        _selectedDate = _anchorDate;
      } else {
        _anchorDate = DateTime(_anchorDate.year, _anchorDate.month + direction, 13);
        _selectedDate = DateTime(_anchorDate.year, _anchorDate.month, 1);
      }
    });
    _load();
  }

  Map<String, _Assignment> get _cellIndex => {
        for (final item in _assignments) '${item.employeeId}|${_isoDate(item.workDate)}': item,
      };

  List<_Assignment> _assignmentsOn(DateTime date) => _assignments
      .where((item) => _sameDay(item.workDate, date))
      .toList()
    ..sort((a, b) => a.startLabel.compareTo(b.startLabel));

  Future<void> _openSheet({_Assignment? existing, int? employeeId, DateTime? date}) async {
    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _AssignmentSheet(
        employees: _employees,
        shifts: _shifts,
        existing: existing,
        initialEmployeeId: employeeId ?? existing?.employeeId,
        initialDate: date ?? existing?.workDate ?? _selectedDate,
      ),
    );
    if (message != null && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lịch phân ca'),
        leading: IconButton(
          tooltip: 'Quay lại tổng quan',
          onPressed: () => context.go(RouteNames.home),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading && _employees.isEmpty && _assignments.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _employees.isEmpty
                ? _ErrorState(message: _error!, onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                      children: [
                        _WeekSelector(
                          view: _view,
                          anchorDate: _anchorDate,
                          onViewChanged: _changeView,
                          onPeriodChanged: _changePeriod,
                        ),
                        const SizedBox(height: 14),
                        if (_error != null) ...[
                          Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                          const SizedBox(height: 8),
                        ],
                        if (_view == _ScheduleView.week) ...[
                          Text(
                            'Nhân viên theo ca · ${_employees.length} nhân viên',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (_employees.isEmpty)
                            const _EmptyNote(message: 'Chưa có nhân viên đang làm việc.')
                          else
                            _RosterTable(
                              days: _weekDays,
                              employees: _employees,
                              cellFor: (employeeId, date) =>
                                  _cellIndex['$employeeId|${_isoDate(date)}'],
                              onCellTap: (employeeId, date, existing) => _openSheet(
                                existing: existing,
                                employeeId: employeeId,
                                date: date,
                              ),
                            ),
                          const SizedBox(height: 12),
                          const _RosterLegend(),
                        ] else ...[
                          _MonthCalendar(
                            anchorDate: _anchorDate,
                            selectedDate: _selectedDate,
                            countOn: (date) => _assignmentsOn(date).length,
                            onDateSelected: (date) => setState(() => _selectedDate = date),
                          ),
                          const SizedBox(height: 16),
                          _SelectedDayRoster(
                            date: _selectedDate,
                            items: _assignmentsOn(_selectedDate),
                            onTap: (item) => _openSheet(existing: item),
                          ),
                        ],
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () => _openSheet(),
                          icon: const Icon(Icons.add),
                          label: const Text('Tạo lịch mới'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 2,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Tổng quan',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Nhân viên',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Lịch',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check),
            label: 'Duyệt',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'Khác',
          ),
        ],
        onDestinationSelected: (index) {
          if (index == 0) context.go(RouteNames.home);
          if (index == 1) context.go(RouteNames.managerEmployees);
          if (index == 3) context.go(RouteNames.managerApprovals);
          if (index == 4) showManagerMoreMenu(context);
        },
      ),
    );
  }
}

/// Sheet tạo mới hoặc sửa một ca. Đóng với một thông báo (String) khi có thay đổi được lưu.
class _AssignmentSheet extends ConsumerStatefulWidget {
  const _AssignmentSheet({
    required this.employees,
    required this.shifts,
    required this.existing,
    required this.initialEmployeeId,
    required this.initialDate,
  });

  final List<Map<String, dynamic>> employees;
  final List<Map<String, dynamic>> shifts;
  final _Assignment? existing;
  final int? initialEmployeeId;
  final DateTime initialDate;

  @override
  ConsumerState<_AssignmentSheet> createState() => _AssignmentSheetState();
}

class _AssignmentSheetState extends ConsumerState<_AssignmentSheet> {
  late int? _employeeId = widget.initialEmployeeId;
  late DateTime _date = _dateOnly(widget.initialDate);
  late int? _shiftId = widget.existing?.shiftId;
  late final TextEditingController _note = TextEditingController(text: widget.existing?.note ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.existing != null;

  /// Nhân viên trong danh sách; nếu ca đang sửa thuộc nhân viên không còn ACTIVE thì vẫn giữ để hiển thị.
  List<Map<String, dynamic>> get _employeeOptions {
    final options = [...widget.employees];
    final current = widget.existing;
    if (current != null && options.every((e) => (e['employeeId'] as num?)?.toInt() != current.employeeId)) {
      options.add({'employeeId': current.employeeId, 'fullName': current.employeeName});
    }
    return options;
  }

  /// Ca đang dùng luôn có trong danh sách, kể cả khi đã ngừng; ca ngừng khác thì ẩn.
  List<Map<String, dynamic>> get _shiftOptions => widget.shifts
      .where((shift) => shift['isActive'] != false || (shift['shiftId'] as num?)?.toInt() == _shiftId)
      .toList();

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _date = _dateOnly(picked));
  }

  Future<void> _save() async {
    final employeeId = _employeeId;
    final shiftId = _shiftId;
    if (employeeId == null || shiftId == null) {
      setState(() => _error = 'Chọn nhân viên và ca làm.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = ref.read(employeeRepositoryProvider);
    try {
      final existing = widget.existing;
      if (existing == null) {
        await repo.createShiftAssignment(
          employeeId: employeeId,
          workShiftId: shiftId,
          workDate: _isoDate(_date),
          note: _note.text.trim(),
        );
        if (mounted) Navigator.pop(context, 'Đã tạo ca làm.');
      } else {
        await repo.updateShiftAssignment(
          existing.id,
          workShiftId: shiftId,
          workDate: _isoDate(_date),
          note: _note.text.trim(),
        );
        if (mounted) Navigator.pop(context, 'Đã cập nhật ca làm.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is ApiException ? error.message : 'Không lưu được ca làm.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _cancelAssignment() async {
    final existing = widget.existing;
    if (existing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hủy ca làm?'),
        content: Text('Hủy ca ${existing.shiftName} của ${existing.employeeName} ngày ${_isoDate(existing.workDate)}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Không')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Hủy ca')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(employeeRepositoryProvider).cancelShiftAssignment(existing.id);
      if (mounted) Navigator.pop(context, 'Đã hủy ca làm.');
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is ApiException ? error.message : 'Không hủy được ca làm.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    final canCancel = existing != null && !existing.hasAttendance;
    final noShifts = _shiftOptions.isEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing ? 'Sửa ca làm' : 'Tạo lịch phân ca',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
            ),
            if (existing != null && existing.hasAttendance)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Ca đã có bản ghi chấm công nên không thể hủy.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: _employeeId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Nhân viên', border: OutlineInputBorder()),
              items: [
                for (final employee in _employeeOptions)
                  DropdownMenuItem(
                    value: (employee['employeeId'] as num).toInt(),
                    child: Text('${employee['fullName'] ?? 'Nhân viên'} · ${employee['employeeCode'] ?? ''}'),
                  ),
              ],
              // Đổi nhân viên không được hỗ trợ khi sửa ca; muốn đổi thì hủy và tạo lại.
              onChanged: _isEditing ? null : (value) => setState(() => _employeeId = value),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.event_outlined),
              label: Align(
                alignment: Alignment.centerLeft,
                child: Text('Ngày làm việc: ${_date.day}/${_date.month}/${_date.year}'),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _shiftId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Ca làm việc', border: OutlineInputBorder()),
              items: [
                for (final shift in _shiftOptions)
                  DropdownMenuItem(
                    value: (shift['shiftId'] as num).toInt(),
                    child: Text(
                      '${shift['shiftName'] ?? 'Ca'} · ${_hhmm(shift['startTime'])}–${_hhmm(shift['endTime'])}'
                      '${shift['isActive'] == false ? ' (đã ngừng)' : ''}',
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _shiftId = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLength: 500,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Ghi chú (không bắt buộc)', border: OutlineInputBorder()),
            ),
            if (noShifts)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Cửa hàng chưa có ca làm nào.', style: TextStyle(color: AppColors.error, fontSize: 12)),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving || noShifts ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: _saving
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(_isEditing ? 'Lưu thay đổi' : 'Tạo ca làm'),
            ),
            if (_isEditing && canCancel) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _saving ? null : _cancelAssignment,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: AppColors.error,
                ),
                child: const Text('Hủy ca này'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeekSelector extends StatelessWidget {
  const _WeekSelector({
    required this.view,
    required this.anchorDate,
    required this.onViewChanged,
    required this.onPeriodChanged,
  });

  final _ScheduleView view;
  final DateTime anchorDate;
  final ValueChanged<_ScheduleView> onViewChanged;
  final ValueChanged<int> onPeriodChanged;

  String get _periodLabel {
    if (view == _ScheduleView.month) {
      return 'Tháng ${anchorDate.month}/${anchorDate.year}';
    }
    final endDate = anchorDate.add(const Duration(days: 6));
    if (anchorDate.month == endDate.month) {
      return 'Tuần ${anchorDate.day} - ${endDate.day}/${endDate.month}/${endDate.year}';
    }
    return 'Tuần ${anchorDate.day}/${anchorDate.month} - '
        '${endDate.day}/${endDate.month}/${endDate.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SegmentedButton<_ScheduleView>(
          segments: const [
            ButtonSegment(value: _ScheduleView.week, label: Text('Tuần')),
            ButtonSegment(value: _ScheduleView.month, label: Text('Tháng')),
          ],
          selected: {view},
          onSelectionChanged: (selection) => onViewChanged(selection.first),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              tooltip: view == _ScheduleView.week ? 'Tuần trước' : 'Tháng trước',
              onPressed: () => onPeriodChanged(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              _periodLabel,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
            ),
            IconButton(
              tooltip: view == _ScheduleView.week ? 'Tuần sau' : 'Tháng sau',
              onPressed: () => onPeriodChanged(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(message, style: const TextStyle(color: AppColors.textSecondary)),
        ),
      );
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.anchorDate,
    required this.selectedDate,
    required this.countOn,
    required this.onDateSelected,
  });

  final DateTime anchorDate;
  final DateTime selectedDate;
  final int Function(DateTime date) countOn;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final firstDate = DateTime(anchorDate.year, anchorDate.month, 1);
    final daysInMonth = DateTime(anchorDate.year, anchorDate.month + 1, 0).day;
    final leadingCells = firstDate.weekday - 1;
    final totalCells = ((leadingCells + daysInMonth + 6) ~/ 7) * 7;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              _MonthWeekday(label: 'T2'),
              _MonthWeekday(label: 'T3'),
              _MonthWeekday(label: 'T4'),
              _MonthWeekday(label: 'T5'),
              _MonthWeekday(label: 'T6'),
              _MonthWeekday(label: 'T7'),
              _MonthWeekday(label: 'CN'),
            ],
          ),
          const SizedBox(height: 4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalCells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 68,
            ),
            itemBuilder: (context, index) {
              final dayNumber = index - leadingCells + 1;
              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox.shrink();
              }
              final date = DateTime(anchorDate.year, anchorDate.month, dayNumber);
              final count = countOn(date);
              final isSelected = _sameDay(date, selectedDate);

              return Padding(
                padding: const EdgeInsets.all(3),
                child: InkWell(
                  borderRadius: BorderRadius.circular(9),
                  onTap: () => onDateSelected(date),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : const Color(0xFFFAF8F5),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: isSelected ? AppColors.primary : _borderColor),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dayNumber',
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          count == 0 ? 'Không có ca' : '$count ca',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : count == 0
                                    ? AppColors.textSecondary
                                    : AppColors.primary,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SelectedDayRoster extends StatelessWidget {
  const _SelectedDayRoster({required this.date, required this.items, required this.onTap});

  final DateTime date;
  final List<_Assignment> items;
  final ValueChanged<_Assignment> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Phân ca ngày ${date.day}/${date.month}/${date.year}',
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          const _EmptyNote(message: 'Chưa có ca nào trong ngày này.')
        else
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onTap(item),
                child: _DayAssignmentCard(item: item),
              ),
            ),
      ],
    );
  }
}

class _DayAssignmentCard extends StatelessWidget {
  const _DayAssignmentCard({required this.item});

  final _Assignment item;

  @override
  Widget build(BuildContext context) {
    final chipColor = item.isMorning ? _morningColor : _afternoonColor;
    final chipText = item.isMorning ? _morningText : _afternoonText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.employeeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.shiftName} · ${item.startLabel}–${item.endLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(color: chipColor, borderRadius: BorderRadius.circular(20)),
            child: Text(
              item.isMorning ? 'Ca sáng' : 'Ca chiều',
              style: TextStyle(color: chipText, fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthWeekday extends StatelessWidget {
  const _MonthWeekday({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _RosterTable extends StatelessWidget {
  const _RosterTable({
    required this.days,
    required this.employees,
    required this.cellFor,
    required this.onCellTap,
  });

  final List<DateTime> days;
  final List<Map<String, dynamic>> employees;
  final _Assignment? Function(int employeeId, DateTime date) cellFor;
  final void Function(int employeeId, DateTime date, _Assignment? existing) onCellTap;

  static const _employeeColumnWidth = 172.0;
  static const _dayColumnWidth = 58.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = constraints.maxWidth > 1400 ? 1400.0 : constraints.maxWidth;
        final employeeColumnWidth = tableWidth >= 720 ? 220.0 : _employeeColumnWidth;
        final dayColumnWidth = tableWidth >= 720
            ? (tableWidth - employeeColumnWidth - 16) / days.length
            : _dayColumnWidth;

        return Center(
          child: SizedBox(
            width: tableWidth,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _borderColor),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(employeeColumnWidth, dayColumnWidth),
                    for (final employee in employees) ...[
                      const Divider(height: 1, color: _borderColor),
                      _buildEmployeeRow(employee, employeeColumnWidth, dayColumnWidth),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(double employeeColumnWidth, double dayColumnWidth) {
    const labels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: employeeColumnWidth,
            child: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Text(
                'Nhân viên',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          for (final day in days)
            SizedBox(
              width: dayColumnWidth,
              child: Column(
                children: [
                  Text(
                    labels[day.weekday - 1],
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${day.day}',
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmployeeRow(Map<String, dynamic> employee, double employeeColumnWidth, double dayColumnWidth) {
    final employeeId = (employee['employeeId'] as num).toInt();
    final name = (employee['fullName'] ?? 'Nhân viên').toString();
    final code = (employee['employeeCode'] ?? '').toString();
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(RegExp(r'\s+')).map((part) => part[0]).take(2).join().toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: employeeColumnWidth,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: const Color(0xFFEAD9CC),
                  child: Text(
                    initials,
                    style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        code,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (final day in days)
            SizedBox(
              width: dayColumnWidth,
              child: Center(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onCellTap(employeeId, day, cellFor(employeeId, day)),
                  child: _RosterShiftCell(item: cellFor(employeeId, day)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RosterShiftCell extends StatelessWidget {
  const _RosterShiftCell({required this.item});

  final _Assignment? item;

  @override
  Widget build(BuildContext context) {
    final current = item;
    final color = current == null
        ? const Color(0xFFF7F5F2)
        : current.isMorning
            ? _morningColor
            : _afternoonColor;
    final label = current == null ? '+' : current.startLabel;

    return Container(
      width: 48,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: current == null ? Border.all(color: _borderColor) : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: current == null ? AppColors.textSecondary : AppColors.textPrimary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RosterLegend extends StatelessWidget {
  const _RosterLegend();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 14,
      runSpacing: 8,
      children: [
        _LegendItem(label: 'Ca sáng (bắt đầu trước 12:00)', color: _morningColor),
        _LegendItem(label: 'Ca chiều (bắt đầu từ 12:00)', color: _afternoonColor),
        _LegendItem(label: '+ chưa có ca, chạm để phân', color: Color(0xFFF7F5F2)),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

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
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
