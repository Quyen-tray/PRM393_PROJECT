import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:hrm_coffee_shop_flutter/data/repositories/employee_providers.dart';
import 'package:hrm_coffee_shop_flutter/data/repositories/employee_repository.dart';
import 'package:hrm_coffee_shop_flutter/features/admin/presentation/admin_account_management_page.dart';
import 'package:hrm_coffee_shop_flutter/features/admin/presentation/admin_account_permissions_page.dart';
import 'package:hrm_coffee_shop_flutter/features/rewards/presentation/manager_reward_penalty_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('permissions save completes without a framework exception',
      (tester) async {
    final repository = _ErrorLogRepository();
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
    expect(repository.savedPermissionSets, ['HR']);
    expect(find.text('Quy\u1ec1n hi\u1ec7u l\u1ef1c: 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling account creation sends no create request',
      (tester) async {
    final repository = _ErrorLogRepository();
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
    await tester.tap(find.text('H\u1ee7y'));
    await tester.pumpAndSettle();

    expect(repository.createCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rejecting a decision keeps its reason and refreshes the list',
      (tester) async {
    final repository = _ErrorLogRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          employeeRepositoryProvider.overrideWith((ref) => repository)
        ],
        child: const MaterialApp(home: ManagerRewardPenaltyPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('T\u1eeb ch\u1ed1i'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Duplicate decision');
    await tester.tap(find.widgetWithText(FilledButton, 'X\u00e1c nh\u1eadn'));
    await tester.pumpAndSettle();

    expect(repository.rejectedId, 'PENALTY-1');
    expect(repository.rejectionReason, 'Duplicate decision');
    expect(repository.listCalls, 2);
    expect(
        find.text(
            'Kh\u00f4ng c\u00f3 quy\u1ebft \u0111\u1ecbnh n\u00e0o trong m\u1ee5c n\u00e0y.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _ErrorLogRepository implements EmployeeRepository {
  int saveCalls = 0;
  int createCalls = 0;
  int listCalls = 0;
  List<String> savedPermissionSets = [];
  String? rejectedId;
  String? rejectionReason;

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
    savedPermissionSets = permissionSets;
    return const {
      'direct': ['EMPLOYEE_VIEW'],
      'effective': ['EMPLOYEE_VIEW'],
    };
  }

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
  Future<CurrentAccess> getCurrentAccess() async => const CurrentAccess(
        roles: {'STORE_MANAGER'},
        permissions: {'REWARD_VIEW', 'REWARD_APPROVE'},
      );

  @override
  Future<Map<String, dynamic>> getDecisions({
    String? type,
    String? status,
    int? employeeId,
    int page = 0,
  }) async {
    listCalls++;
    if (listCalls > 1) {
      return const {
        'items': [],
        'page': 0,
        'totalPages': 0,
        'totalElements': 0
      };
    }
    return const {
      'items': [
        {
          'decisionId': 'PENALTY-1',
          'decisionType': 'PENALTY',
          'employeeId': 12,
          'employeeName': 'Test employee',
          'reasonCode': 'POLICY',
          'reasonName': 'Policy violation',
          'severity': 'MINOR',
          'description': 'Test decision',
          'status': 'PENDING_APPROVAL',
        },
      ],
      'page': 0,
      'totalPages': 1,
      'totalElements': 1,
    };
  }

  @override
  Future<Map<String, dynamic>> rejectDecision(
    String decisionId, {
    required String reason,
  }) async {
    rejectedId = decisionId;
    rejectionReason = reason;
    return const {};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
