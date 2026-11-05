import 'package:flutter/material.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';
import 'package:hrm_coffee_shop_flutter/features/workspace/domain/workspace.dart';

final myExplanationsModule = ModuleSpec(
  'my-explanations',
  'Giải trình của tôi',
  '/attendance/explanation-requests/me',
  'requestId',
  'requestType',
  access: employee,
  detail: '/attendance/explanation-requests/{id}',
  icon: Icons.edit_note,
  group: 'Yêu cầu cá nhân',
  workspaces: [Workspace.employee],
);

final myOvertimeModule = ModuleSpec(
  'my-overtime',
  'Tăng ca của tôi',
  '/attendance/overtime-requests/me',
  'requestId',
  'requestedStartAt',
  access: employee,
  detail: '/attendance/overtime-requests/{id}',
  icon: Icons.more_time,
  group: 'Yêu cầu cá nhân',
  workspaces: [Workspace.employee],
);

final myAdjustmentsModule = ModuleSpec(
  'my-adjustments',
  'Điều chỉnh công của tôi',
  '/attendance/adjustment-requests/me',
  'requestId',
  'fieldName',
  access: employee,
  detail: '/attendance/adjustment-requests/{id}',
  icon: Icons.edit_calendar_outlined,
  group: 'Yêu cầu cá nhân',
  workspaces: [Workspace.employee],
);

final explanationsModule = ModuleSpec(
  'explanations',
  'Duyệt giải trình',
  '/attendance/explanation-requests',
  'requestId',
  'requestType',
  access: manager,
  detail: '/attendance/explanation-requests/{id}',
  icon: Icons.edit_note,
  group: 'Duyệt',
  filters: ['PENDING', 'APPROVED', 'REJECTED'],
);

final overtimeModule = ModuleSpec(
  'overtime',
  'Duyệt tăng ca',
  '/attendance/overtime-requests',
  'requestId',
  'requestedStartAt',
  access: manager,
  detail: '/attendance/overtime-requests/{id}',
  icon: Icons.more_time,
  group: 'Duyệt',
  filters: ['PENDING', 'APPROVED', 'REJECTED'],
);

final adjustmentsModule = ModuleSpec(
  'adjustments',
  'Điều chỉnh công · hai bước',
  '/attendance/adjustment-requests',
  'requestId',
  'fieldName',
  access: canAdjust,
  detail: '/attendance/adjustment-requests/{id}',
  icon: Icons.edit_calendar,
  group: 'Duyệt',
  filters: ['PENDING_MANAGER', 'PENDING_HR', 'APPROVED', 'REJECTED'],
);
