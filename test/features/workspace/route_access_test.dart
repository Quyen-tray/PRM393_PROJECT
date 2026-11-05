import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_coffee_shop_flutter/app/app.dart';
import 'package:hrm_coffee_shop_flutter/app/router/app_router.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/data/session_controller.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_providers.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';
import '../../support/test_support.dart';
import '../../support/resource_fixtures.dart';

void main() {
  testWidgets('A direct administrative URL shows 403 for Employee', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(
          () => FixedSession(
            const SessionState(
              user: employeeUser,
              workspace: Workspace.employee,
            ),
          ),
        ),
        resourceRepositoryProvider.overrideWith(
          (ref) => FixtureRepository(ref.read(authenticatedApiProvider)),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BeanHubApp(),
      ),
    );
    await tester.pumpAndSettle();
    container.read(routerProvider).go('/module/accounts');
    await tester.pumpAndSettle();
    expect(find.text('403 · Không đủ quyền'), findsOneWidget);
  });

  testWidgets(
    'A route rechecks grants when the session changes on the same URL',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          sessionProvider.overrideWith(
            () => FixedSession(
              const SessionState(
                user: employeeUser,
                workspace: Workspace.employee,
              ),
            ),
          ),
          resourceRepositoryProvider.overrideWith(
            (ref) => FixtureRepository(ref.read(authenticatedApiProvider)),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const BeanHubApp(),
        ),
      );
      await tester.pumpAndSettle();
      container.read(routerProvider).go('/module/accounts');
      await tester.pumpAndSettle();
      expect(find.text('403 · Không đủ quyền'), findsOneWidget);
      final session = container.read(sessionProvider.notifier) as FixedSession;
      session.replace(
        const SessionState(
          user: CurrentUser(
            id: 2,
            name: 'Admin',
            email: 'admin@example.test',
            roles: {'SYSTEM_ADMIN'},
            permissions: {},
          ),
          workspace: Workspace.admin,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('403 · Không đủ quyền'), findsNothing);
      expect(find.text('Tạo mới'), findsOneWidget);
      session.replace(
        const SessionState(user: employeeUser, workspace: Workspace.employee),
      );
      await tester.pumpAndSettle();
      expect(find.text('403 · Không đủ quyền'), findsOneWidget);
      expect(find.text('Tạo mới'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
