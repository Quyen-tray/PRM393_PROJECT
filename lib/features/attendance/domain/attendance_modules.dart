import 'package:flutter/material.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';
import 'package:hrm_coffee_shop_flutter/features/workspace/domain/workspace.dart';

final myAttendanceModule = ModuleSpec(
  'my-attendance',
  'Lịch sử công',
  '/attendance/me',
  'attendanceId',
  'workDate',
  access: employee,
  detail: '/attendance/{id}',
  icon: Icons.fact_check_outlined,
  group: 'Cá nhân',
  workspaces: [Workspace.employee],
);

final attendanceModule = ModuleSpec(
  'attendance',
  'Chấm công toàn cửa hàng',
  '/attendance',
  'attendanceId',
  'employeeName',
  access: (u) => u.has('ATTENDANCE_VIEW_ALL'),
  detail: '/attendance/{id}',
  icon: Icons.fact_check,
  group: 'Đối soát',
  filters: ['CHECKED_IN', 'CHECKED_OUT', 'LATE', 'EARLY_LEAVE', 'FINALIZED'],
);
