import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_coffee_shop_flutter/data/repositories/employee_providers.dart';
import 'package:hrm_coffee_shop_flutter/data/repositories/employee_repository.dart';
import 'package:hrm_coffee_shop_flutter/features/admin/presentation/admin_account_management_page.dart';

void main() {
  testWidgets('cancelling account creation does not send a create request',
      (tester) async {
    final repository = _AccountsRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          employeeRepositoryProvider.overrideWith((ref) => repository)
        ],
        child: const MaterialApp(home: AdminAccountManagementPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('T\u1ea1o t\u00e0i kho\u1ea3n'), findsOneWidget);

    await tester.tap(find.text('H\u1ee7y'));
    await tester.pumpAndSettle();

    expect(repository.createCalls, 0);
    expect(tester.takeException(), isNull);
  });
}

class _AccountsRepository implements EmployeeRepository {
  int createCalls = 0;

  @override
  Future<List<Map<String, dynamic>>> getAllAdminUsers(
          {int maxPages = 100}) async =>
      const [];

  @override
  Future<Map<String, dynamic>> createAdminUser({
    required String email,
    required String displayName,
    String? phoneNumber,
    required List<String> roles,
  }) async {
    createCalls++;
    return const {};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
