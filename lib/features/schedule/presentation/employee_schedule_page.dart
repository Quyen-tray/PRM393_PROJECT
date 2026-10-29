import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';

class EmployeeSchedulePage extends StatefulWidget {
  const EmployeeSchedulePage({super.key});

  @override
  State<EmployeeSchedulePage> createState() => _EmployeeSchedulePageState();
}

class _EmployeeSchedulePageState extends State<EmployeeSchedulePage> {
  late DateTime _selectedDate;
  int _weekOffset = 0;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateUtils.dateOnly(DateTime.now());
  }

  DateTime get _weekStart {
    final today = DateUtils.dateOnly(DateTime.now());
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return monday.add(Duration(days: _weekOffset * 7));
  }

  List<DateTime> get _weekDates =>
      List.generate(7, (index) => _weekStart.add(Duration(days: index)));

  List<_Shift> _shiftsFor(DateTime date) {
    final weekdayShifts = <int, _Shift>{
      DateTime.monday: const _Shift(
        name: 'Ca sáng',
        start: '07:00',
        end: '15:00',
        position: 'Thu ngân',
        location: 'Tầng 1 · Quầy chính',
      ),
      DateTime.tuesday: const _Shift(
        name: 'Ca chiều',
        start: '14:00',
        end: '22:00',
        position: 'Phục vụ',
        location: 'Khu vực khách',
      ),
      DateTime.wednesday: const _Shift(
        name: 'Ca sáng',
        start: '07:00',
        end: '15:00',
        position: 'Pha chế',
        location: 'Quầy pha chế',
      ),
      DateTime.friday: const _Shift(
        name: 'Ca tối',
        start: '15:00',
        end: '23:00',
        position: 'Thu ngân',
        location: 'Tầng 1 · Quầy chính',
      ),
      DateTime.saturday: const _Shift(
        name: 'Ca sáng',
        start: '08:00',
        end: '16:00',
        position: 'Phục vụ',
        location: 'Khu vực khách',
      ),
      DateTime.sunday: const _Shift(
        name: 'Ca giữa',
        start: '10:00',
        end: '18:00',
        position: 'Pha chế',
        location: 'Quầy pha chế',
      ),
    };
    final shift = weekdayShifts[date.weekday];
    return shift == null ? const [] : [shift];
  }

  void _changeWeek(int amount) {
    setState(() {
      _weekOffset += amount;
      _selectedDate = _weekStart;
    });
  }

  String _weekLabel(DateTime start) {
    final end = start.add(const Duration(days: 6));
    return '${start.day} ${_monthName(start.month)} - ${end.day} ${_monthName(end.month)}';
  }

  String _monthName(int month) {
    const names = [
      'tháng 1',
      'tháng 2',
      'tháng 3',
      'tháng 4',
      'tháng 5',
      'tháng 6',
      'tháng 7',
      'tháng 8',
      'tháng 9',
      'tháng 10',
      'tháng 11',
      'tháng 12',
    ];
    return names[month - 1];
  }

  String _weekdayName(int weekday) {
    const names = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ nhật'];
    return names[weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final selectedShifts = _shiftsFor(_selectedDate);
    final weekShiftCount = _weekDates.fold<int>(
      0,
      (count, date) => count + _shiftsFor(date).length,
    );
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch làm việc'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Hôm nay',
            onPressed: () => setState(() {
              _weekOffset = 0;
              _selectedDate = DateUtils.dateOnly(DateTime.now());
            }),
            icon: const Icon(Icons.today_outlined),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 20),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tuần ${_weekLabel(_weekStart)}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tuần trước',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _changeWeek(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  IconButton(
                    tooltip: 'Tuần tiếp theo',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _changeWeek(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
            _WeekDatePicker(
              dates: _weekDates,
              selectedDate: _selectedDate,
              onSelected: (date) => setState(() => _selectedDate = date),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isToday ? 'Hôm nay' : '${_weekdayName(_selectedDate.weekday)}, ${_selectedDate.day} ${_monthName(_selectedDate.month)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  Text(
                    '$weekShiftCount ca trong tuần',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            if (selectedShifts.isEmpty)
              const _NoShiftMessage()
            else
              ...selectedShifts.map(
                (shift) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: _ShiftCard(
                    shift: shift,
                    date: _selectedDate,
                    isToday: isToday,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
              child: Text(
                'Lưu ý ca làm',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _ScheduleNotice(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 1,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Trang chủ'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Lịch'),
          NavigationDestination(icon: Icon(Icons.checklist_outlined), selectedIcon: Icon(Icons.checklist), label: 'Checklist'),
          NavigationDestination(icon: Icon(Icons.notifications_none), selectedIcon: Icon(Icons.notifications), label: 'Tin nhắn'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Cá nhân'),
        ],
        onDestinationSelected: (index) {
          if (index == 0) context.go(RouteNames.home);
          if (index == 4) context.go(RouteNames.profile);
        },
      ),
    );
  }
}

class _WeekDatePicker extends StatelessWidget {
  const _WeekDatePicker({
    required this.dates,
    required this.selectedDate,
    required this.onSelected,
  });

  final List<DateTime> dates;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 78,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        separatorBuilder: (_, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final date = dates[index];
          final selected = DateUtils.isSameDay(date, selectedDate);
          final today = DateUtils.isSameDay(date, DateTime.now());
          final dayShort = date.weekday == DateTime.sunday
              ? 'CN'
              : 'T${date.weekday + 1}';

          return SizedBox(
            width: 43,
            child: Material(
              color: selected ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onSelected(date),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected ? AppColors.primary : const Color(0xFFE6E8E3),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dayShort,
                        style: TextStyle(
                          fontSize: 10,
                          color: selected ? Colors.white70 : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: today
                              ? (selected ? Colors.white : AppColors.secondary)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Shift {
  const _Shift({
    required this.name,
    required this.start,
    required this.end,
    required this.position,
    required this.location,
  });

  final String name;
  final String start;
  final String end;
  final String position;
  final String location;
}

class _ShiftCard extends StatelessWidget {
  const _ShiftCard({
    required this.shift,
    required this.date,
    required this.isToday,
  });

  final _Shift shift;
  final DateTime date;
  final bool isToday;

  String get _status {
    final today = DateUtils.dateOnly(DateTime.now());
    if (date.isBefore(today)) return 'Đã hoàn thành';
    if (isToday) return 'Hôm nay';
    return 'Sắp tới';
  }

  @override
  Widget build(BuildContext context) {
    final past = date.isBefore(DateUtils.dateOnly(DateTime.now()));
    final statusColor = past ? AppColors.textSecondary : AppColors.secondary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE6E8E3)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shift.start, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 3),
                Text(shift.end, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Container(
            width: 3,
            height: 64,
            decoration: BoxDecoration(
              color: isToday ? const Color(0xFFD49A4A) : AppColors.secondary,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        shift.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.11),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _status,
                        style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(shift.position, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.place_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        shift.location,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoShiftMessage extends StatelessWidget {
  const _NoShiftMessage();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE6E8E3)),
      ),
      child: const Column(
        children: [
          Icon(Icons.event_available_outlined, size: 30, color: AppColors.textSecondary),
          SizedBox(height: 8),
          Text('Bạn không có ca làm trong ngày này', style: TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(height: 4),
          Text('Chọn ngày khác để xem lịch làm việc.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ScheduleNotice extends StatelessWidget {
  const _ScheduleNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6F2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: AppColors.primary),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Vui lòng có mặt trước giờ bắt đầu ca 10 phút. Nếu cần đổi ca, hãy gửi yêu cầu cho quản lý.',
              style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
