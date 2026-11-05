import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/data/session_controller.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_providers.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';
import 'package:hrm_coffee_shop_flutter/app/router/module_registry.dart';
import 'package:hrm_coffee_shop_flutter/features/workspace/presentation/record_actions.dart';
import '../../support/test_support.dart';
import '../../support/resource_fixtures.dart';

void main() {
  testWidgets(
    'A device reviewer can revoke their active device but cannot self-approve',
    (tester) async {
      const reviewer = CurrentUser(
        id: 1,
        name: 'Reviewer',
        email: 'reviewer@example.test',
        employeeId: 12,
        roles: {'EMPLOYEE'},
        permissions: {'DEVICE_APPROVE'},
      );
      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith(
            () => FixedSession(
              const SessionState(user: reviewer, workspace: Workspace.employee),
            ),
          ),
          resourceRepositoryProvider.overrideWith(
            (ref) => FixtureRepository(ref.read(authenticatedApiProvider)),
          ),
        ],
      );
      addTearDown(container.dispose);
      Widget screen(String status) => UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: RecordActions(
                  spec: module('my-devices'),
                  row: {'deviceId': 20, 'employeeId': 12, 'status': status},
                ),
              ),
            ),
          );
      await tester.pumpWidget(screen('ACTIVE'));
      await tester.pumpAndSettle();
      expect(find.text('Thu hồi thiết bị'), findsOneWidget);
      await tester.pumpWidget(screen('PENDING'));
      await tester.pumpAndSettle();
      expect(find.text('Duyệt thiết bị'), findsNothing);
      expect(find.text('Từ chối thiết bị'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
