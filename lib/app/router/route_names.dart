abstract final class RouteNames {
  static const home = '/';
  static const employeeHome = '/employee';
  static const employeeSchedule = '/employee/schedule';
  static const employeeChecklist = '/employee/checklist';
  static const employeeTraining = '/employee/training';
  static const employeeNotifications = '/employee/notifications';
  static const employeeProfile = '/employee/profile';
  static const employeeRewards = '/employee/rewards';
  static const login = '/login';
  static const register = '/register';
  static const checkIn = '/attendance/check-in';
  static const employeeAttendanceHistory = '/employee/attendance-history';
  static const profile = '/profile';
  static const managerEmployees = '/manager/employees';
  static const managerEmployeeDetail = '/manager/employees/:employeeCode';
  static const managerEmployeeEdit = '/manager/employees/:employeeCode/edit';
  static const adminAccountEmployeeCreate = '/admin/accounts/:userId/employee/new';
  static const adminAccountPermissions = '/admin/accounts/:userId/permissions';
  static const managerSchedule = '/manager/schedule';
  static const managerApprovals = '/manager/approvals';
  static const managerDevices = '/manager/devices';
  static const managerAttendanceRequests = '/manager/attendance-requests';
  static const managerChecklistApprovals = '/manager/checklists/approvals';
  static const managerAttendanceReport = '/manager/reports/attendance';
  static const adminHome = '/admin';
  static const adminAccounts = '/admin/accounts';
  static const adminPositions = '/admin/positions';
  static const adminTraining = '/admin/training';
  static const adminChecklistTemplates = '/admin/checklist-templates';
  static const adminSettings = '/admin/settings';
  static const adminAuditLogs = '/admin/audit-logs';
  static const adminNotificationDeliveries = '/admin/notification-deliveries';
  static const adminSkills = '/admin/skills';
  static const managerViolations = '/manager/violations';
  static const managerRewards = '/manager/rewards';
  static const managerPayroll = '/manager/payroll';

  static String managerEmployeeDetailFor(String employeeCode) =>
      '/manager/employees/$employeeCode';

  static String managerEmployeeEditFor(String employeeCode) =>
      '/manager/employees/$employeeCode/edit';

  static String adminAccountEmployeeCreateFor(int userId) =>
      '/admin/accounts/$userId/employee/new';

  static String adminAccountPermissionsFor(int userId) =>
      '/admin/accounts/$userId/permissions';
}
