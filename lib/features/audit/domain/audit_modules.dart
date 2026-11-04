import 'package:flutter/material.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';

final auditModule = ModuleSpec(
  'audit',
  'Nhật ký kiểm toán',
  '/admin/audit-logs',
  'auditLogId',
  'actionCode',
  access: admin,
  detail: '/admin/audit-logs/{id}',
  icon: Icons.history,
  group: 'Giám sát',
);
