import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../data/mock/demo_data.dart';

class ManagerReviewCard extends StatelessWidget {
  const ManagerReviewCard({
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.evidence,
    required this.status,
    required this.onApprove,
    required this.onReject,
    this.rejectionReason,
    super.key,
  });

  final String title;
  final String subtitle;
  final String detail;
  final String evidence;
  final DemoManagerReviewStatus status;
  final String? rejectionReason;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final isPending = status == DemoManagerReviewStatus.pendingManager;

    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFEDE8E3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _ReviewStatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              detail,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.attach_file, size: 16),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    evidence,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
            if (rejectionReason != null) ...[
              const SizedBox(height: 8),
              Text(
                'Lý do từ chối: $rejectionReason',
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 11,
                ),
              ),
            ],
            if (isPending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onReject,
                      child: const Text('Từ chối'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: onApprove,
                      child: const Text('Duyệt'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReviewStatusBadge extends StatelessWidget {
  const _ReviewStatusBadge({required this.status});

  final DemoManagerReviewStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      DemoManagerReviewStatus.pendingManager => ('Chờ duyệt', Colors.orange),
      DemoManagerReviewStatus.pendingHr => ('Chờ HR', Colors.blue),
      DemoManagerReviewStatus.approved => ('Đã duyệt', Colors.green),
      DemoManagerReviewStatus.rejected => ('Từ chối', AppColors.error),
    };

    return Chip(
      label: Text(label),
      labelStyle: TextStyle(color: color, fontSize: 10),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}
