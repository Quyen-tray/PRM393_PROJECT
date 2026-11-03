import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_coffee_shop_flutter/data/repositories/employee_providers.dart';
import 'package:hrm_coffee_shop_flutter/data/repositories/employee_repository.dart';
import 'package:hrm_coffee_shop_flutter/features/admin/presentation/admin_account_permissions_page.dart';

void main() {
  testWidgets('saving permissions keeps the server response in the page state',
      (tester) async {
    final repository = _PermissionsRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          employeeRepositoryProvider.overrideWith((ref) => repository)
        ],
        child: const MaterialApp(
          home: AdminAccountPermissionsPage(userId: 7),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('L\u01b0u thay \u0111\u1ed5i'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'X\u00e1c nh\u1eadn'));
    await tester.pumpAndSettle();

    expect(repository.saveCalls, 1);
    expect(repository.savedPermissions, isEmpty);
    expect(repository.savedPermissionSets, ['HR']);
    expect(find.text('Quy\u1ec1n hi\u1ec7u l\u1ef1c: 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _PermissionsRepository implements EmployeeRepository {
  int saveCalls = 0;
  List<String> savedPermissions = [];
  List<String> savedPermissionSets = [];

  @override
  Future<Map<String, dynamic>> getPermissionCatalog() async => const {
        'permissions': [
          {'code': 'EMPLOYEE_VIEW', 'name': 'View employees'},
        ],
        'permissionSets': {
          'HR': ['EMPLOYEE_VIEW'],
        },
      };

  @override
  Future<Map<String, dynamic>> getUserPermissions(int userId) async => const {
        'roles': ['EMPLOYEE'],
        'direct': [],
        'effective': [],
      };

  @override
  Future<Map<String, dynamic>> setUserPermissions(
    int userId, {
    required List<String> permissions,
    required List<String> permissionSets,
  }) async {
    saveCalls++;
    savedPermissions = permissions;
    savedPermissionSets = permissionSets;
    return {
      'direct': ['EMPLOYEE_VIEW'],
      'effective': ['EMPLOYEE_VIEW'],
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
