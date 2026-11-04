import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_coffee_shop_flutter/app/app.dart';
import 'package:hrm_coffee_shop_flutter/app/router/app_router.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_exception.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_providers.dart';
import 'package:hrm_coffee_shop_flutter/core/presentation/resource_widgets.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/data/session_controller.dart';
import 'package:hrm_coffee_shop_flutter/features/operations/data/operations_repository.dart';
import 'package:hrm_coffee_shop_flutter/features/operations/domain/module_registry.dart';
import 'package:hrm_coffee_shop_flutter/features/operations/presentation/record_form.dart';
import 'package:hrm_coffee_shop_flutter/features/operations/presentation/record_detail_page.dart';
import 'support/test_support.dart';

class FixtureRepository extends OperationsRepository {
  FixtureRepository(super.api);
  @override
  Future<dynamic> read(String path, [Json query = const {}]) async =>
      switch (path) {
        '/attendance/me/current' => {
            'shiftAssignmentId': 20,
            'shiftName': 'Ca hôm nay',
            'plannedStartAt': '2026-11-04T08:00:00+07:00',
            'plannedEndAt': '2026-11-04T16:00:00+07:00',
            'canCheckIn': false,
            'canCheckOut': false,
            'blockers': ['DEVICE_NOT_ACTIVE']
          },
        '/attendance/devices/current' => null,
        '/stores/current' => {
            'name': 'Coffee test',
            'latitude': 21.0,
            'longitude': 105.0,
            'attendanceRadiusMeters': 100
          },
        '/dashboard/employee/overview' => {
            'profileStatus': 'COMPLETE',
            'shiftEligibility': 'ELIGIBLE'
          },
        '/notifications/me/unread-count' => {'unreadCount': 0},
        '/dashboard/tasks' => {'pending': {}},
        _ => <dynamic>[],
      };
}

class RecordingRepository extends FixtureRepository {
  RecordingRepository(super.api);
  final List<Json> writes = [];
  @override
  Future<dynamic> write(String method, String path, [Object? body]) async {
    writes.add({'method': method, 'path': path, 'body': body});
    return null;
  }
}

void main() {
  testWidgets('An empty secure session opens real sign-in UI', (tester) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [sessionStoreProvider.overrideWithValue(MemoryStore())],
        child: const BeanHubApp()));
    await tester.pumpAndSettle();
    expect(find.text('Đăng nhập bằng Google'), findsOneWidget);
    expect(find.textContaining('Tài khoản đã được'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'A blocked check-in still opens its diagnostic page and has back navigation',
      (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(overrides: [
      sessionStoreProvider.overrideWithValue(MemoryStore()),
      sessionProvider.overrideWith(() => FixedSession(const SessionState(
          user: employeeUser, workspace: Workspace.employee))),
      operationsRepositoryProvider.overrideWith(
          (ref) => FixtureRepository(ref.read(authenticatedApiProvider)))
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const BeanHubApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check-in · xem điều kiện'));
    await tester.pumpAndSettle();
    expect(find.text('Chấm công tại cửa hàng'), findsOneWidget);
    expect(find.textContaining('Bản cài đặt này chưa có thiết bị được duyệt'),
        findsOneWidget);
    final submit = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Xác nhận check-in'));
    expect(submit.onPressed, isNull);
    await tester.tap(find.byTooltip('Quay lại'));
    await tester.pumpAndSettle();
    expect(find.text('Check-in · xem điều kiện'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('A direct administrative URL shows 403 for Employee',
      (tester) async {
    final container = ProviderContainer(overrides: [
      sessionProvider.overrideWith(() => FixedSession(const SessionState(
          user: employeeUser, workspace: Workspace.employee))),
      operationsRepositoryProvider.overrideWith(
          (ref) => FixtureRepository(ref.read(authenticatedApiProvider)))
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const BeanHubApp()));
    await tester.pumpAndSettle();
    container.read(routerProvider).go('/module/accounts');
    await tester.pumpAndSettle();
    expect(find.text('403 · Không đủ quyền'), findsOneWidget);
  });
  testWidgets(
      'A route rechecks grants when the session changes on the same URL',
      (tester) async {
    final container = ProviderContainer(overrides: [
      sessionProvider.overrideWith(() => FixedSession(const SessionState(
          user: employeeUser, workspace: Workspace.employee))),
      operationsRepositoryProvider.overrideWith(
          (ref) => FixtureRepository(ref.read(authenticatedApiProvider)))
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const BeanHubApp()));
    await tester.pumpAndSettle();
    container.read(routerProvider).go('/module/accounts');
    await tester.pumpAndSettle();
    expect(find.text('403 · Không đủ quyền'), findsOneWidget);
    final session = container.read(sessionProvider.notifier) as FixedSession;
    session.replace(const SessionState(
        user: CurrentUser(
            id: 2,
            name: 'Admin',
            email: 'admin@example.test',
            roles: {'SYSTEM_ADMIN'},
            permissions: {}),
        workspace: Workspace.admin));
    await tester.pumpAndSettle();
    expect(find.text('403 · Không đủ quyền'), findsNothing);
    expect(find.text('Tạo mới'), findsOneWidget);
    session.replace(
        const SessionState(user: employeeUser, workspace: Workspace.employee));
    await tester.pumpAndSettle();
    expect(find.text('403 · Không đủ quyền'), findsOneWidget);
    expect(find.text('Tạo mới'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Backend validation preserves form input and prevents duplicate submit',
      (tester) async {
    final pending = Completer<void>();
    int calls = 0;
    await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
            home: RecordForm(
                title: 'Cập nhật',
                fields: const [FieldSpec('name', 'Tên', required: true)],
                onSubmit: (value) async {
                  calls++;
                  await pending.future;
                  throw const ApiException(
                      message: 'Tên đã tồn tại', statusCode: 409);
                }))));
    await tester.enterText(find.byType(TextFormField), 'Tên đã nhập');
    await tester.tap(find.text('Lưu và hoàn tất'));
    await tester.pump();
    expect(calls, 1);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Tên đã nhập'), findsOneWidget);
    expect(find.byType(ErrorPanel), findsOneWidget);
    expect(find.text('Tên đã tồn tại'), findsOneWidget);
  });
  testWidgets('A form can finish after its originating resource widget reloads',
      (tester) async {
    late VoidCallback removeOrigin;
    bool showOrigin = true;
    late RecordingRepository repository;
    await tester.pumpWidget(ProviderScope(
        overrides: [
          operationsRepositoryProvider.overrideWith((ref) => repository =
              RecordingRepository(ref.read(authenticatedApiProvider)))
        ],
        child: MaterialApp(home: StatefulBuilder(builder: (context, setState) {
          removeOrigin = () => setState(() => showOrigin = false);
          return Scaffold(
              body: showOrigin
                  ? Consumer(
                      builder: (context, ref, _) => TextButton(
                          onPressed: () => editRecord(context, ref,
                              title: 'Gửi yêu cầu',
                              fields: const [
                                FieldSpec('reason', 'Nội dung',
                                    kind: FieldKind.multiline, required: true)
                              ],
                              path: '/requests'),
                          child: const Text('Mở form')))
                  : const SizedBox.shrink());
        }))));
    await tester.tap(find.text('Mở form'));
    await tester.pumpAndSettle();
    removeOrigin();
    await tester.pump();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.keyboardType, TextInputType.multiline);
    await tester.enterText(
        find.byType(TextFormField), 'Nội dung đã nhập\nDòng tiếp theo');
    await tester.tap(find.text('Lưu và hoàn tất'));
    await tester.pumpAndSettle();
    expect(repository.writes.single['path'], '/requests');
    expect(repository.writes.single['body'],
        {'reason': 'Nội dung đã nhập\nDòng tiếp theo'});
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'A device reviewer can revoke their active device but cannot self-approve',
      (tester) async {
    const reviewer = CurrentUser(
        id: 1,
        name: 'Reviewer',
        email: 'reviewer@example.test',
        employeeId: 12,
        roles: {'EMPLOYEE'},
        permissions: {'DEVICE_APPROVE'});
    final container = ProviderContainer(overrides: [
      sessionProvider.overrideWith(() => FixedSession(
          const SessionState(user: reviewer, workspace: Workspace.employee))),
      operationsRepositoryProvider.overrideWith(
          (ref) => FixtureRepository(ref.read(authenticatedApiProvider)))
    ]);
    addTearDown(container.dispose);
    Widget screen(String status) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            home: Scaffold(
                body: RecordActions(spec: module('my-devices'), row: {
          'deviceId': 20,
          'employeeId': 12,
          'status': status
        }))));
    await tester.pumpWidget(screen('ACTIVE'));
    await tester.pumpAndSettle();
    expect(find.text('Thu hồi thiết bị'), findsOneWidget);
    await tester.pumpWidget(screen('PENDING'));
    await tester.pumpAndSettle();
    expect(find.text('Duyệt thiết bị'), findsNothing);
    expect(find.text('Từ chối thiết bị'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
