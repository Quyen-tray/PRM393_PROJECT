import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../data/manager_review_items.dart';
import 'manager_review_card.dart';

/// Danh sách mục duyệt dùng chung cho hub Duyệt và màn duyệt checklist.
/// Kéo để làm mới ở cả trường hợp danh sách rỗng.
class ManagerReviewList extends StatelessWidget {
  const ManagerReviewList({
    required this.items,
    required this.emptyMessage,
    required this.busy,
    required this.onApprove,
    required this.onReject,
    required this.onRefresh,
    this.onSelect,
    super.key,
  });

  final List<ManagerReviewItem> items;
  final String emptyMessage;

  /// Khi đang xử lý một thao tác hoặc đang tải, nút duyệt/từ chối bị tắt.
  final bool busy;
  final Future<void> Function(ManagerReviewItem item) onApprove;
  final Future<void> Function(ManagerReviewItem item, String reason) onReject;
  final Future<void> Function() onRefresh;
  final ValueChanged<ManagerReviewItem>? onSelect;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 160),
            Center(
              child: Text(
                emptyMessage,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          for (final item in items)
            ManagerReviewCard(
              title: item.title,
              subtitle: item.subtitle,
              detail: item.detail,
              evidence: item.evidence,
              status: item.status,
              rejectionReason: item.rejectionReason,
              onTap: onSelect == null ? null : () => onSelect!(item),
              onApprove: item.isPending && !busy ? () => onApprove(item) : null,
              onReject: item.isPending && !busy
                  ? () async {
                      final reason = await _askRejectReason(context);
                      if (reason != null) await onReject(item, reason);
                    }
                  : null,
            ),
        ],
      ),
    );
  }
}

/// Hộp thoại lấy lý do từ chối. Trả về null nếu hủy hoặc để trống.
Future<String?> _askRejectReason(BuildContext context) async {
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
          maxLength: 500,
          onChanged: (_) => updateDialog(() {}),
          decoration: const InputDecoration(
            labelText: 'Lý do từ chối',
            hintText: 'Nhập lý do để nhân viên biết cần xử lý gì',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: controller.text.trim().isEmpty
                ? null
                : () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Xác nhận từ chối'),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  if (reason == null || reason.isEmpty) return null;
  return reason;
}
