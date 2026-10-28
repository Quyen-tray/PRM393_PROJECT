import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';

Future<void> showManagerMoreMenu(BuildContext context) async {
  final destination = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Text(
                'Chức năng khác',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart_outlined),
              title: const Text('Báo cáo chấm công'),
              onTap: () => Navigator.pop(
                sheetContext,
                RouteNames.managerAttendanceReport,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.fact_check_outlined),
              title: const Text('Duyệt checklist'),
              onTap: () => Navigator.pop(
                sheetContext,
                RouteNames.managerChecklistApprovals,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  if (!context.mounted || destination == null) return;
  context.go(destination);
}
