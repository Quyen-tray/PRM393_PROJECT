import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';

const _signOutDestination = '__sign_out__';

Future<void> showAdminMoreMenu(
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
              leading: const Icon(Icons.fact_check_outlined),
              title: const Text('Quản lý checklist'),
              onTap: () => Navigator.pop(
                sheetContext,
                RouteNames.adminChecklistTemplates,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.psychology_outlined),
              title: const Text('Danh mục kỹ năng'),
              onTap: () => Navigator.pop(
                sheetContext,
                RouteNames.adminSkills,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Thông báo đã gửi'),
              onTap: () => Navigator.pop(
                sheetContext,
                RouteNames.adminNotificationDeliveries,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.history_outlined),
              title: const Text('Nhật ký hệ thống'),
              onTap: () => Navigator.pop(
                sheetContext,
                RouteNames.adminAuditLogs,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Cấu hình hệ thống'),
              onTap: () => Navigator.pop(
                sheetContext,
                RouteNames.adminSettings,
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
