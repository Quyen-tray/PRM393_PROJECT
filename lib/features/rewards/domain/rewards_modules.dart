import 'package:flutter/material.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/common_fields.dart';
import 'package:hrm_coffee_shop_flutter/features/workspace/domain/workspace.dart';

final myRewardsModule = ModuleSpec(
  'my-rewards',
  'Thưởng và phạt của tôi',
  '/rewards-penalties/me',
  'decisionId',
  'reasonName',
  access: employee,
  detail: '/rewards-penalties/{id}',
  icon: Icons.workspace_premium_outlined,
  group: 'Cá nhân',
  workspaces: [Workspace.employee],
);

final decisionsModule = ModuleSpec(
  'decisions',
  'Thưởng / phạt',
  '/rewards-penalties',
  'decisionId',
  'reasonName',
  access: (u) => u.has('REWARD_VIEW'),
  detail: '/rewards-penalties/{id}',
  icon: Icons.workspace_premium,
  group: 'Nhân sự',
  filters: ['PENDING_APPROVAL', 'APPROVED', 'REJECTED', 'CANCELLED'],
  createAccess: (u) => u.has('REWARD_PROPOSE'),
  createPath: '/rewards-penalties',
  fields: [
    FieldSpec(
      'decisionType',
      'Loại quyết định',
      kind: FieldKind.choice,
      required: true,
      options: ['REWARD', 'PENALTY'],
    ),
    employeeField,
    FieldSpec(
      'reasonCode',
      'Quy định',
      kind: FieldKind.lookup,
      required: true,
      source: '/rule-catalog',
      valueKey: 'ruleCode',
      labelKey: 'ruleName',
    ),
    FieldSpec(
      'description',
      'Nội dung đề xuất',
      kind: FieldKind.multiline,
      required: true,
    ),
    FieldSpec('amount', 'Số tiền', kind: FieldKind.decimal, min: 0),
    FieldSpec('effectiveDate', 'Ngày áp dụng', kind: FieldKind.date),
  ],
);
