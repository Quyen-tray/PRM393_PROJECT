import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../data/mock/demo_data.dart';
import '../../home/presentation/widgets/manager_more_menu.dart';

class ManagerAttendanceReportPage extends StatefulWidget {
  const ManagerAttendanceReportPage({super.key});

  @override
  State<ManagerAttendanceReportPage> createState() =>
      _ManagerAttendanceReportPageState();
}

class _ManagerAttendanceReportPageState
    extends State<ManagerAttendanceReportPage> {
  static const _monthOptions = ['Tháng 10/2026', 'Tháng 9/2026'];
  static const _shiftOptions = ['Tất cả ca', 'Ca sáng', 'Ca chiều'];

  String _selectedMonth = 'Tháng 10/2026';
  String _selectedShift = 'Tất cả ca';

  DemoAttendanceReport get _report => DemoData.managerAttendanceReports
      .firstWhere((item) =>
          item.monthLabel == _selectedMonth &&
          item.shiftLabel == _selectedShift);

  @override
  Widget build(BuildContext context) {
    final report = _report;

    final metrics = <_ReportMetric>[
      _ReportMetric(
        label: 'Tổng lượt phân ca',
        value: '${report.totalShifts}',
        icon: Icons.people_alt_outlined,
        color: const Color(0xFF3998D8),
      ),
      _ReportMetric(
        label: 'Đi muộn',
        value: '${report.lateCount}',
        icon: Icons.alarm_on_outlined,
        color: const Color(0xFFE75B59),
      ),
      _ReportMetric(
        label: 'Vắng mặt',
        value: '${report.absentCount}',
        icon: Icons.person_off_outlined,
        color: const Color(0xFFE39A2F),
      ),
      _ReportMetric(
        label: 'Vi phạm',
        value: '${report.violationCount}',
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFE75B59),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Báo cáo chấm công'),
        leading: IconButton(
          tooltip: 'Quay lại tổng quan',
          onPressed: () => context.go(RouteNames.home),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _ReportFilter(
                  value: _selectedMonth,
                  options: _monthOptions,
                  onChanged: (value) => setState(() => _selectedMonth = value),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ReportFilter(
                  value: _selectedShift,
                  options: _shiftOptions,
                  onChanged: (value) => setState(() => _selectedShift = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columnCount = constraints.maxWidth >= 900 ? 4 : 2;
              final tileWidth = (constraints.maxWidth -
                      10.0 * (columnCount - 1)) /
                  columnCount;

              return GridView.count(
                crossAxisCount: columnCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: tileWidth / 112,
                children: [
                  for (final metric in metrics)
                    _ReportMetricCard(metric: metric),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          const Text(
            'Tỷ lệ chấm công theo ngày',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _AttendanceChart(rates: report.dailyRates),
          const SizedBox(height: 20),
          const Text(
            'Chi tiết cần theo dõi',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _ReportDetailRow(
            label: 'Thiếu check-out',
            value: '${report.missingCheckOutCount}',
          ),
          _ReportDetailRow(
            label: 'Chờ xác minh',
            value: '${report.verificationPendingCount}',
          ),
          _ReportDetailRow(
            label: 'Tổng phút đi muộn',
            value: '${report.totalLateMinutes} phút',
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 4,
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
          if (index == 2) context.go(RouteNames.managerSchedule);
          if (index == 3) context.go(RouteNames.managerApprovals);
          if (index == 4) showManagerMoreMenu(context);
        },
      ),
    );
  }
}

class _ReportMetric {
  const _ReportMetric({
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

class _ReportMetricCard extends StatelessWidget {
  const _ReportMetricCard({required this.metric});

  final _ReportMetric metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDE8E3)),
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
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            metric.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportFilter extends StatelessWidget {
  const _ReportFilter({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDE8E3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          items: [
            for (final option in options)
              DropdownMenuItem(value: option, child: Text(option)),
          ],
          onChanged: (selected) {
            if (selected != null) onChanged(selected);
          },
        ),
      ),
    );
  }
}

class _AttendanceChart extends StatelessWidget {
  const _AttendanceChart({required this.rates});

  final List<int> rates;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDE8E3)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 35,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('100%', style: _axisLabelStyle),
                Text('75%', style: _axisLabelStyle),
                Text('50%', style: _axisLabelStyle),
                Text('25%', style: _axisLabelStyle),
                Text('0%', style: _axisLabelStyle),
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
                                  color: Color(0xFFEDE8E3),
                                ),
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
                                        horizontal: 1,
                                      ),
                                      child: Container(
                                        height: chartHeight * rate / 100,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF39A1E8),
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
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('01', style: _axisLabelStyle),
                    Text('05', style: _axisLabelStyle),
                    Text('10', style: _axisLabelStyle),
                    Text('15', style: _axisLabelStyle),
                    Text('20', style: _axisLabelStyle),
                    Text('25', style: _axisLabelStyle),
                    Text('30', style: _axisLabelStyle),
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

const _axisLabelStyle = TextStyle(
  color: AppColors.textSecondary,
  fontSize: 9,
);

class _ReportDetailRow extends StatelessWidget {
  const _ReportDetailRow({
    required this.label,
    required this.value,
  });

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
        border: Border.all(color: const Color(0xFFEDE8E3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
