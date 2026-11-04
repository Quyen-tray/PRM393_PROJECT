import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../auth/presentation/sign_out_flow.dart';
import 'manager_more_menu.dart';

class ManagerBottomNavigation extends ConsumerWidget {
  const ManagerBottomNavigation({required this.selectedIndex, super.key});

  final int selectedIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      backgroundColor: AppColors.surface,
      indicatorColor: const Color(0xFFF3E5DA),
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
        switch (index) {
          case 0:
            context.go(RouteNames.home);
            break;
          case 1:
            context.go(RouteNames.managerEmployees);
            break;
          case 2:
            context.go(RouteNames.managerSchedule);
            break;
          case 3:
            context.go(RouteNames.managerApprovals);
            break;
          case 4:
            showManagerMoreMenu(
              context,
              returnRoute: RouteNames.home,
              onSignOut: () => signOutAndReturnToLogin(context, ref),
            );
            break;
        }
      },
    );
  }
}
