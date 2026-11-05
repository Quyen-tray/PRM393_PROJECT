import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';

const noteField = FieldSpec('note', 'Ghi chú', kind: FieldKind.multiline);
const employeeField = FieldSpec(
  'employeeId',
  'Nhân viên',
  kind: FieldKind.lookup,
  required: true,
  source: '/employees',
  valueKey: 'employeeId',
  labelKey: 'fullName',
);
const positionField = FieldSpec(
  'positionId',
  'Chức vụ',
  kind: FieldKind.lookup,
  required: true,
  source: '/job-positions',
  valueKey: 'positionId',
  labelKey: 'positionName',
);
const courseField = FieldSpec(
  'courseId',
  'Khóa học',
  kind: FieldKind.lookup,
  required: true,
  source: '/training/courses',
  valueKey: 'courseId',
  labelKey: 'courseName',
);
const documentTypeField = FieldSpec(
  'documentTypeId',
  'Loại giấy tờ',
  kind: FieldKind.lookup,
  required: true,
  source: '/admin/document-types',
  valueKey: 'documentTypeId',
  labelKey: 'documentName',
);
const activeField = FieldSpec(
  'isActive',
  'Đang hoạt động',
  kind: FieldKind.toggle,
  defaultValue: true,
);
const requiredField = FieldSpec(
  'isMandatory',
  'Bắt buộc',
  kind: FieldKind.toggle,
  defaultValue: true,
);
const employmentField = FieldSpec(
  'employmentType',
  'Loại hợp đồng',
  kind: FieldKind.choice,
  options: ['FULL_TIME', 'PART_TIME', 'TEMPORARY', 'PROBATION'],
  defaultValue: 'FULL_TIME',
);
const roleField = FieldSpec(
  'roles',
  'Vai trò',
  kind: FieldKind.multiple,
  required: true,
  options: ['EMPLOYEE', 'STORE_MANAGER', 'SYSTEM_ADMIN'],
);
