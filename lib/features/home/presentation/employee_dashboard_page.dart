import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';

class EmployeeDashboardPage extends StatelessWidget {
  const EmployeeDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          children: [
            const _StoreHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _EmployeeGreeting(),
                      const SizedBox(height: 16),
                      const _AttendanceCard(),
                      const SizedBox(height: 22),
                      Text(
                        'Truy cập nhanh',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 12),
                      const _TaskGrid(),
                      const SizedBox(height: 22),
                      _SectionHeading(
                        title: 'Checklist hôm nay',
                        action: '2/4 hoàn tất',
                      ),
                      const SizedBox(height: 8),
                      const _TodayChecklist(),
                      const SizedBox(height: 22),
                      _SectionHeading(
                        title: 'Ca làm hôm nay',
                        action: 'Xem lịch',
                        onTap: () {},
                      ),
                      const SizedBox(height: 8),
                      const _ScheduleCard(),
                      const SizedBox(height: 22),
                      Text(
                        'Thông báo mới',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 10),
                      const _NotificationCard(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Trang chủ'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Lịch'),
          NavigationDestination(icon: Icon(Icons.checklist_outlined), selectedIcon: Icon(Icons.checklist), label: 'Checklist'),
          NavigationDestination(icon: Icon(Icons.notifications_none), selectedIcon: Icon(Icons.notifications), label: 'Tin nhắn'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Cá nhân'),
        ],
        onDestinationSelected: (index) {
          if (index == 4) context.go(RouteNames.profile);
        },
      ),
    );
  }
}

class _StoreHeader extends StatelessWidget {
  const _StoreHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF24332D),
      padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.coffee, color: Color(0xFFE9C89A), size: 21),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HRM COFFEE SHOP',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Chi nhánh trung tâm',
                    style: TextStyle(color: Color(0xFFCFD8D2), fontSize: 11),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Thông báo',
              onPressed: () {},
              color: Colors.white,
              icon: const Badge(
                smallSize: 7,
                child: Icon(Icons.notifications_none_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeGreeting extends StatelessWidget {
  const _EmployeeGreeting();

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
              Text('Chào buổi sáng,', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 2),
              Text(
                'Nguyễn Thị Mai',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Nhân viên · Thu ngân',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Hồ sơ cá nhân',
          onPressed: () => context.go(RouteNames.profile),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.action,
    this.onTap,
  });

  final String title;
  final String action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: const Size(0, 36),
          ),
          child: Text(action),
        ),
      ],
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
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
                  'Chấm công hôm nay',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1D9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Chưa check-in',
                  style: TextStyle(color: Color(0xFF96631D), fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '08:12',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 34,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(width: 9),
              Padding(
                padding: EdgeInsets.only(bottom: 2),
                child: Text(
                  'Thứ Hai, 26/10',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          const Row(
            children: [
              Icon(Icons.access_time, size: 17, color: AppColors.textSecondary),
              SizedBox(width: 7),
              Text('Ca sáng', style: TextStyle(fontWeight: FontWeight.w600)),
              Spacer(),
              Text('07:00 - 15:00', style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF76503A),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => context.go(RouteNames.checkIn),
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('Check-in'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskGrid extends StatelessWidget {
  const _TaskGrid();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: _TaskTile(
            icon: Icons.calendar_month_outlined,
            title: 'Lịch làm việc',
            color: Color(0xFF3B8C67),
          ),
        ),
        Expanded(
          child: _TaskTile(
            icon: Icons.checklist_rounded,
            title: 'Checklist',
            color: Color(0xFFD39A36),
          ),
        ),
        Expanded(
          child: _TaskTile(
            icon: Icons.description_outlined,
            title: 'Hồ sơ',
            color: Color(0xFFD66E56),
          ),
        ),
        Expanded(
          child: _TaskTile(
            icon: Icons.school_outlined,
            title: 'Đào tạo',
            color: Color(0xFF4E86A8),
          ),
        ),
      ],
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.icon,
    required this.title,
    required this.color,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
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
    );
  }
}

class _TodayChecklist extends StatelessWidget {
  const _TodayChecklist();

  @override
  Widget build(BuildContext context) {
    return const _SectionCard(
      child: Column(
        children: [
          _ChecklistRow(title: 'Kiểm tra khu vực quầy', isDone: true),
          Divider(height: 18),
          _ChecklistRow(title: 'Kiểm tra máy pha cà phê', isDone: true),
          Divider(height: 18),
          _ChecklistRow(title: 'Vệ sinh bàn và khu vực khách', isDone: false),
          Divider(height: 18),
          _ChecklistRow(title: 'Kiểm tra nguyên vật liệu', isDone: false),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.title, required this.isDone});

  final String title;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          isDone ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isDone ? AppColors.secondary : const Color(0xFF9AA39B),
          size: 19,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: isDone ? AppColors.textSecondary : AppColors.textPrimary,
              decoration: isDone ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
        if (!isDone)
          const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
      ],
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard();

  @override
  Widget build(BuildContext context) {
    return const _SectionCard(
      child: Row(
        children: [
          _DateBadge(day: '27', month: 'T10'),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ca chiều', style: TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(height: 4),
                Text('14:00 - 22:00 · Tầng 1', style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
          Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.day, required this.month});

  final String day;
  final String month;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3EF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(day, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
          Text(month, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard();

  @override
  Widget build(BuildContext context) {
    return const _SectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Color(0xFFF4E8C8),
            child: Icon(Icons.priority_high, color: Color(0xFFA87412), size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Checklist đầu ca sắp hết hạn', style: TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(height: 4),
                Text('Hoàn thành trước 07:15 hôm nay.', style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E9E3)),
      ),
      child: child,
    );
  }
}
