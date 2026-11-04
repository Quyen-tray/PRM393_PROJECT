import 'package:flutter/material.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/common_fields.dart';

final accountsModule = ModuleSpec(
  'accounts',
  'Tài khoản và quyền',
  '/admin/users',
  'userId',
  'displayName',
  access: admin,
  search: true,
  filters: ['ACTIVE', 'LOCKED', 'INACTIVE'],
  icon: Icons.manage_accounts,
  group: 'Quản trị',
  createPath: '/admin/users',
  createAccess: admin,
  fields: [
    FieldSpec('email', 'Email', required: true),
    FieldSpec('displayName', 'Tên hiển thị', required: true),
    FieldSpec('phoneNumber', 'Điện thoại'),
    roleField,
  ],
);
