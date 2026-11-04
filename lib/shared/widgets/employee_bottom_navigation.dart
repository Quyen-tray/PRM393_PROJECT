import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_names.dart';
import '../../app/theme/app_colors.dart';

/// Thanh điều hướng dưới của nhân viên, dùng cho các màn phụ (đào tạo, thông báo...).
class EmployeeBottomNavigation extends StatelessWidget {
  const EmployeeBottomNavigation({required this.selectedIndex, super.key});

  final int selectedIndex;

  static const _routes = <String>[
    RouteNames.employeeHome,
    RouteNames.employeeSchedule,
    RouteNames.employeeChecklist,
    RouteNames.employeeProfile,
  ];

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      backgroundColor: AppColors.surface,
      indicatorColor: const Color(0xFFF3E5DA),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Trang chủ'),
        NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Lịch'),
        NavigationDestination(icon: Icon(Icons.checklist_outlined), selectedIcon: Icon(Icons.checklist), label: 'Checklist'),
        NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Cá nhân'),
      ],
      onDestinationSelected: (index) => context.go(_routes[index]),
    );
  }
}
