import 'package:hrm_coffee_shop_flutter/features/auth/domain/current_user.dart';
import 'package:hrm_coffee_shop_flutter/app/router/module_registry.dart';

String? notificationRoute(Map<String, dynamic> notification,
    [CurrentUser? user]) {
  final type = notification['entityType'] ?? notification['relatedEntityType'];
  final id = notification['entityId'] ?? notification['relatedEntityId'];
  if (notification['type'] == 'ATTENDANCE_SPOT_CHECK') {
    if (type == 'ShiftAssignment' && id != null) {
      return '/attendance/check-in?assignmentId=$id';
    }
    // Older spot-check notifications point to AttendanceId, but the active
    // shift is still selected by the current-attendance endpoint.
    return '/attendance/check-in';
  }
  if (id == null) return null;
  final key = switch (type) {
    'Attendance' =>
      user?.has('ATTENDANCE_VIEW_ALL') == true ? 'attendance' : 'my-attendance',
    'AttendanceDevice' =>
      user?.has('DEVICE_APPROVE') == true ? 'devices' : 'my-devices',
    'ShiftAssignment' ||
    'WorkSchedule' =>
      user?.manager == true ? 'assignments' : 'my-schedule',
    'ChecklistTask' =>
      user?.has('CHECKLIST_VIEW') == true ? 'checklists' : 'my-checklists',
    'EmployeeDocument' => 'my-document-records',
    'AttendanceExceptionRequest' =>
      user?.manager == true ? 'explanations' : 'my-explanations',
    'OvertimeRequest' => user?.manager == true ? 'overtime' : 'my-overtime',
    'AttendanceAdjustmentRequest' =>
      user != null && canAdjust(user) ? 'adjustments' : 'my-adjustments',
    'EmployeeRewardPenalty' =>
      user?.has('REWARD_VIEW') == true ? 'decisions' : 'my-rewards',
    'ViolationEvent' =>
      user?.has('VIOLATION_REVIEW') == true ? 'violations' : 'my-violations',
    'PayrollPeriod' => 'payroll',
    'EmployeeTraining' => 'enrollments',
    _ => null,
  };
  return key == null ? null : module(key).recordRoute(id);
}
