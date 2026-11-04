import 'package:flutter/material.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';

final reminderRulesModule = ModuleSpec(
  'reminder-rules',
  'Quy tắc nhắc việc',
  '/admin/reminder-rules',
  'ruleId',
  'description',
  access: admin,
  icon: Icons.alarm,
  group: 'Cấu hình',
  editPath: '/admin/reminder-rules/{id}',
  editAccess: admin,
  fields: [
    FieldSpec('isActive', 'Bật quy tắc nhắc việc',
        kind: FieldKind.toggle, defaultValue: true),
    FieldSpec(
      'leadMinutes',
      'Nhắc trước (phút)',
      kind: FieldKind.integer,
      min: 0,
    ),
    FieldSpec(
      'intervalMinutes',
      'Chu kỳ nhắc (phút)',
      kind: FieldKind.integer,
      min: 0,
    ),
    FieldSpec('maxAttempts', 'Số lần nhắc', kind: FieldKind.integer, min: 0),
  ],
);

final deliveriesModule = ModuleSpec(
  'deliveries',
  'Phân phối thông báo',
  '/admin/notification-deliveries',
  'notificationId',
  'title',
  access: admin,
  icon: Icons.mark_email_read_outlined,
  group: 'Giám sát',
  filters: ['PENDING', 'SENT', 'FAILED'],
);

final notificationsModule = ModuleSpec(
  'notifications',
  'Thông báo',
  '/notifications/me',
  'notificationId',
  'title',
  access: (_) => true,
  icon: Icons.notifications_outlined,
  group: 'Chung',
  kind: 'notifications',
);
