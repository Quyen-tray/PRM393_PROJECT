import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/presentation/sign_out_flow.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/repositories/employee_providers.dart';
import '../../home/presentation/widgets/manager_more_menu.dart';
import '../data/manager_review_items.dart';
import 'widgets/manager_review_list.dart';

/// Duyệt checklist: các checklist nhân viên đã nộp, chờ quản lý duyệt, lấy từ API.
class ManagerChecklistApprovalPage extends ConsumerStatefulWidget {
  const ManagerChecklistApprovalPage({super.key});

  @override
  ConsumerState<ManagerChecklistApprovalPage> createState() =>
      _ManagerChecklistApprovalPageState();
}

class _ManagerChecklistApprovalPageState
    extends ConsumerState<ManagerChecklistApprovalPage> {
  static const _kinds = {ManagerReviewKind.checklist};

  List<ManagerReviewItem> _pending = [];
  List<ManagerReviewItem> _processed = [];
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
      final buckets = await loadManagerReviewBuckets(
        ref.read(employeeRepositoryProvider),
        kinds: _kinds,
      );
      if (!mounted) return;
      setState(() {
        _pending = buckets.pending;
        _processed = [...buckets.approved, ...buckets.rejected];
      });
    } catch (error) {
      if (mounted) setState(() => _error = _messageOf(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(ManagerReviewItem item) => _run(
      () =>
          approveManagerReviewItem(ref.read(employeeRepositoryProvider), item),
      'Đã duyệt checklist.');

  Future<void> _reject(ManagerReviewItem item, String reason) => _run(
        () => rejectManagerReviewItem(
            ref.read(employeeRepositoryProvider), item,
            reason: reason),
        'Đã từ chối checklist.',
      );

  Future<void> _run(
      Future<void> Function() action, String successMessage) async {
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

  String _messageOf(Object error) => error is ApiException
      ? error.message
      : 'Không tải được checklist. Vui lòng thử lại.';

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final busy = _loading || _acting;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Duyệt checklist'),
          actions: [
            IconButton(
              tooltip: 'Tải lại',
              onPressed: busy ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'Duyệt yêu cầu',
              onPressed: () => context.go(RouteNames.managerApprovals),
              icon: const Icon(Icons.inbox_outlined),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: 'Chờ duyệt (${_pending.length})'),
              const Tab(text: 'Đã xử lý'),
            ],
          ),
        ),
        body:
            _loading && _pending.isEmpty && _processed.isEmpty && _error == null
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _pending.isEmpty && _processed.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!, textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              FilledButton(
                                  onPressed: _load,
                                  child: const Text('Thử lại')),
                            ],
                          ),
                        ),
                      )
                    : TabBarView(
                        children: [
                          ManagerReviewList(
                            items: _pending,
                            emptyMessage: 'Không có checklist đang chờ duyệt.',
                            busy: busy,
                            onApprove: _approve,
                            onReject: _reject,
                            onRefresh: _load,
                          ),
                          ManagerReviewList(
                            items: _processed,
                            emptyMessage: 'Chưa có checklist đã xử lý.',
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
            if (index == 3) context.go(RouteNames.managerApprovals);
            if (index == 4) {
              showManagerMoreMenu(
                context,
                onSignOut: () => signOutAndReturnToLogin(context, ref),
              );
            }
          },
        ),
      ),
    );
  }
}
