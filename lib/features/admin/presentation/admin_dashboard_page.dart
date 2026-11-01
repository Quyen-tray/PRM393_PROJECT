import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/repositories/employee_providers.dart';
import '../../../data/repositories/employee_repository.dart';
import 'widgets/admin_bottom_navigation.dart';
import 'widgets/admin_more_menu.dart';

/// Số liệu của dashboard admin. Chỉ gồm những số có API tương ứng.
class _AdminStats {
  const _AdminStats({
    required this.storeName,
    required this.accountTotal,
    required this.accountActive,
    required this.courseActive,
    required this.checklistCodes,
  });

  final String storeName;
  final int accountTotal;
  final int accountActive;
  final int courseActive;
  final int checklistCodes;
}

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  _AdminStats? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  /// Đọc toàn bộ tài khoản theo trang để đếm tổng và số đang hoạt động.
  Future<List<Map<String, dynamic>>> _allAccounts(EmployeeRepository repo) async {
    final all = <Map<String, dynamic>>[];
    for (var page = 0; page < 100; page++) {
      final items = await repo.getAdminUsers(page: page);
      all.addAll(items);
      if (items.length < 50) break;
    }
    return all;
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(employeeRepositoryProvider);
      final results = await Future.wait<Object>([
        repo.getCurrentStore(), // 0
        _allAccounts(repo), // 1
        repo.getTrainingCourses(), // 2
        repo.getAdminChecklistTemplates(), // 3
      ]);
      if (!mounted) return;

      final store = results[0] as Map<String, dynamic>;
      final accounts = results[1] as List<Map<String, dynamic>>;
      final courses = results[2] as List<Map<String, dynamic>>;
      final templates = results[3] as List<Map<String, dynamic>>;

      setState(() {
        _stats = _AdminStats(
          storeName: (store['name'] ?? 'Cửa hàng').toString(),
          accountTotal: accounts.length,
          accountActive: accounts.where((row) => row['status'] == 'ACTIVE').length,
          courseActive: courses.where((row) => row['isActive'] != false).length,
          checklistCodes: templates.map((row) => row['checklistCode']).toSet().length,
        );
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is ApiException
            ? error.message
            : 'Không tải được số liệu quản trị. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.coffee, color: Color(0xFFF1D2A6)),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'HRM COFFEE SHOP',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Làm mới',
                      onPressed: _loading ? null : _load,
                      color: Colors.white,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Dashboard Admin',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Quản trị hệ thống · ${stats?.storeName ?? '…'}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              if (_loading && stats == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (stats == null)
                Column(
                  children: [
                    Text(_error ?? 'Không tải được số liệu.', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _load, child: const Text('Thử lại')),
                  ],
                )
              else ...[
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 900 ? 4 : 2;
                    final tileWidth = (constraints.maxWidth - 10 * (columns - 1)) / columns;
                    final metrics = [
                      _Metric('Tài khoản', '${stats.accountTotal}', Icons.badge_outlined, const Color(0xFF2196F3)),
                      _Metric('Đang hoạt động', '${stats.accountActive}', Icons.verified_user_outlined, const Color(0xFF28A765)),
                      _Metric('Khóa học đang mở', '${stats.courseActive}', Icons.school_outlined, const Color(0xFFE39A2F)),
                      _Metric('Mẫu checklist', '${stats.checklistCodes}', Icons.fact_check_outlined, const Color(0xFFE75B59)),
                    ];
                    return GridView.count(
                      crossAxisCount: columns,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: tileWidth / 112,
                      children: [for (final metric in metrics) _MetricCard(metric: metric)],
                    );
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  'Số nhân viên và biểu đồ xu hướng chưa có trong dashboard admin: vai trò này không có quyền xem danh sách nhân viên.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
              const SizedBox(height: 22),
              const Text(
                'Truy cập nhanh',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              _QuickLink(
                label: 'Quản lý tài khoản',
                icon: Icons.manage_accounts_outlined,
                route: RouteNames.adminAccounts,
              ),
              _QuickLink(
                label: 'Quản lý chức vụ',
                icon: Icons.badge_outlined,
                route: RouteNames.adminPositions,
              ),
              _QuickLink(
                label: 'Quản lý đào tạo',
                icon: Icons.school_outlined,
                route: RouteNames.adminTraining,
              ),
              _QuickLink(
                label: 'Quản lý checklist',
                icon: Icons.fact_check_outlined,
                route: RouteNames.adminChecklistTemplates,
              ),
              _QuickLink(
                label: 'Cấu hình hệ thống',
                icon: Icons.settings_outlined,
                route: RouteNames.adminSettings,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AdminBottomNavigation(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index == 1) context.go(RouteNames.adminAccounts);
          if (index == 2) context.go(RouteNames.adminPositions);
          if (index == 3) context.go(RouteNames.adminTraining);
          if (index == 4) showAdminMoreMenu(context);
        },
      ),
    );
  }
}

class _Metric {
  const _Metric(this.label, this.value, this.icon, this.color);

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
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 21, fontWeight: FontWeight.w800),
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

class _QuickLink extends StatelessWidget {
  const _QuickLink({required this.label, required this.icon, required this.route});

  final String label;
  final IconData icon;
  final String route;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEDE8E3)),
        ),
        child: ListTile(
          onTap: () => context.go(route),
          leading: Icon(icon, color: AppColors.primary),
          title: Text(label, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
