import 'package:flutter/material.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/common_fields.dart';
import 'package:hrm_coffee_shop_flutter/features/workspace/domain/workspace.dart';

final myScheduleModule = ModuleSpec(
  'my-schedule',
  'Lịch làm của tôi',
  '/shift-assignments/me',
  'assignmentId',
  'workDate',
  access: employee,
  icon: Icons.calendar_month_outlined,
  detail: '/shift-assignments/{id}',
  kind: 'schedule',
  group: 'Cá nhân',
  workspaces: [Workspace.employee],
);

final assignmentsModule = ModuleSpec(
  'assignments',
  'Lịch phân ca',
  '/shift-assignments',
  'assignmentId',
  'employeeName',
  access: manager,
  icon: Icons.calendar_month,
  kind: 'schedule',
  detail: '/shift-assignments/{id}',
  createAccess: manager,
  editAccess: manager,
  createPath: '/shift-assignments',
  editPath: '/shift-assignments/{id}',
  editMethod: 'PATCH',
  fields: [
    employeeField,
    FieldSpec(
      'workShiftId',
      'Ca làm',
      kind: FieldKind.lookup,
      required: true,
      source: '/work-shifts',
      valueKey: 'shiftId',
      labelKey: 'shiftName',
    ),
    FieldSpec('workDate', 'Ngày làm', kind: FieldKind.date, required: true),
    noteField,
  ],
  editFields: [
    FieldSpec(
      'workShiftId',
      'Ca làm',
      kind: FieldKind.lookup,
      required: true,
      source: '/work-shifts',
      valueKey: 'shiftId',
      labelKey: 'shiftName',
    ),
    FieldSpec('workDate', 'Ngày làm', kind: FieldKind.date, required: true),
    noteField,
  ],
);

final shiftsModule = ModuleSpec(
  'shifts',
  'Danh mục ca',
  '/work-shifts',
  'shiftId',
  'shiftName',
  access: (u) => u.manager || u.admin,
  icon: Icons.schedule,
  createAccess: (u) => u.manager || u.admin,
  editAccess: (u) => u.manager || u.admin,
  createPath: '/work-shifts',
  editPath: '/work-shifts/{id}',
  fields: [
    FieldSpec('shiftCode', 'Mã ca', required: true),
    FieldSpec('shiftName', 'Tên ca', required: true),
    FieldSpec('startTime', 'Giờ bắt đầu', kind: FieldKind.time, required: true),
    FieldSpec('endTime', 'Giờ kết thúc', kind: FieldKind.time, required: true),
    FieldSpec(
      'breakMinutes',
      'Nghỉ giữa ca (phút)',
      kind: FieldKind.integer,
      min: 0,
      max: 240,
      defaultValue: 0,
    ),
    FieldSpec(
      'earlyCheckInMinutes',
      'Vào sớm (phút)',
      kind: FieldKind.integer,
      min: 15,
      max: 30,
      defaultValue: 15,
    ),
    FieldSpec(
      'graceMinutes',
      'Ân hạn (phút)',
      kind: FieldKind.integer,
      min: 3,
      max: 5,
      defaultValue: 5,
    ),
    activeField,
  ],
);
