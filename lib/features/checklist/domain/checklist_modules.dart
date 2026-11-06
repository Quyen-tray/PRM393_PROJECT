import 'package:flutter/material.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/common_fields.dart';
import 'package:hrm_coffee_shop_flutter/features/workspace/domain/workspace.dart';
import 'package:hrm_coffee_shop_flutter/features/checklist/domain/checklist_fields.dart';

final myChecklistsModule = ModuleSpec(
  'my-checklists',
  'Checklist',
  '/checklists/me',
  'taskId',
  'checklistName',
  access: employee,
  detail: '/checklists/tasks/{id}',
  icon: Icons.checklist,
  group: 'Công việc',
  workspaces: [Workspace.employee],
  filters: [
    'PENDING',
    'IN_PROGRESS',
    'SUBMITTED',
    'APPROVED',
    'REJECTED',
    'OVERDUE',
  ],
);

final checklistsModule = ModuleSpec(
  'checklists',
  'Checklist',
  '/checklists/instances',
  'taskId',
  'checklistName',
  access: (u) => u.has('CHECKLIST_VIEW'),
  detail: '/checklists/tasks/{id}',
  icon: Icons.checklist,
  group: 'Vận hành',
  filters: [
    'PENDING',
    'IN_PROGRESS',
    'SUBMITTED',
    'APPROVED',
    'REJECTED',
    'OVERDUE',
  ],
  createPath: '/checklists/instances/generate',
  createAccess: manager,
  fields: [
    FieldSpec(
      'templateId',
      'Mẫu checklist',
      kind: FieldKind.lookup,
      required: true,
      source: '/admin/checklist-templates',
      valueKey: 'templateId',
      labelKey: 'checklistName',
    ),
    FieldSpec(
      'employeeId',
      'Nhân viên (chỉ cần nếu không chọn ca)',
      kind: FieldKind.lookup,
      required: true,
      source: '/employees',
      valueKey: 'employeeId',
      labelKey: 'fullName',
    ),
    FieldSpec(
      'workDate',
      'Ngày thực hiện (chỉ cần nếu không chọn ca)',
      kind: FieldKind.date,
      required: true,
    ),
    FieldSpec(
      'scheduleId',
      'Ca được phân (tùy chọn; ngày và nhân viên lấy theo ca)',
      kind: FieldKind.lookup,
      source: '/shift-assignments',
      valueKey: 'assignmentId',
      labelKey: 'employeeName',
    ),
  ],
);

final checklistReviewsModule = ModuleSpec(
  'checklist-reviews',
  'Checklist chờ duyệt',
  '/checklists/reviews/pending',
  'taskId',
  'checklistName',
  access: (u) => u.has('CHECKLIST_REVIEW'),
  detail: '/checklists/tasks/{id}',
  icon: Icons.playlist_add_check,
  group: 'Duyệt',
);

final templatesModule = ModuleSpec(
  'templates',
  'Mẫu checklist',
  '/admin/checklist-templates',
  'templateId',
  'checklistName',
  access: (u) => u.admin || u.manager,
  icon: Icons.task_outlined,
  group: 'Danh mục',
  createPath: '/admin/checklist-templates',
  editPath: '/admin/checklist-templates/{id}',
  createAccess: admin,
  editAccess: admin,
  fields: [
    FieldSpec('checklistCode', 'Mã checklist', required: true),
    FieldSpec('checklistName', 'Tên checklist', required: true),
    FieldSpec(
      'checklistType',
      'Loại checklist',
      kind: FieldKind.choice,
      required: true,
      options: ['OPENING', 'CLOSING', 'HANDOVER', 'SERVICE', 'INVENTORY'],
    ),
    FieldSpec(
      'managerApprovalRequired',
      'Cần quản lý duyệt',
      kind: FieldKind.toggle,
      defaultValue: true,
    ),
    activeField,
    FieldSpec(
      'items',
      'Các công việc',
      kind: FieldKind.array,
      required: true,
      fields: checklistItemFields,
    ),
  ],
);
