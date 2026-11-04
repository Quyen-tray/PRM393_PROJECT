import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/repositories/employee_providers.dart';
import '../../home/presentation/widgets/manager_bottom_navigation.dart';

const _borderColor = Color(0xFFEDE8E3);
const _barColor = Color(0xFF39A1E8);

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _isoDay(Object? value) {
  final text = value?.toString() ?? '';
  return text.length >= 10 ? text.substring(0, 10) : text;
}

int _intOf(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

/// Số liệu tổng của một tháng (StatsView) đã đọc sang kiểu có tên.
class _Totals {
  const _Totals({
    required this.scheduled,
    required this.onTime,
    required this.late,
    required this.absent,
    required this.missingCheckOut,
    required this.verificationPending,
    required this.lateMinutes,
  });

  factory _Totals.fromMap(Map<String, dynamic> map) => _Totals(
        scheduled: _intOf(map['scheduledShifts']),
        onTime: _intOf(map['checkedInOnTime']),
        late: _intOf(map['late']),
        absent: _intOf(map['absent']),
        missingCheckOut: _intOf(map['missingCheckOuts']),
        verificationPending: _intOf(map['verificationPending']),
        lateMinutes: _intOf(map['lateMinutesTotal']),
      );

  final int scheduled;
  final int onTime;
  final int late;
  final int absent;
  final int missingCheckOut;
  final int verificationPending;
  final int lateMinutes;

  /// Tỷ lệ có mặt = (đúng giờ + đi muộn) / tổng lượt phân ca. Null khi chưa có ca nào.
  double? get presenceRate =>
      scheduled == 0 ? null : (onTime + late) / scheduled;
}

/// Một dòng của bảng theo nhân viên.
class _EmployeeRow {
  const _EmployeeRow({
    required this.name,
    required this.scheduled,
    required this.lateCount,
    required this.lateMinutes,
    required this.absent,
    required this.workedMinutes,
  });

  factory _EmployeeRow.fromMap(Map<String, dynamic> map) => _EmployeeRow(
        name: (map['employeeName'] ?? 'Mã ${map['employeeId'] ?? '—'}')
            .toString(),
        scheduled: _intOf(map['scheduledShifts']),
        lateCount: _intOf(map['lateCount']),
        lateMinutes: _intOf(map['lateMinutes']),
        absent: _intOf(map['absentShifts']),
        workedMinutes: _intOf(map['workedMinutes']),
      );

  final String name;
  final int scheduled;
  final int lateCount;
  final int lateMinutes;
  final int absent;
  final int workedMinutes;
}

/// Dữ liệu đã tính cho một tháng và một ca (hoặc tất cả ca).
class _ReportData {
  const _ReportData({
    required this.totals,
    required this.dailyRates,
    required this.employees,
  });

  final _Totals totals;

  /// Tỷ lệ có mặt từng ngày trong tháng (0..1), null với ngày chưa có ca hoặc chưa tới.
  final List<double?> dailyRates;
  final List<_EmployeeRow> employees;
}

/// Tính tỷ lệ có mặt theo ngày từ danh sách phân ca và chấm công của tháng.
/// Có mặt = có check-in. Lọc theo ca bằng shiftId của ca được phân.
List<double?> _dailyRates({
  required DateTime month,
  required int? shiftId,
  required List<Map<String, dynamic>> assignments,
  required List<Map<String, dynamic>> records,
}) {
  final shiftOfAssignment = <int, int?>{};
  final scheduled = <String, int>{};
  for (final row in assignments) {
    if (row['status'] == 'CANCELLED') continue;
    final assignmentId = _intOf(row['assignmentId']);
    final rowShift =
        row['workShift'] is Map ? (row['workShift'] as Map)['shiftId'] : null;
    final rowShiftId = rowShift == null ? null : _intOf(rowShift);
    shiftOfAssignment[assignmentId] = rowShiftId;
    if (shiftId != null && rowShiftId != shiftId) continue;
    final day = _isoDay(row['workDate']);
    scheduled[day] = (scheduled[day] ?? 0) + 1;
  }

  final checkedIn = <String, int>{};
  for (final row in records) {
    if (row['checkInAt'] == null) continue;
    final assignmentId = _intOf(row['shiftAssignmentId']);
    if (shiftId != null && shiftOfAssignment[assignmentId] != shiftId) continue;
    final day = _isoDay(row['workDate']);
    checkedIn[day] = (checkedIn[day] ?? 0) + 1;
  }

  final today = DateTime.now();
  final todayOnly = DateTime(today.year, today.month, today.day);
  final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  return List<double?>.generate(daysInMonth, (index) {
    final date = DateTime(month.year, month.month, index + 1);
    if (date.isAfter(todayOnly)) return null;
    final key = _isoDate(date);
    final planned = scheduled[key] ?? 0;
    if (planned == 0) return null;
    return ((checkedIn[key] ?? 0) / planned).clamp(0.0, 1.0).toDouble();
  });
}

class ManagerAttendanceReportPage extends ConsumerStatefulWidget {
  const ManagerAttendanceReportPage({super.key});

  @override
  ConsumerState<ManagerAttendanceReportPage> createState() =>
      _ManagerAttendanceReportPageState();
}

class _ManagerAttendanceReportPageState
    extends ConsumerState<ManagerAttendanceReportPage> {
  late final List<DateTime> _months;
  late DateTime _month;
  int? _shiftId;
  List<Map<String, dynamic>> _shifts = [];
  _ReportData? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Sáu tháng gần nhất, tháng hiện tại đứng đầu.
    _months =
        List.generate(6, (index) => DateTime(now.year, now.month - index, 1));
    _month = _months.first;
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
      final from = _isoDate(_month);
      final to = _isoDate(DateTime(_month.year, _month.month + 1, 0));
      final needShifts = _shifts.isEmpty;

      final results = await Future.wait<Object>([
        repo.getAttendanceStats(from: from, to: to, shiftId: _shiftId), // 0
        repo.getAttendanceReportRows(from: from, to: to), // 1
        repo.getShiftAssignments(from: from, to: to), // 2
        repo.getAttendanceRecords(from: from, to: to), // 3
        needShifts ? repo.getWorkShifts() : Future.value(_shifts), // 4
      ]);
      if (!mounted) return;

      final assignments = results[2] as List<Map<String, dynamic>>;
      final records = results[3] as List<Map<String, dynamic>>;
      final employees = (results[1] as List<Map<String, dynamic>>)
          .map(_EmployeeRow.fromMap)
          .toList()
        ..sort((a, b) {
          final byLate = b.lateCount.compareTo(a.lateCount);
          return byLate != 0 ? byLate : b.absent.compareTo(a.absent);
        });

      setState(() {
        _shifts = results[4] as List<Map<String, dynamic>>;
        _data = _ReportData(
          totals: _Totals.fromMap(results[0] as Map<String, dynamic>),
          dailyRates: _dailyRates(
            month: _month,
            shiftId: _shiftId,
            assignments: assignments,
            records: records,
          ),
          employees: employees,
        );
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is ApiException
            ? error.message
            : 'Không tải được báo cáo chấm công. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeMonth(DateTime month) {
    if (month == _month) return;
    setState(() => _month = month);
    _load();
  }

  void _changeShift(int? shiftId) {
    if (shiftId == _shiftId) return;
    setState(() => _shiftId = shiftId);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final busy = _loading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Báo cáo chấm công'),
        leading: IconButton(
          tooltip: 'Quay lại tổng quan',
          onPressed: () => context.go(RouteNames.home),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: busy && data != null
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3),
              )
            : null,
      ),
      body: data == null
          ? (_loading
              ? const Center(child: CircularProgressIndicator())
              : _ErrorView(
                  message: _error ?? 'Không tải được báo cáo.', onRetry: _load))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _Filter<DateTime>(
                          value: _month,
                          items: [
                            for (final month in _months)
                              DropdownMenuItem(
                                value: month,
                                child:
                                    Text('Tháng ${month.month}/${month.year}'),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) _changeMonth(value);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _Filter<int?>(
                          value: _shiftId,
                          items: [
                            const DropdownMenuItem<int?>(
                                value: null, child: Text('Tất cả ca')),
                            for (final shift in _shifts)
                              DropdownMenuItem<int?>(
                                value: _intOf(shift['shiftId']),
                                child: Text(
                                    (shift['shiftName'] ?? 'Ca').toString()),
                              ),
                          ],
                          onChanged: _changeShift,
                        ),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(_error!,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 12)),
                  ],
                  const SizedBox(height: 14),
                  _MetricsGrid(totals: data.totals),
                  const SizedBox(height: 22),
                  const Text(
                    'Tỷ lệ có mặt theo ngày',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  _AttendanceChart(rates: data.dailyRates),
                  const SizedBox(height: 20),
                  const Text(
                    'Chi tiết cần theo dõi',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  _DetailRow(
                    label: 'Tỷ lệ có mặt',
                    value: data.totals.presenceRate == null
                        ? '—'
                        : '${(data.totals.presenceRate! * 100).toStringAsFixed(1)}%',
                  ),
                  _DetailRow(
                      label: 'Thiếu check-out',
                      value: '${data.totals.missingCheckOut}'),
                  _DetailRow(
                      label: 'Chờ xác minh',
                      value: '${data.totals.verificationPending}'),
                  _DetailRow(
                      label: 'Tổng phút đi muộn',
                      value: '${data.totals.lateMinutes} phút'),
                  const SizedBox(height: 20),
                  const Text(
                    'Theo nhân viên',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Bảng này tính trên toàn bộ ca trong tháng, không lọc theo ca.',
                    style:
                        TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  if (data.employees.isEmpty)
                    const _EmptyBlock(
                        message: 'Chưa có ca làm nào trong tháng này.')
                  else
                    _EmployeeTable(rows: data.employees),
                ],
              ),
            ),
      bottomNavigationBar: const ManagerBottomNavigation(selectedIndex: 4),
    );
  }
}

class _Filter<T> extends StatelessWidget {
  const _Filter(
      {required this.value, required this.items, required this.onChanged});

  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.totals});

  final _Totals totals;

  @override
  Widget build(BuildContext context) {
    final metrics = <_Metric>[
      _Metric(
        label: 'Tổng lượt phân ca',
        value: '${totals.scheduled}',
        icon: Icons.people_alt_outlined,
        color: const Color(0xFF3998D8),
      ),
      _Metric(
        label: 'Đi muộn',
        value: '${totals.late}',
        icon: Icons.alarm_on_outlined,
        color: const Color(0xFFE75B59),
      ),
      _Metric(
        label: 'Vắng mặt',
        value: '${totals.absent}',
        icon: Icons.person_off_outlined,
        color: const Color(0xFFE39A2F),
      ),
      _Metric(
        label: 'Chờ xác minh',
        value: '${totals.verificationPending}',
        icon: Icons.verified_user_outlined,
        color: const Color(0xFF8A6FD1),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = constraints.maxWidth >= 900 ? 4 : 2;
        final tileWidth =
            (constraints.maxWidth - 10.0 * (columnCount - 1)) / columnCount;
        return GridView.count(
          crossAxisCount: columnCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: tileWidth / 112,
          children: [for (final metric in metrics) _MetricCard(metric: metric)],
        );
      },
    );
  }
}

class _Metric {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: metric.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(metric.icon, color: metric.color, size: 19),
          ),
          Text(
            metric.value,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 21,
                fontWeight: FontWeight.w800),
          ),
          Text(
            metric.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Biểu đồ cột tỷ lệ có mặt theo ngày. Nhãn trục X hiện các ngày 1, 5, 10, 15, 20, 25 và ngày cuối tháng.
class _AttendanceChart extends StatelessWidget {
  const _AttendanceChart({required this.rates});

  final List<double?> rates;

  static const _axisStyle =
      TextStyle(color: AppColors.textSecondary, fontSize: 9);

  @override
  Widget build(BuildContext context) {
    final lastDay = rates.length;
    final labelDays = {1, 5, 10, 15, 20, 25, lastDay};

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 35,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('100%', style: _axisStyle),
                Text('75%', style: _axisStyle),
                Text('50%', style: _axisStyle),
                Text('25%', style: _axisStyle),
                Text('0%', style: _axisStyle),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final chartHeight = constraints.maxHeight;
                      return Stack(
                        children: [
                          Positioned.fill(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(
                                5,
                                (_) => const Divider(
                                    height: 1,
                                    thickness: 1,
                                    color: _borderColor),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                for (final rate in rates)
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 1),
                                      child: rate == null
                                          ? const SizedBox.shrink()
                                          : Container(
                                              height: chartHeight * rate,
                                              decoration: BoxDecoration(
                                                color: _barColor,
                                                borderRadius:
                                                    BorderRadius.circular(3),
                                              ),
                                            ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    for (var day = 1; day <= lastDay; day++)
                      Expanded(
                        child: Text(
                          labelDays.contains(day) ? '$day' : '',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                          style: _axisStyle,
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ),
          Text(
            value,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _EmployeeTable extends StatelessWidget {
  const _EmployeeTable({required this.rows});

  final List<_EmployeeRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            if (index > 0) const Divider(height: 1),
            _EmployeeRowTile(row: rows[index]),
          ],
        ],
      ),
    );
  }
}

class _EmployeeRowTile extends StatelessWidget {
  const _EmployeeRowTile({required this.row});

  final _EmployeeRow row;

  @override
  Widget build(BuildContext context) {
    final hours = (row.workedMinutes / 60).toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  'Ca ${row.scheduled} · Giờ công $hours h',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          _Badge(
            label: 'Muộn ${row.lateCount}',
            color:
                row.lateCount > 0 ? AppColors.error : AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          _Badge(
            label: 'Vắng ${row.absent}',
            color: row.absent > 0
                ? const Color(0xFFB96D17)
                : AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(
            child: Text(message,
                style: const TextStyle(color: AppColors.textSecondary))),
      );
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
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
