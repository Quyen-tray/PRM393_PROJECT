import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../data/mock/demo_data.dart';
import '../../home/presentation/widgets/manager_more_menu.dart';

class ManagerShiftSchedulePage extends StatefulWidget {
  const ManagerShiftSchedulePage({super.key});

  @override
  State<ManagerShiftSchedulePage> createState() =>
      _ManagerShiftSchedulePageState();
}

class _ManagerShiftSchedulePageState extends State<ManagerShiftSchedulePage> {
  DateTime _anchorDate = DateTime(2026, 10, 13);
  DateTime _selectedDate = DateTime(2026, 10, 13);
  _ScheduleView _view = _ScheduleView.week;
  late final List<DemoManagerShiftRosterRow> _roster = [
    ...DemoData.managerShiftRoster,
  ];

  List<_ScheduleDay> get _days => List.generate(
        7,
        (index) => _ScheduleDay(_anchorDate.add(Duration(days: index))),
      );

  DateTime _tuesdayOnOrBefore(DateTime date) {
    final daysSinceTuesday = (date.weekday - 2 + 7) % 7;
    return date.subtract(Duration(days: daysSinceTuesday));
  }

  List<_ScheduleDay> _daysForDate(DateTime date) {
    final weekStart = _tuesdayOnOrBefore(date);
    return List.generate(
      7,
      (index) => _ScheduleDay(weekStart.add(Duration(days: index))),
    );
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
  }

  void _changePeriod(int direction) {
    setState(() {
      if (_view == _ScheduleView.week) {
        _anchorDate = _anchorDate.add(Duration(days: 7 * direction));
        _selectedDate = _anchorDate;
      } else {
        _anchorDate = DateTime(
          _anchorDate.year,
          _anchorDate.month + direction,
          13,
        );
        _selectedDate = DateTime(_anchorDate.year, _anchorDate.month, 1);
      }
    });
  }

  int _patternIndexFor(DateTime date) {
    final offset = date.difference(DateTime(2026, 10, 13)).inDays;
    return ((offset % 7) + 7) % 7;
  }

  int _employeesScheduledOn(DateTime date) {
    final index = _patternIndexFor(date);
    return _roster.where((row) {
      final shift = row.shifts[index];
      return shift == DemoRosterShift.morning ||
          shift == DemoRosterShift.afternoon;
    }).length;
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
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          children: [
            _WeekSelector(
              view: _view,
              anchorDate: _anchorDate,
              onViewChanged: _changeView,
              onPeriodChanged: _changePeriod,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _view == _ScheduleView.week
                        ? 'Nhân viên theo ca'
                        : 'Ngày ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  _view == _ScheduleView.week
                      ? '${_roster.length} nhân viên'
                      : '${_employeesScheduledOn(_selectedDate)} nhân viên có ca',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_view == _ScheduleView.week) ...[
              _RosterTable(
                days: _days,
                roster: _roster,
                onCellTap: (row, dayIndex) => _showCreateShiftSheet(
                  initialEmployeeCode: row.employeeCode,
                  initialDayIndex: dayIndex,
                ),
              ),
              const SizedBox(height: 12),
              const _RosterLegend(),
            ] else ...[
              _MonthCalendar(
                anchorDate: _anchorDate,
                selectedDate: _selectedDate,
                scheduledEmployeeCount: _employeesScheduledOn,
                onDateSelected: (date) =>
                    setState(() => _selectedDate = date),
              ),
              const SizedBox(height: 16),
              _SelectedDayRoster(
                date: _selectedDate,
                roster: _roster,
                shiftIndex: _patternIndexFor(_selectedDate),
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _showCreateShiftSheet(),
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

  Future<void> _showCreateShiftSheet({
    String? initialEmployeeCode,
    int? initialDayIndex,
  }) {
    final days = _view == _ScheduleView.month
        ? _daysForDate(_selectedDate)
        : _days;
    final selectedDayIndex = _view == _ScheduleView.month
        ? _selectedDate.difference(_tuesdayOnOrBefore(_selectedDate)).inDays
        : 0;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => _CreateShiftSheet(
        roster: _roster,
        days: days,
        initialEmployeeCode: initialEmployeeCode,
        initialDayIndex: initialDayIndex ?? selectedDayIndex,
        onSave: (employeeCode, dayIndex, shift) {
          final rowIndex = _roster.indexWhere(
            (row) => row.employeeCode == employeeCode,
          );
          if (rowIndex < 0) return;

          setState(() {
            final oldRow = _roster[rowIndex];
            final updatedShifts = [...oldRow.shifts];
            updatedShifts[dayIndex] = shift;
            _roster[rowIndex] = DemoManagerShiftRosterRow(
              employeeName: oldRow.employeeName,
              employeeCode: oldRow.employeeCode,
              position: oldRow.position,
              initials: oldRow.initials,
              shifts: updatedShifts,
            );
          });
          Navigator.of(sheetContext).pop();
          _showDemoMessage('Đã cập nhật ca trong phiên demo.');
        },
      ),
    );
  }

  void _showDemoMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _ScheduleView { week, month }

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
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
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

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.anchorDate,
    required this.selectedDate,
    required this.scheduledEmployeeCount,
    required this.onDateSelected,
  });

  final DateTime anchorDate;
  final DateTime selectedDate;
  final int Function(DateTime date) scheduledEmployeeCount;
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
        border: Border.all(color: const Color(0xFFEDE8E3)),
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

              final date = DateTime(
                anchorDate.year,
                anchorDate.month,
                dayNumber,
              );
              final employeeCount = scheduledEmployeeCount(date);
              final isSelected = date.year == selectedDate.year &&
                  date.month == selectedDate.month &&
                  date.day == selectedDate.day;

              return Padding(
                padding: const EdgeInsets.all(3),
                child: InkWell(
                  borderRadius: BorderRadius.circular(9),
                  onTap: () => onDateSelected(date),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : const Color(0xFFFAF8F5),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : const Color(0xFFEDE8E3),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dayNumber',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          employeeCount == 0
                              ? 'Không có ca'
                              : '$employeeCount ca',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : employeeCount == 0
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
  const _SelectedDayRoster({
    required this.date,
    required this.roster,
    required this.shiftIndex,
  });

  final DateTime date;
  final List<DemoManagerShiftRosterRow> roster;
  final int shiftIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Phân ca ngày ${date.day}/${date.month}/${date.year}',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        for (final employee in roster)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _DayRosterCard(
              employee: employee,
              shift: employee.shifts[shiftIndex],
            ),
          ),
      ],
    );
  }
}

class _DayRosterCard extends StatelessWidget {
  const _DayRosterCard({required this.employee, required this.shift});

  final DemoManagerShiftRosterRow employee;
  final DemoRosterShift shift;

  @override
  Widget build(BuildContext context) {
    final (shiftLabel, shiftTime, chipColor, chipTextColor) = switch (shift) {
      DemoRosterShift.morning => (
          'Ca sáng',
          '08:00–16:00',
          const Color(0xFFE4F4D7),
          const Color(0xFF287A38),
        ),
      DemoRosterShift.afternoon => (
          'Ca chiều',
          '16:00–22:00',
          const Color(0xFFFFE8C2),
          const Color(0xFF98600B),
        ),
      DemoRosterShift.off => (
          'Ngày nghỉ',
          'Không phân ca hôm nay',
          const Color(0xFFF1F2F3),
          AppColors.textSecondary,
        ),
      DemoRosterShift.leave => (
          'Nghỉ phép',
          'Nhân viên nghỉ theo lịch',
          const Color(0xFFF9DDDA),
          const Color(0xFFA63C36),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDE8E3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(
              employee.initials,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.employeeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${employee.employeeCode} · ${employee.position} · $shiftTime',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: chipColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              shiftLabel,
              style: TextStyle(
                color: chipTextColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
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
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _RosterTable extends StatelessWidget {
  const _RosterTable({
    required this.days,
    required this.roster,
    required this.onCellTap,
  });

  final List<_ScheduleDay> days;
  final List<DemoManagerShiftRosterRow> roster;
  final void Function(DemoManagerShiftRosterRow row, int dayIndex) onCellTap;

  static const _employeeColumnWidth = 172.0;
  static const _dayColumnWidth = 58.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth =
            constraints.maxWidth > 1400 ? 1400.0 : constraints.maxWidth;
        final employeeColumnWidth =
            tableWidth >= 720 ? 220.0 : _employeeColumnWidth;
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
                border: Border.all(color: const Color(0xFFEDE8E3)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(employeeColumnWidth, dayColumnWidth),
                    for (var rowIndex = 0;
                        rowIndex < roster.length;
                        rowIndex++) ...[
                      const Divider(height: 1, color: Color(0xFFEDE8E3)),
                      _buildEmployeeRow(
                        roster[rowIndex],
                        employeeColumnWidth,
                        dayColumnWidth,
                      ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: employeeColumnWidth,
            child: Padding(
              padding: EdgeInsets.only(left: 8),
              child: Text(
                'Nhân viên',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          for (final day in days)
            SizedBox(
              width: dayColumnWidth,
              child: Column(
                children: [
                  Text(
                    day.label,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    day.date,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmployeeRow(
    DemoManagerShiftRosterRow row,
    double employeeColumnWidth,
    double dayColumnWidth,
  ) {
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
                    row.initials,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.employeeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${row.employeeCode} · ${row.position}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (var dayIndex = 0; dayIndex < row.shifts.length; dayIndex++)
            SizedBox(
              width: dayColumnWidth,
              child: Center(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onCellTap(row, dayIndex),
                  child: _RosterShiftCell(shift: row.shifts[dayIndex]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RosterShiftCell extends StatelessWidget {
  const _RosterShiftCell({required this.shift});

  final DemoRosterShift shift;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (shift) {
      DemoRosterShift.morning => ('S', const Color(0xFFE4F4D7)),
      DemoRosterShift.afternoon => ('C', const Color(0xFFFFE8C2)),
      DemoRosterShift.off => ('Nghỉ', const Color(0xFFF1F2F3)),
      DemoRosterShift.leave => ('Phép', const Color(0xFFF9DDDA)),
    };

    return Container(
      width: 48,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textPrimary,
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
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: const [
        _LegendItem(label: 'Ca sáng · 08:00–16:00', color: Color(0xFFE4F4D7)),
        _LegendItem(label: 'Ca chiều · 16:00–22:00', color: Color(0xFFFFE8C2)),
        _LegendItem(label: 'Ngày nghỉ', color: Color(0xFFF1F2F3)),
        _LegendItem(label: 'Nghỉ phép', color: Color(0xFFF9DDDA)),
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
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _CreateShiftSheet extends StatefulWidget {
  const _CreateShiftSheet({
    required this.roster,
    required this.days,
    required this.initialEmployeeCode,
    required this.initialDayIndex,
    required this.onSave,
  });

  final List<DemoManagerShiftRosterRow> roster;
  final List<_ScheduleDay> days;
  final String? initialEmployeeCode;
  final int initialDayIndex;
  final void Function(String employeeCode, int dayIndex, DemoRosterShift shift)
      onSave;

  @override
  State<_CreateShiftSheet> createState() => _CreateShiftSheetState();
}

class _CreateShiftSheetState extends State<_CreateShiftSheet> {
  late String _employeeCode = widget.initialEmployeeCode ??
      (widget.roster.isEmpty ? '' : widget.roster.first.employeeCode);
  late int _dayIndex = widget.initialDayIndex;
  DemoRosterShift _shift = DemoRosterShift.morning;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tạo lịch phân ca',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _employeeCode,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Nhân viên',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final row in widget.roster)
                DropdownMenuItem(
                  value: row.employeeCode,
                  child: Text('${row.employeeName} · ${row.employeeCode}'),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _employeeCode = value);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _dayIndex,
            decoration: const InputDecoration(
              labelText: 'Ngày làm việc',
              border: OutlineInputBorder(),
            ),
            items: [
              for (var index = 0; index < widget.days.length; index++)
                DropdownMenuItem(
                  value: index,
                  child: Text(widget.days[index].dateLabel),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _dayIndex = value);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<DemoRosterShift>(
            initialValue: _shift,
            decoration: const InputDecoration(
              labelText: 'Ca làm việc',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final shift in DemoRosterShift.values)
                DropdownMenuItem(
                  value: shift,
                  child: Text(shift.displayLabel),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _shift = value);
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: widget.roster.isEmpty
                  ? null
                  : () => widget.onSave(_employeeCode, _dayIndex, _shift),
              child: const Text('Lưu lịch demo'),
            ),
          ),
        ],
      ),
    );
  }
}

extension on DemoRosterShift {
  String get displayLabel => switch (this) {
        DemoRosterShift.morning => 'Ca sáng · 08:00–16:00',
        DemoRosterShift.afternoon => 'Ca chiều · 16:00–22:00',
        DemoRosterShift.off => 'Ngày nghỉ',
        DemoRosterShift.leave => 'Nghỉ phép',
      };
}

class _ScheduleDay {
  _ScheduleDay(DateTime date)
      : label = _weekdayLabels[date.weekday - 1],
        date = '${date.day}',
        dateLabel = '${date.day}/${date.month}/${date.year}';

  static const _weekdayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  final String label;
  final String date;
  final String dateLabel;
}
