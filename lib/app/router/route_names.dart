abstract final class RouteNames {
  static const home = '/';
  static const login = '/login';
  static const register = '/register';
  static const checkIn = '/attendance/check-in';
  static const profile = '/profile';
  static const managerEmployees = '/manager/employees';
  static const managerEmployeeDetail = '/manager/employees/:employeeCode';
  static const managerSchedule = '/manager/schedule';
  static const managerApprovals = '/manager/approvals';
  static const managerChecklistApprovals = '/manager/checklists/approvals';
  static const managerAttendanceReport = '/manager/reports/attendance';
  static const adminHome = '/admin';
  static const adminAccounts = '/admin/accounts';
  static const adminTraining = '/admin/training';
  static const adminSettings = '/admin/settings';
  static const adminPositions = '/admin/positions';
  static const adminChecklists = '/admin/checklists';

  static String managerEmployeeDetailFor(String employeeCode) =>
      '/manager/employees/$employeeCode';
}
