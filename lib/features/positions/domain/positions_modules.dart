import 'package:flutter/material.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/common_fields.dart';

final positionsModule = ModuleSpec(
  'positions',
  'Chức vụ và điều kiện',
  '/admin/job-positions',
  'positionId',
  'positionName',
  access: admin,
  icon: Icons.badge_outlined,
  group: 'Danh mục',
  createPath: '/admin/job-positions',
  editPath: '/admin/job-positions/{id}',
  createAccess: admin,
  editAccess: admin,
  fields: [
    FieldSpec('positionCode', 'Mã chức vụ', required: true),
    FieldSpec('positionName', 'Tên chức vụ', required: true),
    FieldSpec('description', 'Mô tả', kind: FieldKind.multiline),
    activeField,
  ],
);
