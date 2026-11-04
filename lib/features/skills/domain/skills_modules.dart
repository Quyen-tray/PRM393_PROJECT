import 'package:flutter/material.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';

final skillsModule = ModuleSpec(
  'skills',
  'Kỹ năng',
  '/skills',
  'skillId',
  'skillName',
  access: (u) => u.admin || u.has('TRAINING_MANAGE'),
  icon: Icons.psychology_outlined,
  group: 'Danh mục',
  createPath: '/admin/skills',
  createAccess: admin,
  fields: [
    FieldSpec('skillCode', 'Mã kỹ năng', required: true),
    FieldSpec('skillName', 'Tên kỹ năng', required: true),
    FieldSpec('description', 'Mô tả', kind: FieldKind.multiline),
  ],
);
