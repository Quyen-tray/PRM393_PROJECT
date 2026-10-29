abstract final class RouteNames {
  static const home = '/';
  static const employeeHome = '/employee';
  static const employeeSchedule = '/employee/schedule';
  static const employeeChecklist = '/employee/checklist';
  static const employeeTraining = '/employee/training';
  static const employeeNotifications = '/employee/notifications';
  static const employeeProfile = '/employee/profile';
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

  static String managerEmployeeDetailFor(String employeeCode) =>
      '/manager/employees/$employeeCode';
}
