import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_coffee_shop_flutter/data/repositories/employee_providers.dart';
import 'package:hrm_coffee_shop_flutter/data/repositories/employee_repository.dart';
import 'package:hrm_coffee_shop_flutter/features/rewards/presentation/manager_reward_penalty_page.dart';

void main() {
  testWidgets('rejecting a decision sends its reason and refreshes the list',
      (tester) async {
    final repository = _DecisionRepository();
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

class _DecisionRepository implements EmployeeRepository {
  int listCalls = 0;
  String? rejectedId;
  String? rejectionReason;

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
