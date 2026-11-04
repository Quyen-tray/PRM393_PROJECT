import 'package:flutter/material.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/common_fields.dart';

final payrollModule = ModuleSpec(
  'payroll',
  'Kỳ công và đối soát',
  '/payroll-periods',
  'periodId',
  'periodCode',
  access: (u) => u.has('PAYROLL_VIEW'),
  icon: Icons.account_balance_wallet_outlined,
  group: 'Đối soát',
  kind: 'payroll',
  createPath: '/payroll-periods',
  createAccess: (u) => u.has('PAYROLL_VIEW') && u.has('PAYROLL_PERIOD_MANAGE'),
  fields: [
    FieldSpec('periodCode', 'Mã kỳ công', required: true),
    FieldSpec('startDate', 'Từ ngày', kind: FieldKind.date, required: true),
    FieldSpec('endDate', 'Đến ngày', kind: FieldKind.date, required: true),
    noteField,
  ],
);
