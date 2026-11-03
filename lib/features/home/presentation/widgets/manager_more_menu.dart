import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';

const _signOutDestination = '__sign_out__';

Future<void> showManagerMoreMenu(
  BuildContext context, {
  required Future<void> Function() onSignOut,
}) async {
  final destination = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ListView(
          shrinkWrap: true,
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
              leading: const Icon(Icons.person_outline),
              title: const Text('Hồ sơ cá nhân'),
              onTap: () => Navigator.pop(sheetContext, RouteNames.profile),
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
              leading: const Icon(Icons.payments_outlined),
              title: const Text('Thưởng/phạt'),
              onTap: () => Navigator.pop(
                sheetContext,
                RouteNames.managerRewards,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('Kỳ công'),
              onTap: () => Navigator.pop(
                sheetContext,
                RouteNames.managerPayroll,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.report_outlined),
              title: const Text('Xét duyệt vi phạm'),
              onTap: () => Navigator.pop(
                sheetContext,
                RouteNames.managerViolations,
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
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('\u0110\u0103ng xu\u1ea5t'),
              onTap: () => Navigator.pop(sheetContext, _signOutDestination),
            ),
          ],
        ),
      ),
    ),
  );

  if (!context.mounted || destination == null) return;
  if (destination == _signOutDestination) {
    await onSignOut();
    return;
  }
  context.go(destination);
}
