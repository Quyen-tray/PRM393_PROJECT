import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/repositories/employee_providers.dart';
import '../../../data/repositories/employee_repository.dart';
import '../../../shared/widgets/employee_bottom_navigation.dart';

class EmployeeDashboardPage extends ConsumerStatefulWidget {
  const EmployeeDashboardPage({super.key});

  @override
  ConsumerState<EmployeeDashboardPage> createState() =>
      _EmployeeDashboardPageState();
}

class _EmployeeDashboardPageState extends ConsumerState<EmployeeDashboardPage> {
  late Future<_EmployeeDashboardData> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadDashboard();
  }

  Future<_EmployeeDashboardData> _loadDashboard() async {
    final repository = ref.read(employeeRepositoryProvider);
    final results = await Future.wait<Object?>([
      repository.getEmployeeProfile(),
      repository.getEmployeeOverview(),
      repository.getCurrentShift(),
      repository.getCurrentAccess(),
    ]);
    return _EmployeeDashboardData(
      employee: results[0] as Map<String, dynamic>?,
      overview: results[1] as Map<String, dynamic>?,
      currentShift: results[2] as Map<String, dynamic>?,
      access: results[3] as CurrentAccess,
    );
  }

  void _reload() => setState(() => _dashboardFuture = _loadDashboard());

  @override
  Widget build(BuildContext context) {
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
                  child: FutureBuilder<_EmployeeDashboardData>(
                    future: _dashboardFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError || !snapshot.hasData) {
                        return ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                          children: [
                            _DashboardLoadError(
                              message:
                                  snapshot.error?.toString() ??
                                  'Không tải được dữ liệu.',
                              onRetry: _reload,
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'Nếu tài khoản chưa được gắn hồ sơ nhân viên, '
                                'nhờ Quản lý/Admin hoàn tất liên kết để tải '
                                'lịch và công việc.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Chức năng nhân viên',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 12),
                            _quickAccessGrid(
                              context,
                              canReviewDocuments: false,
                              showCheckIn: true,
                            ),
                          ],
                        );
                      }
                      final data = snapshot.data!;
                      final employee = data.employee ?? <String, dynamic>{};
                      final overview = data.overview ?? <String, dynamic>{};
                      final currentShift = data.currentShift;
                      final nextShift = overview['nextShift'] is Map
                          ? Map<String, dynamic>.from(
                              overview['nextShift'] as Map,
                            )
                          : null;
                      final shift = currentShift ?? nextShift;
                      final name = (employee['fullName'] ?? 'Nhân viên')
                          .toString();
                      final position = (employee['jobTitle'] ?? 'Nhân viên')
                          .toString();
                      final status = employmentStatusLabel(
                        employee['employmentStatus']?.toString(),
                      );
                      return RefreshIndicator(
                        onRefresh: () async => _reload(),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                          children: [
                            _EmployeeGreeting(
                              name: name,
                              position: position,
                              status: status,
                              onProfileTap: () =>
                                  context.go(RouteNames.employeeProfile),
                            ),
                            const SizedBox(height: 18),
                            _ShiftCard(
                              shift: shift,
                              attendanceStatus:
                                  (currentShift?['attendanceStatus'] ??
                                          'Chưa check-in')
                                      .toString(),
                              onCheckInTap: () =>
                                  context.go(RouteNames.checkIn),
                            ),
                            const SizedBox(height: 14),
                            _OverviewSummary(
                              openChecklists: overview['openChecklists'],
                              unreadNotifications:
                                  overview['unreadNotifications'],
                              profileStatus: overview['profileStatus'],
                              shiftEligibility: overview['shiftEligibility'],
                            ),
                            const SizedBox(height: 22),
                            Text(
                              'Truy cập nhanh',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 12),
                            _quickAccessGrid(
                              context,
                              canReviewDocuments:
                                  data.access.canReviewDocuments,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const EmployeeBottomNavigation(selectedIndex: 0),
    );
  }

  Widget _quickAccessGrid(
    BuildContext context, {
    required bool canReviewDocuments,
    bool showCheckIn = false,
  }) => _QuickAccessGrid(
    canReviewDocuments: canReviewDocuments,
    showCheckIn: showCheckIn,
    onCheckInTap: () => context.go(RouteNames.checkIn),
    onScheduleTap: () => context.go(RouteNames.employeeSchedule),
    onChecklistTap: () => context.go(RouteNames.employeeChecklist),
    onTrainingTap: () => context.go(RouteNames.employeeTraining),
    onProfileTap: () => context.go(RouteNames.employeeProfile),
    onNotificationsTap: () => context.go(RouteNames.employeeNotifications),
    onAttendanceHistoryTap: () =>
        context.go(RouteNames.employeeAttendanceHistory),
    onDocumentsTap: () => context.go(RouteNames.employeeDocuments),
    onDocumentReviewTap: () => context.go(RouteNames.managerDocumentReview),
    onViolationsTap: () => context.go(RouteNames.employeeViolations),
    onRewardsTap: () => context.go(RouteNames.employeeRewards),
  );
}

class _EmployeeDashboardData {
  const _EmployeeDashboardData({
    required this.employee,
    required this.overview,
    required this.currentShift,
    required this.access,
  });

  final Map<String, dynamic>? employee;
  final Map<String, dynamic>? overview;
  final Map<String, dynamic>? currentShift;
  final CurrentAccess access;
}

class _DashboardLoadError extends StatelessWidget {
  const _DashboardLoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 42),
          const SizedBox(height: 12),
          const Text(
            'Không thể tải trang chủ',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    ),
  );
}

class _OverviewSummary extends StatelessWidget {
  const _OverviewSummary({
    required this.openChecklists,
    required this.unreadNotifications,
    required this.profileStatus,
    required this.shiftEligibility,
  });
  final dynamic openChecklists;
  final dynamic unreadNotifications;
  final dynamic profileStatus;
  final dynamic shiftEligibility;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE5E1DA)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tổng quan', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('Checklist đang mở: ${openChecklists ?? 0}'),
        Text('Thông báo chưa đọc: ${unreadNotifications ?? 0}'),
        Text(
          'Tình trạng hồ sơ: ${employeeProfileStatusLabel(profileStatus?.toString())}',
        ),
        Text(
          'Điều kiện nhận ca: ${shiftEligibilityLabel(shiftEligibility?.toString())}',
        ),
      ],
    ),
  );
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
                  'BeanHub',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Hệ thống quản lý nhân sự',
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
    required this.name,
    required this.position,
    required this.status,
    required this.onProfileTap,
  });
  final String name;
  final String position;
  final String status;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) => Row(
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
              name,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              position,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              status,
              style: const TextStyle(
                color: Color(0xFF25804B),
                fontSize: 10,
                fontWeight: FontWeight.w600,
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

class _ShiftCard extends StatelessWidget {
  const _ShiftCard({
    required this.shift,
    required this.attendanceStatus,
    required this.onCheckInTap,
  });
  final Map<String, dynamic>? shift;
  final String attendanceStatus;
  final VoidCallback onCheckInTap;

  String _time(dynamic value) => formatClockVn(value);

  @override
  Widget build(BuildContext context) {
    final start = _time(shift?['plannedStartAt']);
    final end = _time(shift?['plannedEndAt']);
    final canCheckIn = shift != null && shift?['canCheckIn'] == true;
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
                  'Ca làm tiếp theo',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                shift == null ? 'Chưa có ca' : attendanceStatus,
                style: const TextStyle(color: Color(0xFF96631D), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            shift == null
                ? 'Bạn chưa có lịch làm được công bố.'
                : '$start - $end',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 25,
              height: 1.1,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (shift != null) ...[
            const SizedBox(height: 4),
            Text(
              (shift!['shiftName'] ?? 'Ca làm đã phân công').toString(),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: canCheckIn ? onCheckInTap : null,
              child: const Text('Check-in'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAccessGrid extends StatelessWidget {
  const _QuickAccessGrid({
    required this.onCheckInTap,
    this.showCheckIn = false,
    required this.onScheduleTap,
    required this.onChecklistTap,
    required this.onTrainingTap,
    required this.onProfileTap,
    required this.onNotificationsTap,
    required this.onAttendanceHistoryTap,
    required this.onDocumentsTap,
    required this.canReviewDocuments,
    required this.onDocumentReviewTap,
    required this.onViolationsTap,
    required this.onRewardsTap,
  });

  final VoidCallback onCheckInTap;
  final bool showCheckIn;
  final VoidCallback onScheduleTap;
  final VoidCallback onChecklistTap;
  final VoidCallback onTrainingTap;
  final VoidCallback onProfileTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onAttendanceHistoryTap;
  final VoidCallback onDocumentsTap;
  final bool canReviewDocuments;
  final VoidCallback onDocumentReviewTap;
  final VoidCallback onViolationsTap;
  final VoidCallback onRewardsTap;

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
        if (showCheckIn)
          _QuickAccessTile(
            icon: Icons.login_rounded,
            title: 'Check-in',
            color: const Color(0xFF8A5032),
            onTap: onCheckInTap,
          ),
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
        _QuickAccessTile(
          icon: Icons.fact_check_outlined,
          title: 'Lịch sử công',
          color: const Color(0xFF5D7899),
          onTap: onAttendanceHistoryTap,
        ),
        _QuickAccessTile(
          icon: Icons.folder_outlined,
          title: 'Hồ sơ giấy tờ',
          color: const Color(0xFF8662A8),
          onTap: onDocumentsTap,
        ),
        _QuickAccessTile(
          icon: Icons.report_gmailerrorred_outlined,
          title: 'Vi phạm',
          color: const Color(0xFFB65048),
          onTap: onViolationsTap,
        ),
        _QuickAccessTile(
          icon: Icons.redeem_outlined,
          title: 'Thưởng / phạt',
          color: const Color(0xFF3D8472),
          onTap: onRewardsTap,
        ),
        if (canReviewDocuments)
          _QuickAccessTile(
            icon: Icons.fact_check_outlined,
            title: 'Duyệt hồ sơ',
            color: const Color(0xFF8A5032),
            onTap: onDocumentReviewTap,
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
