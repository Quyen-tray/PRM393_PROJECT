import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../data/mock/demo_data.dart';

class EmployeeDashboardPage extends StatelessWidget {
  const EmployeeDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final employee = DemoData.employee;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              children: [
                _StoreHeader(
                  onNotificationsTap: () =>
                      context.go(RouteNames.employeeNotifications),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    children: [
                      _EmployeeGreeting(
                        employee: employee,
                        onProfileTap: () =>
                            context.go(RouteNames.employeeProfile),
                      ),
                      const SizedBox(height: 18),
                      _ShiftCard(
                        shift: DemoData.currentShift,
                        attendanceStatus: DemoData.attendanceStatus,
                        onCheckInTap: () => context.go(RouteNames.checkIn),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Truy cập nhanh',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 12),
                      _QuickAccessGrid(
                        onScheduleTap: () =>
                            context.go(RouteNames.employeeSchedule),
                        onChecklistTap: () =>
                            context.go(RouteNames.employeeChecklist),
                        onTrainingTap: () =>
                            context.go(RouteNames.employeeTraining),
                        onProfileTap: () =>
                            context.go(RouteNames.employeeProfile),
                        onNotificationsTap: () =>
                            context.go(RouteNames.employeeNotifications),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
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
          if (index == 1) {
            context.go(RouteNames.employeeSchedule);
          } else if (index == 2) {
            context.go(RouteNames.employeeChecklist);
          } else if (index == 3) {
            context.go(RouteNames.employeeProfile);
          }
        },
      ),
    );
  }
}

class _StoreHeader extends StatelessWidget {
  const _StoreHeader({required this.onNotificationsTap});

  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.coffee, color: Colors.white, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DemoData.storeName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DemoData.storeBranch,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Thông báo',
            onPressed: onNotificationsTap,
            color: AppColors.textPrimary,
            icon: const Badge(
              smallSize: 7,
              child: Icon(Icons.notifications_none_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeGreeting extends StatelessWidget {
  const _EmployeeGreeting({
    required this.employee,
    required this.onProfileTap,
  });

  final DemoEmployee employee;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 25,
          backgroundColor: Color(0xFFE9D9C8),
          child: Icon(Icons.person, color: Color(0xFF76533E), size: 27),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Xin chào,', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 2),
              Text(
                employee.fullName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                employee.position,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4F5E9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  employee.employmentStatus,
                  style: const TextStyle(
                    color: Color(0xFF25804B),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Hồ sơ cá nhân',
          onPressed: onProfileTap,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _ShiftCard extends StatelessWidget {
  const _ShiftCard({
    required this.shift,
    required this.attendanceStatus,
    required this.onCheckInTap,
  });

  final DemoShiftAssignment shift;
  final DemoAttendanceStatus attendanceStatus;
  final VoidCallback onCheckInTap;

  String get _attendanceLabel => switch (attendanceStatus) {
        DemoAttendanceStatus.notCheckedIn => 'Chưa check-in',
        DemoAttendanceStatus.checkedIn => 'Đã check-in',
        DemoAttendanceStatus.checkedOut => 'Đã check-out',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E1DA)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Ca làm hôm nay',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1D9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _attendanceLabel,
                  style: const TextStyle(
                    color: Color(0xFF96631D),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            shift.dayLabel,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${shift.startTime} - ${shift.endTime}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 25,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${shift.shiftName} · ${shift.workArea}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  minimumSize: const Size(0, 42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: onCheckInTap,
                child: const Text('Check-in'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAccessGrid extends StatelessWidget {
  const _QuickAccessGrid({
    required this.onScheduleTap,
    required this.onChecklistTap,
    required this.onTrainingTap,
    required this.onProfileTap,
    required this.onNotificationsTap,
  });

  final VoidCallback onScheduleTap;
  final VoidCallback onChecklistTap;
  final VoidCallback onTrainingTap;
  final VoidCallback onProfileTap;
  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.0,
      children: [
        _QuickAccessTile(
          icon: Icons.calendar_month_outlined,
          title: 'Lịch làm việc',
          color: const Color(0xFF3B8C67),
          onTap: onScheduleTap,
        ),
        _QuickAccessTile(
          icon: Icons.checklist_rounded,
          title: 'Checklist',
          color: const Color(0xFFD39A36),
          onTap: onChecklistTap,
        ),
        _QuickAccessTile(
          icon: Icons.school_outlined,
          title: 'Đào tạo',
          color: const Color(0xFF4E86A8),
          onTap: onTrainingTap,
        ),
        _QuickAccessTile(
          icon: Icons.person_outline,
          title: 'Hồ sơ',
          color: const Color(0xFFD66E56),
          onTap: onProfileTap,
        ),
        _QuickAccessTile(
          icon: Icons.notifications_none,
          title: 'Thông báo',
          color: const Color(0xFF7B68A6),
          onTap: onNotificationsTap,
        ),
      ],
    );
  }
}

class _QuickAccessTile extends StatelessWidget {
  const _QuickAccessTile({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFEDE8E3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 23),
              ),
              const SizedBox(height: 7),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(fontSize: 11, height: 1.15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
