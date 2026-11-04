import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../domain/entities/user.dart';
import 'sign_out_flow.dart';

enum WorkspaceKind { admin, manager, employee, hr }

class WorkspaceOption {
  const WorkspaceOption({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.route,
    required this.icon,
    required this.enabled,
    this.disabledReason,
  });

  final WorkspaceKind kind;
  final String title;
  final String subtitle;
  final String route;
  final IconData icon;
  final bool enabled;
  final String? disabledReason;
}

List<WorkspaceOption> workspaceOptionsFor(User user) {
  final options = <WorkspaceOption>[];
  const hrPermissions = {
    'ATTENDANCE_ADJUST_HR',
    'PAYROLL_FINALIZE',
    'PAYROLL_PERIOD_MANAGE',
    'EMPLOYEE_MANAGE',
    'DOCUMENT_REVIEW',
    'TRAINING_MANAGE',
  };
  if (user.permissions.any(hrPermissions.contains)) {
    options.add(
      const WorkspaceOption(
        kind: WorkspaceKind.hr,
        title: 'Nghiệp vụ HR',
        subtitle:
            'Hồ sơ, điều chỉnh công và đối soát kỳ công theo quyền được cấp',
        route: RouteNames.hrHome,
        icon: Icons.assignment_ind_outlined,
        enabled: true,
      ),
    );
  }
  if (user.hasRole('SYSTEM_ADMIN')) {
    options.add(
      const WorkspaceOption(
        kind: WorkspaceKind.admin,
        title: 'Quản trị hệ thống',
        subtitle: 'Tài khoản, chức vụ, khóa học và cấu hình cửa hàng',
        route: RouteNames.adminHome,
        icon: Icons.settings_suggest_outlined,
        enabled: true,
      ),
    );
  }
  if (user.hasRole('STORE_MANAGER') || user.hasRole('OPERATIONS_DIRECTOR')) {
    options.add(
      const WorkspaceOption(
        kind: WorkspaceKind.manager,
        title: 'Quản lý cửa hàng',
        subtitle: 'Nhân viên, lịch làm, chấm công và duyệt yêu cầu',
        route: RouteNames.home,
        icon: Icons.storefront_outlined,
        enabled: true,
      ),
    );
  }
  if (user.hasRole('EMPLOYEE')) {
    final linked = user.employeeId != null;
    options.add(
      WorkspaceOption(
        kind: WorkspaceKind.employee,
        title: 'Nhân viên',
        subtitle: linked
            ? 'Ca làm, check-in, checklist và đào tạo'
            : 'Tài khoản chưa được liên kết hồ sơ nhân viên',
        route: RouteNames.employeeHome,
        icon: Icons.badge_outlined,
        enabled: linked,
        disabledReason: linked
            ? null
            : 'Liên hệ Admin để hoàn tất hồ sơ nhân viên.',
      ),
    );
  }
  return options;
}

class RoleSelectionPage extends ConsumerWidget {
  const RoleSelectionPage({required this.user, super.key});

  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = workspaceOptionsFor(user);
    final name = user.fullName.trim().isEmpty ? user.email : user.fullName;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chọn không gian làm việc'),
        actions: [
          TextButton.icon(
            onPressed: () => signOutAndReturnToLogin(context, ref),
            icon: const Icon(Icons.logout),
            label: const Text('Đăng xuất'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.coffee_rounded,
                    color: Color(0xFFF1D2A6),
                    size: 30,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Xin chào, $name',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tài khoản có nhiều vai trò. Chọn khu vực bạn muốn sử dụng.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                if (options.isEmpty)
                  const _NoWorkspaceCard()
                else
                  for (final option in options) ...[
                    _WorkspaceCard(
                      option: option,
                      onTap: option.enabled
                          ? () => context.go(option.route)
                          : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                const SizedBox(height: 8),
                Text(
                  user.email,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard({required this.option, required this.onTap});

  final WorkspaceOption option;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final active = option.enabled;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: active ? const Color(0xFFE5D8CE) : const Color(0xFFEDE8E3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFFF3E8DF)
                      : const Color(0xFFF2F0EE),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  option.icon,
                  color: active ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: TextStyle(
                        color: active
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      option.disabledReason ?? option.subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                active ? Icons.chevron_right_rounded : Icons.lock_outline,
                color: active ? AppColors.primary : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoWorkspaceCard extends StatelessWidget {
  const _NoWorkspaceCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE5D8CE)),
    ),
    child: const Text(
      'Tài khoản chưa được cấp vai trò trong ứng dụng. Hãy liên hệ quản trị viên.',
      textAlign: TextAlign.center,
      style: TextStyle(color: AppColors.textSecondary),
    ),
  );
}
