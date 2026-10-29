import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../data/mock/demo_data.dart';

class EmployeeSchedulePage extends StatefulWidget {
  const EmployeeSchedulePage({super.key});

  @override
  State<EmployeeSchedulePage> createState() => _EmployeeSchedulePageState();
}

class _EmployeeSchedulePageState extends State<EmployeeSchedulePage> {
  late DateTime _anchorDate;
  late DateTime _selectedDate;
  _ScheduleView _view = _ScheduleView.week;

  @override
  void initState() {
    super.initState();
    _anchorDate = DateTime.parse(DemoData.employeeScheduleAnchorDate);
    _selectedDate = _anchorDate;
  }

  DateTime get _weekStart => _tuesdayOnOrBefore(_anchorDate);

  List<DateTime> get _weekDays => List.generate(
        7,
        (index) => _weekStart.add(Duration(days: index)),
      );

  DateTime _tuesdayOnOrBefore(DateTime date) {
    final daysSinceTuesday = (date.weekday - DateTime.tuesday + 7) % 7;
    return date.subtract(Duration(days: daysSinceTuesday));
  }

  void _changeView(_ScheduleView view) {
    setState(() {
      _view = view;
      if (view == _ScheduleView.month) {
        _anchorDate = DateTime(_selectedDate.year, _selectedDate.month, 1);
      } else {
        _anchorDate = _tuesdayOnOrBefore(_selectedDate);
      }
    });
  }

  void _changePeriod(int direction) {
    setState(() {
      if (_view == _ScheduleView.week) {
        _anchorDate = _weekStart.add(Duration(days: 7 * direction));
        _selectedDate = _anchorDate;
      } else {
        final nextMonth = DateTime(
          _anchorDate.year,
          _anchorDate.month + direction,
          1,
        );
        final lastDay = DateTime(nextMonth.year, nextMonth.month + 1, 0).day;
        _anchorDate = nextMonth;
        _selectedDate = DateTime(
          nextMonth.year,
          nextMonth.month,
          _selectedDate.day.clamp(1, lastDay).toInt(),
        );
      }
    });
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-${month}-${day}';
  }

  String _dayLabel(DateTime date) {
    const weekdays = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật',
    ];
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '${weekdays[date.weekday - 1]}, ${day}/${month}/${date.year}';
  }

  List<DemoShiftAssignment> _shiftsForDate(DateTime date) {
    final dateKey = _dateKey(date);
    final exactShifts = DemoData.employeeScheduleShifts
        .where((shift) => shift.workDate == dateKey)
        .toList();
    if (exactShifts.isNotEmpty) return exactShifts;

    final anchor = DateTime.parse(DemoData.employeeScheduleAnchorDate);
    final offset = date.difference(anchor).inDays;
    final patternIndex = ((offset % 7) + 7) % 7;
    final patternDate = anchor.add(Duration(days: patternIndex));
    final patternShifts = DemoData.employeeScheduleShifts
        .where((shift) => shift.workDate == _dateKey(patternDate))
        .toList();
    if (patternShifts.isEmpty) return const [];

    // Repeat the weekly pattern; the extra pending shift stays on 13/10 only.
    final shift = patternShifts.first;
    return [
      DemoShiftAssignment(
        workDate: dateKey,
        dayLabel: _dayLabel(date),
        shiftName: shift.shiftName,
        startTime: shift.startTime,
        endTime: shift.endTime,
        workArea: shift.workArea,
        assignmentStatus: shift.assignmentStatus,
      ),
    ];
  }

  List<DemoShiftAssignment> get _selectedDayShifts =>
      _shiftsForDate(_selectedDate)
          .where((shift) => shift.assignmentStatus != 'Ngày nghỉ')
          .toList();

  String get _periodLabel {
    if (_view == _ScheduleView.month) {
      return 'Tháng ${_anchorDate.month}/${_anchorDate.year}';
    }

    final endDate = _weekStart.add(const Duration(days: 6));
    if (_weekStart.month == endDate.month) {
      return 'Tuần ${_weekStart.day} - ${endDate.day}/${endDate.month}/${endDate.year}';
    }
    return 'Tuần ${_weekStart.day}/${_weekStart.month} - '
        '${endDate.day}/${endDate.month}/${endDate.year}';
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('$feature sẽ được hoàn thiện ở bước sau.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lịch làm việc'),
        leading: IconButton(
          tooltip: 'Quay lại trang chủ',
          onPressed: () => context.go(RouteNames.employeeHome),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              children: [
                _PeriodSelector(
                  view: _view,
                  periodLabel: _periodLabel,
                  onViewChanged: _changeView,
                  onPeriodChanged: _changePeriod,
                ),
                const SizedBox(height: 16),
                if (_view == _ScheduleView.week)
                      _WeekDaySelector(
                    days: _weekDays,
                    selectedDate: _selectedDate,
                    shiftsForDate: _shiftsForDate,
                    onDateSelected: (date) =>
                        setState(() => _selectedDate = date),
                  )
                else
                  _MonthCalendar(
                    anchorDate: _anchorDate,
                    selectedDate: _selectedDate,
                    shiftsForDate: _shiftsForDate,
                    onDateSelected: (date) =>
                        setState(() => _selectedDate = date),
                  ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _dayLabel(_selectedDate),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      _selectedDayShifts.length == 1
                          ? '1 ca'
                          : '${_selectedDayShifts.length} ca',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_selectedDayShifts.isEmpty)
                  _NoShiftCard(
                    isDayOff: _shiftsForDate(_selectedDate)
                        .any((shift) => shift.assignmentStatus == 'Ngày nghỉ'),
                  )
                else
                  for (final shift in _selectedDayShifts) ...[
                    _ShiftAssignmentCard(shift: shift),
                    const SizedBox(height: 9),
                  ],
                const SizedBox(height: 8),
                const _ShiftLegend(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 1,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Lịch',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'Checklist',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Cá nhân',
          ),
        ],
        onDestinationSelected: (index) {
          if (index == 0) {
            context.go(RouteNames.employeeHome);
          } else if (index == 2) {
            _showComingSoon('Checklist');
          } else if (index == 3) {
            _showComingSoon('Hồ sơ cá nhân');
          }
        },
      ),
    );
  }
}

enum _ScheduleView { week, month }

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.view,
    required this.periodLabel,
    required this.onViewChanged,
    required this.onPeriodChanged,
  });

  final _ScheduleView view;
  final String periodLabel;
  final ValueChanged<_ScheduleView> onViewChanged;
  final ValueChanged<int> onPeriodChanged;

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
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              tooltip: view == _ScheduleView.week ? 'Tuần trước' : 'Tháng trước',
              onPressed: () => onPeriodChanged(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              periodLabel,
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

class _WeekDaySelector extends StatelessWidget {
  const _WeekDaySelector({
    required this.days,
    required this.selectedDate,
    required this.shiftsForDate,
    required this.onDateSelected,
  });

  final List<DateTime> days;
  final DateTime selectedDate;
  final List<DemoShiftAssignment> Function(DateTime date) shiftsForDate;
  final ValueChanged<DateTime> onDateSelected;

  bool _isSelected(DateTime date) =>
      date.year == selectedDate.year &&
      date.month == selectedDate.month &&
      date.day == selectedDate.day;

  int _shiftCountFor(DateTime date) => shiftsForDate(date)
      .where((shift) => shift.assignmentStatus != 'Ngày nghỉ')
      .length;

  @override
  Widget build(BuildContext context) {
    const weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDE8E3)),
      ),
      child: Row(
        children: [
          for (final date in days)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onDateSelected(date),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _isSelected(date)
                          ? AppColors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          weekdays[date.weekday - 1],
                          style: TextStyle(
                            color: _isSelected(date)
                                ? Colors.white70
                                : AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            color: _isSelected(date)
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${_shiftCountFor(date)} ca',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _isSelected(date)
                                ? Colors.white
                                : AppColors.primary,
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.anchorDate,
    required this.selectedDate,
    required this.shiftsForDate,
    required this.onDateSelected,
  });

  final DateTime anchorDate;
  final DateTime selectedDate;
  final List<DemoShiftAssignment> Function(DateTime date) shiftsForDate;
  final ValueChanged<DateTime> onDateSelected;

  bool _isSelected(DateTime date) =>
      date.year == selectedDate.year &&
      date.month == selectedDate.month &&
      date.day == selectedDate.day;

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
              _WeekdayLabel(label: 'T2'),
              _WeekdayLabel(label: 'T3'),
              _WeekdayLabel(label: 'T4'),
              _WeekdayLabel(label: 'T5'),
              _WeekdayLabel(label: 'T6'),
              _WeekdayLabel(label: 'T7'),
              _WeekdayLabel(label: 'CN'),
            ],
          ),
          const SizedBox(height: 4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalCells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 58,
            ),
            itemBuilder: (context, index) {
              final dayNumber = index - leadingCells + 1;
              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox.shrink();
              }

              final date = DateTime(anchorDate.year, anchorDate.month, dayNumber);
              final assignedShiftCount = shiftsForDate(date)
                  .where((shift) => shift.assignmentStatus != 'Ngày nghỉ')
                  .length;
              final selected = _isSelected(date);

              return Padding(
                padding: const EdgeInsets.all(2),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onDateSelected(date),
                  child: Container(
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : const Color(0xFFFAF8F5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected
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
                            color: selected ? Colors.white : AppColors.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          assignedShiftCount == 0
                              ? '—'
                              : '${assignedShiftCount} ca',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected ? Colors.white : AppColors.primary,
                            fontSize: 8,
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

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel({required this.label});

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
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ShiftAssignmentCard extends StatelessWidget {
  const _ShiftAssignmentCard({required this.shift});

  final DemoShiftAssignment shift;

  bool get _isPending => shift.assignmentStatus == 'Chờ duyệt';

  @override
  Widget build(BuildContext context) {
    final accentColor = _isPending
        ? const Color(0xFFE89A24)
        : const Color(0xFF31A779);
    final statusBackground =
        _isPending ? const Color(0xFFFFE8C2) : const Color(0xFFDDF4E5);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFEDE8E3)),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 58,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${shift.startTime} - ${shift.endTime}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  shift.workArea,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  shift.shiftName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: statusBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              shift.assignmentStatus,
              style: TextStyle(
                color: _isPending
                    ? const Color(0xFFAA6500)
                    : const Color(0xFF25804B),
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

class _NoShiftCard extends StatelessWidget {
  const _NoShiftCard({required this.isDayOff});

  final bool isDayOff;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFEDE8E3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_available, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Text(
            isDayOff ? 'Ngày nghỉ theo lịch' : 'Chưa có ca được phân',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShiftLegend extends StatelessWidget {
  const _ShiftLegend();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 14,
      runSpacing: 8,
      children: [
        _LegendItem(color: Color(0xFF31A779), label: 'Đã phân'),
        _LegendItem(color: Color(0xFFE89A24), label: 'Chờ duyệt'),
        _LegendItem(color: Color(0xFFB8B8B8), label: 'Ngày nghỉ'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
