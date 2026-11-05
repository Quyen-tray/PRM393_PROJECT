import 'package:flutter/material.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/presentation/record_action_context.dart';
import 'package:hrm_coffee_shop_flutter/features/positions/presentation/position_requirements.dart';

List<Widget> buildPositionRecordActions(RecordActionContext record) {
  final user = record.user;
  final key = record.key;
  final id = record.id;
  final actions = <Widget>[];
  if (key == 'positions' && user.admin) actions.add(PositionRequirements(id));
  return actions;
}
