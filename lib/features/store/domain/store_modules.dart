import 'package:flutter/material.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';

final storeSettingsModule = ModuleSpec(
  'store-settings',
  'Cửa hàng và chính sách',
  '/admin/store-settings',
  '',
  'name',
  access: admin,
  icon: Icons.storefront,
  group: 'Cấu hình',
  kind: 'settings',
);
