import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/data/session_controller.dart';
import 'package:hrm_coffee_shop_flutter/app/router/module_registry.dart';

void main() {
  test(
    'A manager role alone does not grant administrative or HR permissions',
    () {
      const manager = CurrentUser(
        id: 2,
        name: 'Manager',
        email: 'm@test',
        roles: {'STORE_MANAGER'},
        permissions: {},
      );
      expect(module('accounts').access(manager), false);
      expect(module('documents').access(manager), false);
      expect(module('devices').access(manager), false);
      expect(module('assignments').access(manager), true);
    },
  );

  test(
    'Permission-only users see their task without acquiring a manager workspace',
    () {
      const reviewer = CurrentUser(
        id: 3,
        name: 'Reviewer',
        email: 'r@test',
        roles: {'EMPLOYEE'},
        permissions: {'DEVICE_APPROVE', 'ATTENDANCE_ADJUST_HR'},
        employeeId: 13,
      );
      expect(module('devices').access(reviewer), true);
      expect(module('adjustments').access(reviewer), true);
      expect(module('assignments').access(reviewer), false);
      expect(reviewer.workspaces, [Workspace.employee]);
    },
  );

  test('Users with several roles keep all authorized workspaces', () {
    const user = CurrentUser(
      id: 4,
      name: 'Multi',
      email: 'multi@test',
      roles: {'EMPLOYEE', 'STORE_MANAGER', 'SYSTEM_ADMIN'},
      permissions: {},
      employeeId: 14,
    );
    expect(user.workspaces.length, 3);
  });
}
