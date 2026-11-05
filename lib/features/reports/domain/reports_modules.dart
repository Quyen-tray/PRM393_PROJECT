import 'package:flutter/material.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';

final reportsAttendanceModule = ModuleSpec(
  'reports-attendance',
  'Báo cáo chấm công',
  '/reports/attendance',
  'employeeId',
  'employeeName',
  access: (u) => u.has('DASHBOARD_MANAGER'),
  icon: Icons.bar_chart,
  group: 'Báo cáo',
  kind: 'report',
);

final reportsOperationsModule = ModuleSpec(
  'reports-operations',
  'Báo cáo vận hành',
  '/reports/operations',
  '',
  '',
  access: (u) => u.has('DASHBOARD_MANAGER'),
  icon: Icons.query_stats,
  group: 'Báo cáo',
  kind: 'report',
);
