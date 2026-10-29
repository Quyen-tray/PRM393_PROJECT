import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';

/// Khung chung cho các màn hình quản trị: AppBar + thanh điều hướng dưới.
/// Mục "Khác" mở menu chứa Chức vụ và Checklist, giống menu Khác của manager.
class AdminScaffold extends StatelessWidget {
  const AdminScaffold({
    super.key,
    required this.title,
    required this.selectedIndex,
    required this.body,
    this.floatingActionButton,
  });

  final String title;
  final int selectedIndex;
  final Widget body;
  final Widget? floatingActionButton;

  static const _routes = [
    RouteNames.adminHome,
    RouteNames.adminAccounts,
    RouteNames.adminTraining,
    RouteNames.adminSettings,
  ];

  static const _moreIndex = 4;

  Future<void> _showMore(BuildContext context) async {
    final route = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Quản lý chức vụ'),
              onTap: () => Navigator.pop(sheetContext, RouteNames.adminPositions),
            ),
            ListTile(
              leading: const Icon(Icons.checklist),
              title: const Text('Quản lý checklist'),
              onTap: () => Navigator.pop(sheetContext, RouteNames.adminChecklists),
            ),
          ],
        ),
      ),
    );

    if (route != null && context.mounted) context.go(route);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: body,
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) {
            if (index == _moreIndex) {
              _showMore(context);
            } else if (index != selectedIndex) {
              context.go(_routes[index]);
            }
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Tổng quan',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Tài khoản',
            ),
            NavigationDestination(
              icon: Icon(Icons.school_outlined),
              selectedIcon: Icon(Icons.school),
              label: 'Đào tạo',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Cấu hình',
            ),
            NavigationDestination(
              icon: Icon(Icons.more_horiz),
              label: 'Khác',
            ),
          ],
        ),
      );
}
