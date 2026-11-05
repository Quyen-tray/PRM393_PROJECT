import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/common_fields.dart';

const employeeEditFields = [
  FieldSpec('fullName', 'Họ và tên'),
  FieldSpec('phone', 'Điện thoại'),
  positionField,
  employmentField,
  FieldSpec('dateOfBirth', 'Ngày sinh', kind: FieldKind.date),
  FieldSpec('identityNumber', 'Số định danh'),
  FieldSpec('address', 'Địa chỉ'),
  FieldSpec('emergencyContact', 'Liên hệ khẩn cấp'),
];
