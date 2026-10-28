import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../data/mock/demo_data.dart';
import '../../home/presentation/widgets/manager_more_menu.dart';
import 'widgets/manager_review_card.dart';

class ManagerApprovalPage extends StatefulWidget {
  const ManagerApprovalPage({super.key});

  @override
  State<ManagerApprovalPage> createState() => _ManagerApprovalPageState();
}

class _ManagerApprovalPageState extends State<ManagerApprovalPage> {
  final Map<String, DemoManagerReviewStatus> _statusOverrides = {};
  final Map<String, String> _rejectionReasons = {};

  List<_ApprovalEntry> get _entries => [
        for (final request in DemoData.managerAttendanceAdjustmentRequests)
          _ApprovalEntry(
            id: 'adjustment-${request.id}',
            initialStatus: request.status,
            approvedStatus: DemoManagerReviewStatus.pendingHr,
            approveMessage: 'Đã duyệt nghiệp vụ và chuyển đơn sang HR.',
            title: request.employeeName,
            subtitle: '${request.employeeCode} · ${request.position}',
            detail: '${request.workDate} · '
                '${request.adjustmentLabel}: ${request.requestedValue}\n'
                'Lý do: ${request.reason}\n'
                'Gửi lúc: ${request.submittedAt}',
            evidence: request.evidenceLabel,
          ),
        for (final request in DemoData.managerOtherRequests)
          _ApprovalEntry(
            id: 'manager-request-${request.id}',
            initialStatus: request.status,
            approvedStatus: DemoManagerReviewStatus.approved,
            approveMessage: request.type.approvedMessage,
            title: request.employeeName,
            subtitle: '${request.employeeCode} · ${request.position} · '
                '${request.type.displayLabel}',
            detail: '${request.detail}\n'
                'Lý do: ${request.reason}\n'
                'Gửi lúc: ${request.submittedAt}',
            evidence: request.evidenceLabel,
            initialRejectionReason: request.reviewReason,
          ),
      ];

  DemoManagerReviewStatus _statusOf(_ApprovalEntry entry) =>
      _statusOverrides[entry.id] ?? entry.initialStatus;

  bool _isInBucket(_ApprovalEntry entry, _ApprovalBucket bucket) {
    final status = _statusOf(entry);
    return switch (bucket) {
      _ApprovalBucket.pending => status == DemoManagerReviewStatus.pendingManager,
      _ApprovalBucket.approved =>
        status == DemoManagerReviewStatus.pendingHr ||
            status == DemoManagerReviewStatus.approved,
      _ApprovalBucket.rejected => status == DemoManagerReviewStatus.rejected,
    };
  }

  int _countFor(_ApprovalBucket bucket) =>
      _entries.where((entry) => _isInBucket(entry, bucket)).length;

  void _setStatus(
    _ApprovalEntry entry,
    DemoManagerReviewStatus status, {
    required String message,
  }) {
    setState(() => _statusOverrides[entry.id] = status);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _rejectWithReason(_ApprovalEntry entry) async {
    final controller = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          title: const Text('Từ chối yêu cầu'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Lý do từ chối',
              hintText: 'Nhập lý do để nhân viên biết cần xử lý gì',
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
      _statusOverrides[entry.id] = DemoManagerReviewStatus.rejected;
      _rejectionReasons[entry.id] = reason;
    });
  }

  Widget _requestList(_ApprovalBucket bucket) {
    final entries = _entries.where((entry) => _isInBucket(entry, bucket));
    final items = entries.toList();

    if (items.isEmpty) {
      return Center(
        child: Text(
          bucket.emptyMessage,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final entry in items)
          ManagerReviewCard(
            title: entry.title,
            subtitle: entry.subtitle,
            detail: entry.detail,
            evidence: entry.evidence,
            status: _statusOf(entry),
            rejectionReason:
                _rejectionReasons[entry.id] ?? entry.initialRejectionReason,
            onApprove: _statusOf(entry) == DemoManagerReviewStatus.pendingManager
                ? () => _setStatus(
                      entry,
                      entry.approvedStatus,
                      message: entry.approveMessage,
                    )
                : null,
            onReject: _statusOf(entry) == DemoManagerReviewStatus.pendingManager
                ? () => _rejectWithReason(entry)
                : null,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Duyệt yêu cầu'),
          actions: [
            IconButton(
              tooltip: 'Duyệt checklist',
              onPressed: () => context.go(RouteNames.managerChecklistApprovals),
              icon: const Icon(Icons.fact_check_outlined),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: 'Chờ duyệt (${_countFor(_ApprovalBucket.pending)})'),
              const Tab(text: 'Đã duyệt'),
              const Tab(text: 'Đã từ chối'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _requestList(_ApprovalBucket.pending),
            _requestList(_ApprovalBucket.approved),
            _requestList(_ApprovalBucket.rejected),
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

class _ApprovalEntry {
  const _ApprovalEntry({
    required this.id,
    required this.initialStatus,
    required this.approvedStatus,
    required this.approveMessage,
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.evidence,
    this.initialRejectionReason,
  });

  final String id;
  final DemoManagerReviewStatus initialStatus;
  final DemoManagerReviewStatus approvedStatus;
  final String approveMessage;
  final String title;
  final String subtitle;
  final String detail;
  final String evidence;
  final String? initialRejectionReason;
}

enum _ApprovalBucket { pending, approved, rejected }

extension on _ApprovalBucket {
  String get emptyMessage => switch (this) {
        _ApprovalBucket.pending => 'Không có yêu cầu đang chờ duyệt.',
        _ApprovalBucket.approved => 'Chưa có yêu cầu đã được duyệt.',
        _ApprovalBucket.rejected => 'Chưa có yêu cầu bị từ chối.',
      };
}

extension on DemoManagerRequestType {
  String get displayLabel => switch (this) {
        DemoManagerRequestType.gpsException => 'Ngoại lệ GPS',
        DemoManagerRequestType.deviceChange => 'Đổi thiết bị',
        DemoManagerRequestType.overtime => 'Đề nghị OT',
      };

  String get approvedMessage => switch (this) {
        DemoManagerRequestType.gpsException =>
          'Đã ghi nhận duyệt ngoại lệ GPS trong phiên demo.',
        DemoManagerRequestType.deviceChange =>
          'Đã ghi nhận duyệt thiết bị trong phiên demo.',
        DemoManagerRequestType.overtime =>
          'Đã ghi nhận duyệt OT trong phiên demo.',
      };
}
