import 'package:go_router/go_router.dart';

import '../../features/approvals/presentation/manager_approval_page.dart';
import '../../features/approvals/presentation/manager_checklist_approval_page.dart';
import '../../features/approvals/presentation/manager_device_approval_page.dart';
import '../../features/approvals/presentation/manager_attendance_requests_page.dart';
import '../../features/attendance/presentation/employee_check_in_page.dart';
import '../../features/attendance/presentation/employee_attendance_history_page.dart';
import '../../features/admin/presentation/admin_dashboard_page.dart';
import '../../features/admin/presentation/admin_account_management_page.dart';
import '../../features/admin/presentation/admin_position_management_page.dart';
import '../../features/admin/presentation/admin_training_management_page.dart';
import '../../features/admin/presentation/admin_training_questions_page.dart';
import '../../features/admin/presentation/admin_checklist_management_page.dart';
import '../../features/admin/presentation/admin_system_settings_page.dart';
import '../../features/checklist/presentation/employee_checklist_page.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/auth/presentation/role_selection_page.dart';
import '../../features/auth/domain/entities/user.dart';
import '../../features/employees/presentation/manager_employee_list_page.dart';
import '../../features/employees/presentation/manager_employee_detail_page.dart';
import '../../features/employees/presentation/employee_profile_form_page.dart';
import '../../features/admin/presentation/admin_account_permissions_page.dart';
import '../../features/admin/presentation/admin_audit_log_page.dart';
import '../../features/admin/presentation/admin_notification_delivery_page.dart';
import '../../features/admin/presentation/admin_skill_management_page.dart';
import '../../features/admin/presentation/admin_document_types_page.dart';
import '../../features/violations/presentation/manager_violation_review_page.dart';
import '../../features/violations/presentation/employee_violations_page.dart';
import '../../features/rewards/presentation/manager_reward_penalty_page.dart';
import '../../features/payroll/presentation/manager_payroll_page.dart';
import '../../features/rewards/presentation/employee_rewards_page.dart';
import '../../features/home/presentation/employee_dashboard_page.dart';
import '../../features/home/presentation/manager_dashboard_page.dart';
import '../../features/home/presentation/hr_workspace_page.dart';
import '../../features/approvals/presentation/hr_attendance_adjustments_page.dart';
import '../../features/notifications/presentation/employee_notifications_page.dart';
import '../../features/profile/presentation/account_profile_page.dart';
import '../../features/documents/presentation/manager_document_review_page.dart';
import '../../features/reports/presentation/manager_attendance_report_page.dart';
import '../../features/reports/presentation/manager_operations_reports_page.dart';
import '../../features/schedule/presentation/employee_schedule_page.dart';
import '../../features/training/presentation/employee_training_page.dart';
import '../../features/training/presentation/manager_training_completion_review_page.dart';
import '../../features/schedule/presentation/manager_shift_schedule_page.dart';
import '../../features/schedule/presentation/manager_work_shift_catalog_page.dart';
import 'route_names.dart';

final appRouter = GoRouter(
  initialLocation: RouteNames.login,
  routes: [
    GoRoute(
      path: RouteNames.home,
      builder: (context, state) => const ManagerDashboardPage(),
    ),
    GoRoute(
      path: RouteNames.hrHome,
      builder: (context, state) => const HrWorkspacePage(),
    ),
    GoRoute(
      path: RouteNames.hrAttendanceAdjustments,
      builder: (context, state) => const HrAttendanceAdjustmentsPage(),
    ),
    GoRoute(
      path: RouteNames.adminHome,
      builder: (context, state) => const AdminDashboardPage(),
    ),
    GoRoute(
      path: RouteNames.adminAccounts,
      builder: (context, state) => const AdminAccountManagementPage(),
    ),
    GoRoute(
      path: RouteNames.adminPositions,
      builder: (context, state) => const AdminPositionManagementPage(),
    ),
    GoRoute(
      path: RouteNames.adminDocumentTypes,
      builder: (context, state) => const AdminDocumentTypesPage(),
    ),
    GoRoute(
      path: RouteNames.adminTraining,
      builder: (context, state) => const AdminTrainingManagementPage(),
    ),
    GoRoute(
      path: RouteNames.adminTrainingCompletions,
      builder: (context, state) => const ManagerTrainingCompletionReviewPage(
        isAdmin: true,
        returnRoute: RouteNames.adminTraining,
      ),
    ),
    GoRoute(
      path: RouteNames.adminTrainingQuestions,
      builder: (context, state) => AdminTrainingQuestionsPage(
        courseId: int.tryParse(state.pathParameters['courseId'] ?? '') ?? -1,
        courseName: state.extra is String ? state.extra! as String : 'Khóa học',
      ),
    ),
    GoRoute(
      path: RouteNames.adminChecklistTemplates,
      builder: (context, state) => const AdminChecklistManagementPage(),
    ),
    GoRoute(
      path: RouteNames.adminSettings,
      builder: (context, state) => const AdminSystemSettingsPage(),
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
      path: RouteNames.employeeChecklist,
      builder: (context, state) => const EmployeeChecklistPage(),
    ),
    GoRoute(
      path: RouteNames.employeeTraining,
      builder: (context, state) => const EmployeeTrainingPage(),
    ),
    GoRoute(
      path: RouteNames.employeeProfile,
      builder: (context, state) =>
          const AccountProfilePage(returnRoute: RouteNames.employeeHome),
    ),
    GoRoute(
      path: RouteNames.employeeDocuments,
      builder: (context, state) => const AccountProfilePage(
        initialTab: 2,
        returnRoute: RouteNames.employeeHome,
      ),
    ),
    GoRoute(
      path: RouteNames.employeeViolations,
      builder: (context, state) => const EmployeeViolationsPage(),
    ),
    GoRoute(
      path: RouteNames.managerDocumentReview,
      builder: (context, state) => ManagerDocumentReviewPage(
        returnRoute: state.extra is String
            ? state.extra! as String
            : RouteNames.home,
      ),
    ),
    GoRoute(
      path: RouteNames.employeeNotifications,
      builder: (context, state) => const EmployeeNotificationsPage(),
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
      path: RouteNames.managerEmployeeEdit,
      builder: (context, state) => EmployeeProfileFormPage.edit(
        employeeId: int.tryParse(state.pathParameters['employeeCode'] ?? ''),
      ),
    ),
    GoRoute(
      path: RouteNames.adminAccountEmployeeCreate,
      builder: (context, state) {
        final extra = state.extra is Map
            ? Map<String, dynamic>.from(state.extra as Map)
            : <String, dynamic>{};
        return EmployeeProfileFormPage.create(
          userId: int.tryParse(state.pathParameters['userId'] ?? ''),
          displayName: extra['displayName']?.toString(),
          email: extra['email']?.toString(),
        );
      },
    ),
    GoRoute(
      path: RouteNames.adminAuditLogs,
      builder: (context, state) => const AdminAuditLogPage(),
    ),
    GoRoute(
      path: RouteNames.adminNotificationDeliveries,
      builder: (context, state) => const AdminNotificationDeliveryPage(),
    ),
    GoRoute(
      path: RouteNames.adminSkills,
      builder: (context, state) => const AdminSkillManagementPage(),
    ),
    GoRoute(
      path: RouteNames.managerViolations,
      builder: (context, state) => const ManagerViolationReviewPage(),
    ),
    GoRoute(
      path: RouteNames.managerRewards,
      builder: (context, state) => const ManagerRewardPenaltyPage(),
    ),
    GoRoute(
      path: RouteNames.managerPayroll,
      builder: (context, state) => const ManagerPayrollPage(),
    ),
    GoRoute(
      path: RouteNames.employeeRewards,
      builder: (context, state) => const EmployeeRewardsPage(),
    ),
    GoRoute(
      path: RouteNames.adminAccountPermissions,
      builder: (context, state) {
        final extra = state.extra is Map
            ? Map<String, dynamic>.from(state.extra as Map)
            : <String, dynamic>{};
        return AdminAccountPermissionsPage(
          userId: int.tryParse(state.pathParameters['userId'] ?? ''),
          displayName: extra['displayName']?.toString(),
          email: extra['email']?.toString(),
        );
      },
    ),
    GoRoute(
      path: RouteNames.managerSchedule,
      builder: (context, state) => const ManagerShiftSchedulePage(),
    ),
    GoRoute(
      path: RouteNames.managerWorkShifts,
      builder: (context, state) => const ManagerWorkShiftCatalogPage(),
    ),
    GoRoute(
      path: RouteNames.managerApprovals,
      builder: (context, state) => const ManagerApprovalPage(),
    ),
    GoRoute(
      path: RouteNames.managerDevices,
      builder: (context, state) => const ManagerDeviceApprovalPage(),
    ),
    GoRoute(
      path: RouteNames.managerAttendanceRequests,
      builder: (context, state) => const ManagerAttendanceRequestsPage(),
    ),
    GoRoute(
      path: RouteNames.managerChecklistApprovals,
      builder: (context, state) => const ManagerChecklistApprovalPage(),
    ),
    GoRoute(
      path: RouteNames.managerTrainingCompletions,
      builder: (context, state) => ManagerTrainingCompletionReviewPage(
        returnRoute: state.extra is String
            ? state.extra! as String
            : RouteNames.home,
      ),
    ),
    GoRoute(
      path: RouteNames.managerAttendanceReport,
      builder: (context, state) => const ManagerAttendanceReportPage(),
    ),
    GoRoute(
      path: RouteNames.managerOperations,
      builder: (context, state) => const ManagerOperationsReportsPage(),
    ),
    GoRoute(
      path: RouteNames.login,
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: RouteNames.roleSelection,
      builder: (context, state) => state.extra is User
          ? RoleSelectionPage(user: state.extra! as User)
          : const LoginPage(),
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
      path: RouteNames.employeeAttendanceHistory,
      builder: (context, state) => const EmployeeAttendanceHistoryPage(),
    ),
    GoRoute(
      path: RouteNames.profile,
      builder: (context, state) => AccountProfilePage(
        returnRoute: state.extra is String ? state.extra! as String : null,
      ),
    ),
  ],
);
