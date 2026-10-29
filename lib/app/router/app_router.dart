import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/approvals/presentation/manager_approval_page.dart';
import '../../features/approvals/presentation/manager_checklist_approval_page.dart';
import '../../features/attendance/presentation/employee_check_in_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/employees/presentation/manager_employee_list_page.dart';
import '../../features/employees/presentation/manager_employee_detail_page.dart';
import '../../features/home/presentation/employee_dashboard_page.dart';
import '../../features/home/presentation/manager_dashboard_page.dart';
import '../../features/reports/presentation/manager_attendance_report_page.dart';
import '../../features/schedule/presentation/employee_schedule_page.dart';
import '../../features/schedule/presentation/manager_shift_schedule_page.dart';
import 'route_names.dart';

final appRouter = GoRouter(
  initialLocation: RouteNames.login,
  routes: [
    GoRoute(
      path: RouteNames.home,
      builder: (context, state) => const ManagerDashboardPage(),
    ),
    GoRoute(
      path: RouteNames.employeeHome,
      builder: (context, state) => const EmployeeDashboardPage(),
    ),
    GoRoute(
      path: RouteNames.employeeSchedule,
      builder: (context, state) => const EmployeeSchedulePage(),
    ),
    GoRoute(
      path: RouteNames.managerEmployees,
      builder: (context, state) => const ManagerEmployeeListPage(),
    ),
    GoRoute(
      path: RouteNames.managerEmployeeDetail,
      builder: (context, state) => ManagerEmployeeDetailPage(
        employeeCode: state.pathParameters['employeeCode'] ?? '',
      ),
    ),
    GoRoute(
      path: RouteNames.managerSchedule,
      builder: (context, state) => const ManagerShiftSchedulePage(),
    ),
    GoRoute(
      path: RouteNames.managerApprovals,
      builder: (context, state) => const ManagerApprovalPage(),
    ),
    GoRoute(
      path: RouteNames.managerChecklistApprovals,
      builder: (context, state) => const ManagerChecklistApprovalPage(),
    ),
    GoRoute(
      path: RouteNames.managerAttendanceReport,
      builder: (context, state) => const ManagerAttendanceReportPage(),
    ),
    GoRoute(
      path: RouteNames.login,
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: RouteNames.register,
      builder: (context, state) => const RegisterPage(),
    ),
    GoRoute(
      path: RouteNames.checkIn,
      builder: (context, state) => const EmployeeCheckInPage(),
    ),
    GoRoute(
      path: RouteNames.profile,
      builder: (context, state) => const ProfilePage(),
    ),
  ],
);

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cá nhân')),
      body: const Center(child: Text('Profile - Đang phát triển')),
    );
  }
}
