import 'package:flutter/material.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/common_fields.dart';
import 'package:hrm_coffee_shop_flutter/features/employees/domain/employee_fields.dart';

final employeesModule = ModuleSpec(
  'employees',
  'Nhân viên',
  '/employees',
  'employeeId',
  'fullName',
  access: (u) => u.has('EMPLOYEE_VIEW'),
  detail: '/employees/{id}',
  icon: Icons.groups_outlined,
  search: true,
  createAccess: (u) => u.has('EMPLOYEE_MANAGE'),
  editAccess: (u) => u.has('EMPLOYEE_MANAGE'),
  createPath: '/employees',
  editPath: '/employees/{id}',
  editMethod: 'PATCH',
  fields: [
    FieldSpec(
      'userId',
      'Tài khoản',
      kind: FieldKind.lookup,
      required: true,
      source: '/employees/linkable-users',
      valueKey: 'userId',
      labelKey: 'email',
    ),
    FieldSpec('employeeCode', 'Mã nhân viên', required: true),
    positionField,
    employmentField,
    FieldSpec('hireDate', 'Ngày vào làm', kind: FieldKind.date, required: true),
  ],
  editFields: employeeEditFields,
  group: 'Nhân sự',
);
