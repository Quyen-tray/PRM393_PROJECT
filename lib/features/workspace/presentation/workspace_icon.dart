import 'package:flutter/material.dart';
import 'package:hrm_coffee_shop_flutter/features/workspace/domain/workspace.dart';

IconData workspaceIcon(Workspace w) => switch (w) {
      Workspace.employee => Icons.badge_outlined,
      Workspace.manager => Icons.storefront,
      Workspace.admin => Icons.admin_panel_settings_outlined,
    };
