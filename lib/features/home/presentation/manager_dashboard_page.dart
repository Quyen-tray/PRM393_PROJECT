import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import 'widgets/manager_more_menu.dart';

class ManagerDashboardPage extends StatelessWidget {
  const ManagerDashboardPage({super.key});

  static const _managerName = 'Trần Thị Bích Ngọc';
  static const _demoDate = 'Thứ Ba, 13/10/2026';

  static const _metrics = <_ManagerMetric>[
    _ManagerMetric(
      label: 'Nhân viên có mặt',
      value: '12/15',
      icon: Icons.people_alt_outlined,
      color: Color(0xFF28A765),
    ),
    _ManagerMetric(
      label: 'Đi muộn',
      value: '2',
      icon: Icons.alarm_on_outlined,
      color: Color(0xFFE75B59),
    ),
    _ManagerMetric(
      label: 'Checklist hoàn thành',
      value: '10/15',
      icon: Icons.fact_check_outlined,
      color: Color(0xFFE39A2F),
    ),
    _ManagerMetric(
      label: 'Vi phạm',
      value: '1',
      icon: Icons.warning_amber_rounded,
      color: Color(0xFFE75B59),
    ),
  ];

  static const _attendanceRows = <_ManagerAttendanceEntry>[
    _ManagerAttendanceEntry(
      initials: 'AN',
      name: 'Nguyễn Văn An',
      subtitle: 'NV0012 · Nhân viên phục vụ',
      timeLabel: 'Chưa check-in · trễ 7 phút',
      statusLabel: 'Đi muộn',
      statusColor: AppColors.error,
      avatarColor: Color(0xFFEAD9CC),
    ),
    _ManagerAttendanceEntry(
      initials: 'TB',
      name: 'Trần Văn Bình',
      subtitle: 'NV0013 · Nhân viên pha chế',
      timeLabel: '08:12',
      statusLabel: 'Đi muộn',
      statusColor: Color(0xFFB96D17),
      avatarColor: Color(0xFFDCE9E2),
    ),
    _ManagerAttendanceEntry(
      initials: 'LH',
      name: 'Lê Thị Hương',
      subtitle: 'NV0014 · Nhân viên phục vụ',
      timeLabel: 'Chưa check-in',
      statusLabel: 'Vắng',
      statusColor: AppColors.error,
      avatarColor: Color(0xFFE7E0F0),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            const _ManagerHeader(),
            const SizedBox(height: 18),
            Text(
              'Xin chào, $_managerName',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Quản lý cửa hàng',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 18),
            _DateLabel(date: _demoDate),
            const SizedBox(height: 12),
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
                    for (final metric in _metrics)
                      _ManagerMetricCard(metric: metric),
                  ],
                );
              },
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Chấm công hôm nay',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      context.go(RouteNames.managerAttendanceReport),
                  child: const Text('Xem tất cả'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _AttendanceList(entries: _attendanceRows),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
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
          if (index == 1) context.go(RouteNames.managerEmployees);
          if (index == 2) context.go(RouteNames.managerSchedule);
          if (index == 3) context.go(RouteNames.managerApprovals);
          if (index == 4) showManagerMoreMenu(context);
        },
      ),
    );
  }
}

class _ManagerHeader extends StatelessWidget {
  const _ManagerHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Mở chức năng khác',
            onPressed: () => showManagerMoreMenu(context),
            color: Colors.white,
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 24, height: 24),
            icon: const Icon(Icons.menu),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.coffee, color: Color(0xFFF1D2A6), size: 22),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'HRM COFFEE SHOP',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Làm mới',
            onPressed: () {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text('Đã làm mới dữ liệu demo.'),
                  ),
                );
            },
            color: Colors.white,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}

class _DateLabel extends StatelessWidget {
  const _DateLabel({required this.date});

  final String date;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.primary),
        const SizedBox(width: 7),
        Text(
          date,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ManagerMetric {
  const _ManagerMetric({
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

class _ManagerMetricCard extends StatelessWidget {
  const _ManagerMetricCard({required this.metric});

  final _ManagerMetric metric;

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
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ManagerAttendanceEntry {
  const _ManagerAttendanceEntry({
    required this.initials,
    required this.name,
    required this.subtitle,
    required this.timeLabel,
    required this.statusLabel,
    required this.statusColor,
    required this.avatarColor,
  });

  final String initials;
  final String name;
  final String subtitle;
  final String timeLabel;
  final String statusLabel;
  final Color statusColor;
  final Color avatarColor;
}

class _AttendanceList extends StatelessWidget {
  const _AttendanceList({required this.entries});

  final List<_ManagerAttendanceEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDE8E3)),
      ),
      child: Column(
        children: [
          for (var index = 0; index < entries.length; index++) ...[
            if (index > 0)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Divider(height: 1),
              ),
            _AttendanceRow(entry: entries[index]),
          ],
        ],
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({required this.entry});

  final _ManagerAttendanceEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: entry.avatarColor,
            child: Text(
              entry.initials,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  entry.subtitle,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
                ),
                const SizedBox(height: 3),
                Text(
                  entry.timeLabel,
                  style: TextStyle(color: entry.statusColor, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: entry.statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              entry.statusLabel,
              style: TextStyle(
                color: entry.statusColor,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
