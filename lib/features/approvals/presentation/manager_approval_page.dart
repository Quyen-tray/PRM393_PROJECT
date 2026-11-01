import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/repositories/employee_providers.dart';
import '../../home/presentation/widgets/manager_more_menu.dart';
import '../data/manager_review_items.dart';
import 'widgets/manager_review_list.dart';

/// Hub Duyệt: mọi yêu cầu chờ quản lý duyệt (giải trình, điều chỉnh công, tăng ca,
/// checklist, thiết bị), lấy từ API.
class ManagerApprovalPage extends ConsumerStatefulWidget {
  const ManagerApprovalPage({super.key});

  @override
  ConsumerState<ManagerApprovalPage> createState() => _ManagerApprovalPageState();
}

class _ManagerApprovalPageState extends ConsumerState<ManagerApprovalPage> {
  ManagerReviewBuckets? _buckets;
  bool _loading = true;
  bool _acting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final buckets = await loadManagerReviewBuckets(ref.read(employeeRepositoryProvider));
      if (mounted) setState(() => _buckets = buckets);
    } catch (error) {
      if (mounted) setState(() => _error = _messageOf(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(ManagerReviewItem item) =>
      _run(() => approveManagerReviewItem(ref.read(employeeRepositoryProvider), item), 'Đã duyệt.');

  Future<void> _reject(ManagerReviewItem item, String reason) => _run(
        () => rejectManagerReviewItem(ref.read(employeeRepositoryProvider), item, reason: reason),
        'Đã từ chối.',
      );

  Future<void> _run(Future<void> Function() action, String successMessage) async {
    setState(() => _acting = true);
    try {
      await action();
      _message(successMessage);
      await _load();
    } catch (error) {
      _message(_messageOf(error));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  String _messageOf(Object error) =>
      error is ApiException ? error.message : 'Không tải được danh sách duyệt. Vui lòng thử lại.';

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final buckets = _buckets;
    final busy = _loading || _acting;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Duyệt yêu cầu'),
          actions: [
            IconButton(
              tooltip: 'Tải lại',
              onPressed: busy ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'Duyệt thiết bị chấm công',
              onPressed: () => context.go(RouteNames.managerDevices),
              icon: const Icon(Icons.phone_android),
            ),
            IconButton(
              tooltip: 'Duyệt checklist',
              onPressed: () => context.go(RouteNames.managerChecklistApprovals),
              icon: const Icon(Icons.fact_check_outlined),
            ),
            IconButton(
              tooltip: 'Duyệt giải trình và điều chỉnh công',
              onPressed: () => context.go(RouteNames.managerAttendanceRequests),
              icon: const Icon(Icons.access_time),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: 'Chờ duyệt (${buckets?.pending.length ?? 0})'),
              const Tab(text: 'Đã duyệt'),
              const Tab(text: 'Đã từ chối'),
            ],
          ),
        ),
        body: buckets == null
            ? (_loading
                ? const Center(child: CircularProgressIndicator())
                : _ErrorView(message: _error ?? 'Không tải được danh sách duyệt.', onRetry: _load))
            : TabBarView(
                children: [
                  ManagerReviewList(
                    items: buckets.pending,
                    emptyMessage: 'Không có yêu cầu đang chờ duyệt.',
                    busy: busy,
                    onApprove: _approve,
                    onReject: _reject,
                    onRefresh: _load,
                  ),
                  ManagerReviewList(
                    items: buckets.approved,
                    emptyMessage: 'Chưa có yêu cầu đã được duyệt.',
                    busy: busy,
                    onApprove: _approve,
                    onReject: _reject,
                    onRefresh: _load,
                  ),
                  ManagerReviewList(
                    items: buckets.rejected,
                    emptyMessage: 'Chưa có yêu cầu bị từ chối.',
                    busy: busy,
                    onApprove: _approve,
                    onReject: _reject,
                    onRefresh: _load,
                  ),
                ],
              ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: 3,
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
            if (index == 4) showManagerMoreMenu(context);
          },
        ),
      ),
    );
  }
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
