import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/resources/data/resource_repository.dart';
import '../../auth/data/session_controller.dart';
import '../../../core/presentation/business_labels.dart';
import '../../../core/presentation/resource_widgets.dart';

final attendanceMonthProvider =
    FutureProvider.autoDispose.family<Json, String>((ref, month) async {
  ref.watch(dataRevisionProvider);
  ref.watch(sessionProvider.select((s) => s.user));
  final first = DateTime.parse('$month-01');
  final last = DateTime(first.year, first.month + 1, 0);
  final range = {
    'from': first.toIso8601String().substring(0, 10),
    'to': last.toIso8601String().substring(0, 10)
  };
  final repo = ref.watch(resourceRepositoryProvider);
  final rows = <Json>[];
  var page = 0;
  while (true) {
    final result = await repo
        .list('/attendance/me', {...range, 'page': page, 'size': 100});
    rows.addAll(result.items);
    if (++page >= result.totalPages) break;
  }
  final shifts = await repo.list('/shift-assignments/me', range);
  return {'records': rows, 'shifts': shifts.items};
});

class AttendanceCalendarPage extends ConsumerStatefulWidget {
  const AttendanceCalendarPage({super.key});
  @override
  ConsumerState<AttendanceCalendarPage> createState() => _CalendarState();
}

class _CalendarState extends ConsumerState<AttendanceCalendarPage> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime selected = DateUtils.dateOnly(DateTime.now());
  String keyOf(DateTime d) => d.toIso8601String().substring(0, 10);
  @override
  Widget build(BuildContext context) {
    final monthKey = keyOf(month).substring(0, 7);
    final data = ref.watch(attendanceMonthProvider(monthKey));
    return PageBody(
        onRefresh: () async {
          ref.invalidate(attendanceMonthProvider(monthKey));
          await ref.read(attendanceMonthProvider(monthKey).future);
        },
        children: [
          Text('Lịch công của tôi',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
              'Chọn một ngày để xem ca làm, giờ vào/ra và gửi yêu cầu liên quan.'),
          Card(
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                IconButton(
                    tooltip: 'Tháng trước',
                    onPressed: () => changeMonth(-1),
                    icon: const Icon(Icons.chevron_left)),
                Text('Tháng ${month.month}/${month.year}',
                    style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                    tooltip: 'Tháng sau',
                    onPressed: () => changeMonth(1),
                    icon: const Icon(Icons.chevron_right)),
              ])),
          data.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorPanel(e,
                  retry: () =>
                      ref.invalidate(attendanceMonthProvider(monthKey))),
              data: (value) {
                final rows = ResourcePage.parse(value['records']).items;
                final shifts = ResourcePage.parse(value['shifts']).items;
                final start = month.subtract(Duration(days: month.weekday - 1));
                final count = ((DateTime(month.year, month.month + 1, 0).day +
                                month.weekday -
                                1) /
                            7)
                        .ceil() *
                    7;
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        for (final name in [
                          'T2',
                          'T3',
                          'T4',
                          'T5',
                          'T6',
                          'T7',
                          'CN'
                        ])
                          Expanded(
                              child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  child:
                                      Text(name, textAlign: TextAlign.center)))
                      ]),
                      GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 7,
                                  mainAxisSpacing: 4,
                                  crossAxisSpacing: 4,
                                  childAspectRatio: 1.05),
                          itemCount: count,
                          itemBuilder: (context, index) {
                            final date = start.add(Duration(days: index));
                            final key = keyOf(date);
                            final dayRows = rows
                                .where((r) => r['workDate'] == key)
                                .toList();
                            final assigned = shifts
                                .where((s) => s['workDate'] == key)
                                .toList();
                            final color = dayRows.isNotEmpty
                                ? dayRows.any((r) => r['checkOutAt'] == null)
                                    ? Colors.blue
                                    : dayRows.any((r) =>
                                            (r['lateMinutes'] as num? ?? 0) >
                                                0 ||
                                            (r['earlyLeaveMinutes'] as num? ??
                                                    0) >
                                                0)
                                        ? Colors.orange
                                        : Colors.green
                                : assigned.isNotEmpty
                                    ? assigned.any((s) =>
                                            DateTime.tryParse(
                                                    '${s['plannedEndAt']}')
                                                ?.isBefore(DateTime.now()) ==
                                            true)
                                        ? Colors.red
                                        : Colors.brown
                                    : Colors.grey;
                            final active = DateUtils.isSameDay(selected, date);
                            return Material(
                                color: active
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                    : date.month == month.month
                                        ? Colors.white
                                        : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => setState(() {
                                          selected = date;
                                          if (date.month != month.month) {
                                            month =
                                                DateTime(date.year, date.month);
                                          }
                                        }),
                                    child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text('${date.day}',
                                              style: TextStyle(
                                                  fontWeight: active
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                  color:
                                                      date.month == month.month
                                                          ? null
                                                          : Colors.grey)),
                                          const SizedBox(height: 6),
                                          if (dayRows.isNotEmpty ||
                                              assigned.isNotEmpty)
                                            Icon(
                                                dayRows.isNotEmpty
                                                    ? dayRows.any((r) =>
                                                            r['checkOutAt'] ==
                                                            null)
                                                        ? Icons.login
                                                        : color == Colors.orange
                                                            ? Icons
                                                                .priority_high
                                                            : Icons.check
                                                    : color == Colors.red
                                                        ? Icons
                                                            .warning_amber_rounded
                                                        : Icons.schedule,
                                                size: 14,
                                                color: color),
                                        ])));
                          }),
                      const SizedBox(height: 16),
                      Wrap(spacing: 12, runSpacing: 8, children: [
                        for (final entry in {
                          Colors.green: 'Đã kết thúc ca',
                          Colors.blue: 'Đã vào ca',
                          Colors.orange: 'Đi muộn / về sớm',
                          Colors.red: 'Ca đã qua chưa có công',
                          Colors.brown: 'Được phân ca'
                        }.entries)
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.circle, color: entry.key, size: 10),
                            const SizedBox(width: 5),
                            Text(entry.value,
                                style: Theme.of(context).textTheme.labelSmall)
                          ])
                      ]),
                      SectionTitle('Ngày ${dateText(keyOf(selected))}'),
                      if (!shifts
                              .any((s) => s['workDate'] == keyOf(selected)) &&
                          !rows.any((r) => r['workDate'] == keyOf(selected)))
                        const EmptyPanel(
                            message: 'Không có ca được phân trong ngày này.'),
                      for (final record in rows
                          .where((r) => r['workDate'] == keyOf(selected)))
                        Card(
                            child: ListTile(
                                leading: const Icon(Icons.fact_check_outlined),
                                title: Text(
                                    statusLabel(record['attendanceStatus'])),
                                subtitle: Text(
                                    'Vào: ${dateText(record['checkInAt'])}\nRa: ${dateText(record['checkOutAt'])}'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => context.push(
                                    '/record/my-attendance/${record['attendanceId']}'))),
                      for (final shift in shifts
                          .where((s) => s['workDate'] == keyOf(selected)))
                        Card(
                            child: ListTile(
                                title: Text(
                                    '${json(shift['workShift'])['shiftName'] ?? 'Ca làm'}'),
                                subtitle: Text(
                                    '${dateText(shift['plannedStartAt'])} → ${dateText(shift['plannedEndAt'])}'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => context.push(
                                    '/record/my-schedule/${shift['assignmentId']}'))),
                    ]);
              }),
        ]);
  }

  void changeMonth(int offset) => setState(() {
        month = DateTime(month.year, month.month + offset);
        selected = month;
      });
}
