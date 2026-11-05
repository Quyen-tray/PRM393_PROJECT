import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_coffee_shop_flutter/app/app.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/data/session_controller.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_providers.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';
import '../../support/test_support.dart';
import '../../support/resource_fixtures.dart';

void main() {
  testWidgets(
      'Dashboard keeps Check-out visible after check-in even when device needs attention',
      (tester) async {
    final container = ProviderContainer(overrides: [
      sessionProvider.overrideWith(() => FixedSession(const SessionState(
          user: employeeUser, workspace: Workspace.employee))),
      resourceRepositoryProvider.overrideWith(
          (ref) => _CheckedInRepository(ref.read(authenticatedApiProvider))),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const BeanHubApp()));
    await tester.pumpAndSettle();
    expect(find.text('Check-out'), findsOneWidget);
    expect(find.text('Check-in · xem điều kiện'), findsNothing);
  });
  testWidgets(
    'A blocked check-in still opens its diagnostic page and has back navigation',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer(
        overrides: [
          sessionStoreProvider.overrideWithValue(MemoryStore()),
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
      await tester.tap(find.text('Check-in · xem điều kiện'));
      await tester.pumpAndSettle();
      expect(find.text('Chấm công tại cửa hàng'), findsOneWidget);
      expect(
        find.textContaining('Bản cài đặt này chưa có thiết bị được duyệt'),
        findsOneWidget,
      );
      final submit = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Xác nhận check-in'),
      );
      expect(submit.onPressed, isNull);
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();
      expect(find.text('Check-in · xem điều kiện'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _CheckedInRepository extends FixtureRepository {
  _CheckedInRepository(super.api);
  @override
  Future<dynamic> read(String path, [Json query = const {}]) async =>
      path == '/attendance/me/current'
          ? {
              'shiftAssignmentId': 20,
              'shiftName': 'Ca đang làm',
              'attendanceId': 30,
              'attendanceStatus': 'CHECKED_IN',
              'canCheckIn': false,
              'canCheckOut': false,
              'blockers': ['DEVICE_NOT_ACTIVE'],
            }
          : super.read(path, query);
}
