import 'package:flutter/material.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/presentation/record_action_context.dart';
import 'package:hrm_coffee_shop_flutter/app/router/module_registry.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/presentation/linked_resource_list.dart';

List<Widget> buildDeviceRecordActions(RecordActionContext record) {
  final row = record.row;
  final user = record.user;
  final key = record.key;
  final id = record.id;
  final own = record.own;
  final status = record.status;
  final approve = record.approve;
  final reject = record.reject;
  final actions = <Widget>[];
  if (['my-devices', 'devices'].contains(key)) {
    if (user.has('DEVICE_APPROVE')) {
      if (status == 'PENDING' && !own) {
        actions.add(
          approve('Duyệt thiết bị', '/attendance/devices/$id/approve'),
        );
        actions.add(
          reject('Từ chối thiết bị', '/attendance/devices/$id/reject'),
        );
      }
      if (status == 'ACTIVE') {
        actions.add(
          reject('Thu hồi thiết bị', '/attendance/devices/$id/revoke'),
        );
      }
    }
    if (user.has('DEVICE_APPROVE')) {
      actions.add(
        LinkedResourceList(
          '/attendance/devices/employees/${row['employeeId']}',
          module('devices'),
          title: 'Tất cả thiết bị của nhân viên',
        ),
      );
    }
  }
  return actions;
}
