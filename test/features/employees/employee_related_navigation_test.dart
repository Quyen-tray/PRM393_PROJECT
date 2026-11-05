import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_coffee_shop_flutter/app/app.dart';
import 'package:hrm_coffee_shop_flutter/app/router/app_router.dart';
import 'package:hrm_coffee_shop_flutter/features/employees/presentation/employee_related_page.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/data/session_controller.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_providers.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';
import '../../support/test_support.dart';
import '../../support/resource_fixtures.dart';

class EmployeeRepository extends FixtureRepository {
  EmployeeRepository(super.api);
  @override
  Future<dynamic> read(String path, [Json query = const {}]) async =>
      switch (path) {
        '/employees/12' => {
            'employeeId': 12,
            'fullName': 'Test employee',
            'employeeCode': 'NV12',
            'employmentStatus': 'ACTIVE'
          },
        '/attendance/devices/employees/12' => [
            {
              'deviceId': 4,
              'employeeId': 12,
              'employeeName': 'Device owner',
              'status': 'ACTIVE'
            }
          ],
        '/attendance/devices/4' => {
            'deviceId': 4,
            'employeeId': 12,
            'employeeName': 'Device owner',
            'status': 'ACTIVE'
          },
        _ => super.read(path, query),
      };
}

void main() {
  testWidgets(
      'Manager employee sections preserve navigation back from device detail',
      (tester) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(overrides: [
      sessionProvider.overrideWith(() => FixedSession(const SessionState(
          user: CurrentUser(id: 2, name: 'Manager', email: 'm@test', roles: {
            'STORE_MANAGER'
          }, permissions: {
            'EMPLOYEE_VIEW',
            'EMPLOYEE_MANAGE',
            'DEVICE_APPROVE'
          }),
          workspace: Workspace.manager))),
      resourceRepositoryProvider.overrideWith(
          (ref) => EmployeeRepository(ref.read(authenticatedApiProvider))),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const BeanHubApp()));
    await tester.pumpAndSettle();
    final router = container.read(routerProvider);
    router.go('/record/employees/12');
    await tester.pumpAndSettle();
    expect(find.text('Chỉnh sửa'), findsNothing);
    expect(find.text('Thay đổi trạng thái làm việc'), findsNothing);
    final devices = find.text('Thiết bị chấm công');
    await tester.ensureVisible(devices);
    await tester.tap(devices);
    await tester.pumpAndSettle();
    expect(find.byType(EmployeeRelatedPage), findsOneWidget);
    await tester.tap(find.text('Device owner'));
    await tester.pumpAndSettle();
    expect(find.text('Thu hồi thiết bị'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(EmployeeRelatedPage), findsOneWidget);
    expect(find.text('Hồ sơ nhân viên'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
