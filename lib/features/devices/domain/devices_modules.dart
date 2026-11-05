import 'package:flutter/material.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';
import 'package:hrm_coffee_shop_flutter/features/workspace/domain/workspace.dart';

final myDevicesModule = ModuleSpec(
  'my-devices',
  'Thiết bị của tôi',
  '/attendance/devices/me',
  'deviceId',
  'deviceLabel',
  access: employee,
  detail: '/attendance/devices/{id}',
  icon: Icons.phonelink_lock,
  group: 'Cá nhân',
  kind: 'devices',
  workspaces: [Workspace.employee],
);

final devicesModule = ModuleSpec(
  'devices',
  'Quản lý thiết bị chấm công',
  '/attendance/devices',
  'deviceId',
  'employeeName',
  access: (u) => u.has('DEVICE_APPROVE'),
  detail: '/attendance/devices/{id}',
  icon: Icons.devices,
  group: 'Duyệt',
  search: true,
  filters: ['PENDING', 'ACTIVE', 'LOCKED', 'REJECTED', 'REVOKED'],
);
