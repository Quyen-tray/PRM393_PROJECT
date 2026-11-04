import 'package:flutter/material.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';
import 'package:hrm_coffee_shop_flutter/features/workspace/domain/workspace.dart';

final myViolationsModule = ModuleSpec(
  'my-violations',
  'Vi phạm của tôi',
  '/employees/me/violations',
  'violationId',
  'ruleName',
  access: employee,
  detail: '/violations/{id}',
  icon: Icons.rule,
  group: 'Cá nhân',
  workspaces: [Workspace.employee],
);

final violationsModule = ModuleSpec(
  'violations',
  'Vi phạm cần xem xét',
  '/violations',
  'violationId',
  'ruleName',
  access: (u) => u.has('VIOLATION_REVIEW'),
  detail: '/violations/{id}',
  icon: Icons.rule,
  group: 'Duyệt',
  filters: ['OPEN', 'CONFIRMED', 'DISMISSED', 'RESOLVED'],
);
