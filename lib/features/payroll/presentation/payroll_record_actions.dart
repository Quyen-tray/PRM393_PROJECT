import 'package:flutter/material.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/presentation/record_action_context.dart';
import 'package:hrm_coffee_shop_flutter/features/payroll/presentation/payroll_detail.dart';

List<Widget> buildPayrollRecordActions(RecordActionContext record) {
  final row = record.row;
  final key = record.key;
  final actions = <Widget>[];
  if (key == 'payroll') actions.add(PayrollDetail(row));
  return actions;
}
