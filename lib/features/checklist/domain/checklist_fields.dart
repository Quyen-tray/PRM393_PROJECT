import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';

const checklistItemFields = [
  FieldSpec('itemName', 'Tên công việc', required: true),
  FieldSpec('instructions', 'Hướng dẫn', kind: FieldKind.multiline),
  FieldSpec(
    'isRequired',
    'Bắt buộc',
    kind: FieldKind.toggle,
    defaultValue: true,
  ),
  FieldSpec('requiresEvidence', 'Cần ảnh minh chứng', kind: FieldKind.toggle),
  FieldSpec(
    'requiresManagerApproval',
    'Cần quản lý duyệt',
    kind: FieldKind.toggle,
  ),
  FieldSpec('sortOrder', 'Thứ tự', kind: FieldKind.integer, min: 1),
];
