import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../data/mock/demo_data.dart';
import '../../home/presentation/widgets/manager_more_menu.dart';
import 'widgets/manager_review_card.dart';

class ManagerChecklistApprovalPage extends StatefulWidget {
  const ManagerChecklistApprovalPage({super.key});

  @override
  State<ManagerChecklistApprovalPage> createState() =>
      _ManagerChecklistApprovalPageState();
}

class _ManagerChecklistApprovalPageState
    extends State<ManagerChecklistApprovalPage> {
  final Map<String, DemoManagerReviewStatus> _statusOverrides = {};
  final Map<String, String> _rejectionReasons = {};

  String _idFor(DemoChecklistReview review) => 'checklist-${review.id}';

  DemoManagerReviewStatus _statusOf(DemoChecklistReview review) =>
      _statusOverrides[_idFor(review)] ?? review.status;

  int get _pendingCount => DemoData.managerChecklistReviews
      .where((review) =>
          _statusOf(review) == DemoManagerReviewStatus.pendingManager)
      .length;

  void _setStatus(
    DemoChecklistReview review,
    DemoManagerReviewStatus status, {
    required String message,
  }) {
    setState(() => _statusOverrides[_idFor(review)] = status);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _rejectWithReason(DemoChecklistReview review) async {
    final controller = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          title: const Text('Từ chối checklist'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Lý do từ chối',
              hintText: 'Nhập nội dung cần nhân viên làm lại',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => updateDialog(() {}),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: controller.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(
                        dialogContext,
                        controller.text.trim(),
                      ),
              child: const Text('Xác nhận từ chối'),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
    if (!mounted || reason == null || reason.isEmpty) return;

    setState(() {
      _statusOverrides[_idFor(review)] = DemoManagerReviewStatus.rejected;
      _rejectionReasons[_idFor(review)] = reason;
    });
  }

  Widget _reviewList({required bool pendingOnly}) {
    final reviews = DemoData.managerChecklistReviews.where((review) {
      final isPending =
          _statusOf(review) == DemoManagerReviewStatus.pendingManager;
      return pendingOnly ? isPending : !isPending;
    }).toList();

    if (reviews.isEmpty) {
      return Center(
        child: Text(
          pendingOnly
              ? 'Không có checklist đang chờ duyệt.'
              : 'Chưa có checklist đã xử lý.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final review in reviews)
          ManagerReviewCard(
            title: review.employeeName,
            subtitle: '${review.employeeCode} · ${review.checklistTitle}',
            detail: '${review.taskTitle}\n'
                '${review.workDate} · Ca ${review.shiftTime}\n'
                'Gửi lúc: ${review.submittedAt}',
            evidence: review.evidenceLabel,
            status: _statusOf(review),
            rejectionReason: _rejectionReasons[_idFor(review)],
            onApprove: _statusOf(review) ==
                    DemoManagerReviewStatus.pendingManager
                ? () => _setStatus(
                      review,
                      DemoManagerReviewStatus.approved,
                      message: 'Đã duyệt checklist trong phiên demo.',
                    )
                : null,
            onReject: _statusOf(review) ==
                    DemoManagerReviewStatus.pendingManager
                ? () => _rejectWithReason(review)
                : null,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Duyệt checklist'),
          actions: [
            IconButton(
              tooltip: 'Duyệt yêu cầu',
              onPressed: () => context.go(RouteNames.managerApprovals),
              icon: const Icon(Icons.inbox_outlined),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: 'Chờ duyệt ($_pendingCount)'),
              const Tab(text: 'Đã duyệt'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _reviewList(pendingOnly: true),
            _reviewList(pendingOnly: false),
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
            if (index == 4) showManagerMoreMenu(context);
          },
        ),
      ),
    );
  }
}
