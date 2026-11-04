import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/repositories/employee_providers.dart';
import '../../../data/repositories/employee_repository.dart';

class HrWorkspacePage extends ConsumerStatefulWidget {
  const HrWorkspacePage({super.key});

  @override
  ConsumerState<HrWorkspacePage> createState() => _HrWorkspacePageState();
}

class _HrWorkspacePageState extends ConsumerState<HrWorkspacePage> {
  CurrentAccess? _access;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final access = await ref
          .read(employeeRepositoryProvider)
          .getCurrentAccess();
      if (mounted) setState(() => _access = access);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Không tải được quyền HR.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = _access;
    final tasks =
        <({String title, String detail, IconData icon, String route})>[
          if (access?.permissions.contains('ATTENDANCE_ADJUST_HR') == true)
            (
              title: 'Điều chỉnh công chờ HR',
              detail: 'Xem yêu cầu, đối chiếu chứng từ, duyệt hoặc từ chối.',
              icon: Icons.fact_check_outlined,
              route: RouteNames.hrAttendanceAdjustments,
            ),
          if (access?.canViewPayroll == true)
            (
              title: 'Đối soát và chốt kỳ công',
              detail:
                  'Xem readiness, HR finalize hoặc mở lại khi được cấp quyền.',
              icon: Icons.payments_outlined,
              route: RouteNames.managerPayroll,
            ),
          if (access?.canManageEmployees == true)
            (
              title: 'Hồ sơ nhân viên',
              detail: 'Tra cứu và cập nhật hồ sơ theo phạm vi được cấp.',
              icon: Icons.people_outline,
              route: RouteNames.managerEmployees,
            ),
          if (access?.canReviewDocuments == true)
            (
              title: 'Duyệt giấy tờ',
              detail: 'Xử lý hồ sơ đang chờ và xem lý do khi bị từ chối.',
              icon: Icons.description_outlined,
              route: RouteNames.managerDocumentReview,
            ),
          if (access?.canManageTraining == true)
            (
              title: 'Tiến độ đào tạo',
              detail: 'Xem tiến độ và duyệt hoàn thành khóa học.',
              icon: Icons.school_outlined,
              route: RouteNames.managerTrainingCompletions,
            ),
          if (access?.permissions.contains('DASHBOARD_MANAGER') == true)
            (
              title: 'Báo cáo',
              detail: 'Báo cáo chấm công và vận hành.',
              icon: Icons.bar_chart_outlined,
              route: RouteNames.managerOperations,
            ),
        ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Nghiệp vụ HR'),
        leading: IconButton(
          onPressed: () => context.go(RouteNames.login),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _load, child: const Text('Thử lại')),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Các mục dưới đây được dựng từ quyền hiệu lực của tài khoản. Máy chủ vẫn kiểm tra quyền ở mỗi thao tác.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  if (tasks.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: Text(
                          'Tài khoản hiện chưa có quyền nghiệp vụ HR. Hãy nhờ Admin kiểm tra tập quyền.',
                        ),
                      ),
                    ),
                  for (final task in tasks)
                    Card(
                      color: AppColors.surface,
                      child: ListTile(
                        leading: CircleAvatar(child: Icon(task.icon)),
                        title: Text(
                          task.title,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(task.detail),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.go(task.route),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
