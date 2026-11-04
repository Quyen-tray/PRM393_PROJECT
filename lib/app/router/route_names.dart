abstract final class RouteNames {
  static const home = '/';
  static const hrHome = '/hr';
  static const hrAttendanceAdjustments = '/hr/attendance-adjustments';
  static const employeeHome = '/employee';
  static const employeeSchedule = '/employee/schedule';
  static const employeeChecklist = '/employee/checklist';
  static const employeeTraining = '/employee/training';
  static const employeeNotifications = '/employee/notifications';
  static const employeeProfile = '/employee/profile';
  static const employeeDocuments = '/employee/documents';
  static const employeeViolations = '/employee/violations';
  static const managerDocumentReview = '/manager/documents';
  static const employeeRewards = '/employee/rewards';
  static const login = '/login';
  static const register = '/register';
  static const roleSelection = '/select-workspace';
  static const checkIn = '/attendance/check-in';
  static const employeeAttendanceHistory = '/employee/attendance-history';
  static const profile = '/profile';
  static const managerEmployees = '/manager/employees';
  static const managerEmployeeDetail = '/manager/employees/:employeeCode';
  static const managerEmployeeEdit = '/manager/employees/:employeeCode/edit';
  static const adminAccountEmployeeCreate =
      '/admin/accounts/:userId/employee/new';
  static const adminAccountPermissions = '/admin/accounts/:userId/permissions';
  static const managerSchedule = '/manager/schedule';
  static const managerWorkShifts = '/manager/schedule/work-shifts';
  static const managerApprovals = '/manager/approvals';
  static const managerDevices = '/manager/devices';
  static const managerAttendanceRequests = '/manager/attendance-requests';
  static const managerChecklistApprovals = '/manager/checklists/approvals';
  static const managerTrainingCompletions = '/manager/training/completions';
  static const adminTrainingCompletions = '/admin/training/completions';
  static const managerAttendanceReport = '/manager/reports/attendance';
  static const adminHome = '/admin';
  static const adminAccounts = '/admin/accounts';
  static const adminPositions = '/admin/positions';
  static const adminTraining = '/admin/training';
  static const adminTrainingQuestions =
      '/admin/training/courses/:courseId/questions';
  static const adminChecklistTemplates = '/admin/checklist-templates';
  static const adminSettings = '/admin/settings';
  static const adminAuditLogs = '/admin/audit-logs';
  static const adminNotificationDeliveries = '/admin/notification-deliveries';
  static const adminSkills = '/admin/skills';
  static const adminDocumentTypes = '/admin/document-types';
  static const managerOperations = '/manager/reports/operations';
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

  static String adminTrainingQuestionsFor(int courseId) =>
      '/admin/training/courses/$courseId/questions';
}
