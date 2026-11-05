import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hrm_coffee_shop_flutter/core/location/location_service.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_providers.dart';
import 'package:hrm_coffee_shop_flutter/core/network/authenticated_api.dart';
import 'package:hrm_coffee_shop_flutter/core/storage/session_store.dart';
import 'package:hrm_coffee_shop_flutter/features/attendance/data/attendance_controller.dart';
import 'package:hrm_coffee_shop_flutter/features/attendance/presentation/check_in_screen.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/data/session_controller.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';
import '../../support/resource_fixtures.dart';
import '../../support/test_support.dart';

class ReadyAttendanceRepository extends FixtureRepository {
  ReadyAttendanceRepository(super.api,
      {required this.photoRequired, this.checkout = false});
  final bool photoRequired, checkout;
  @override
  Future<dynamic> read(String path, [Json query = const {}]) async =>
      switch (path) {
        '/attendance/me/current' => {
            'shiftAssignmentId': 20,
            'shiftName': 'Ca hiện tại',
            if (checkout) 'attendanceId': 30,
            if (checkout) 'attendanceStatus': 'CHECKED_IN',
            'canCheckIn': !checkout,
            'canCheckOut': checkout,
            'photoRequired': photoRequired,
            'blockers': [],
          },
        '/attendance/devices/current' => {'deviceId': 5, 'status': 'ACTIVE'},
        _ => super.read(path, query),
      };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final position = Position(
      latitude: 21.0278,
      longitude: 105.8342,
      timestamp: DateTime.utc(2026, 11, 5),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 1,
      heading: 0,
      headingAccuracy: 1,
      speed: 0,
      speedAccuracy: 1);

  Future<ProviderContainer> setup(
      {required bool photoRequired,
      bool checkout = false,
      required Future<ResponseBody> Function(RequestOptions) handler,
      Future<Position> Function()? locate}) async {
    final store =
        MemoryStore({'access': 'test', 'device-credential': 'installation-5'});
    final vault = TokenVault(store);
    await vault.load();
    final dio = Dio(BaseOptions(baseUrl: 'http://unit.test'));
    dio.httpClientAdapter = TestAdapter(handler);
    final api = AuthenticatedApi(transport: dio, vault: vault);
    final container = ProviderContainer(overrides: [
      sessionProvider.overrideWith(() => FixedSession(const SessionState(
          user: employeeUser, workspace: Workspace.employee))),
      sessionStoreProvider.overrideWithValue(store),
      authenticatedApiProvider.overrideWithValue(api),
      resourceRepositoryProvider.overrideWithValue(ReadyAttendanceRepository(
          api,
          photoRequired: photoRequired,
          checkout: checkout)),
      locationProvider.overrideWithValue(locate ?? () async => position),
    ]);
    final subscription =
        container.listen(attendanceControllerProvider, (_, __) {});
    addTearDown(subscription.close);
    addTearDown(container.dispose);
    await container.read(attendanceControllerProvider.future);
    return container;
  }

  test(
      'An unselected camera sends fresh GPS and installation identity without uploading a photo',
      () async {
    final requests = <RequestOptions>[];
    final container = await setup(
        photoRequired: false,
        handler: (request) async {
          requests.add(request);
          return response({'attendanceId': 30});
        });
    await container.read(attendanceControllerProvider.notifier).submit();
    expect(requests, hasLength(1));
    expect(requests.single.path, '/api/v1/attendance/check-in');
    expect(requests.single.headers['X-Device-Credential'], 'installation-5');
    final body = requests.single.data as Map;
    expect(body.containsKey('photoEvidence'), false);
    expect(body['shiftAssignmentId'], 20);
    expect(body['location']['accuracyMeters'], 5);
    expect(requests.single.headers['Idempotency-Key'], body['idempotencyKey']);
    expect(
        await container.read(sessionStoreProvider).read('attendance-pending-1'),
        isNull);
  });

  test('A selected camera blocks submit until a photo is captured', () async {
    int requests = 0;
    final container = await setup(
        photoRequired: true,
        handler: (_) async {
          requests++;
          return response({});
        });
    await container.read(attendanceControllerProvider.notifier).submit();
    expect(requests, 0);
    expect(
        container
            .read(attendanceControllerProvider)
            .requireValue
            .error
            .toString(),
        contains('Cần chụp ảnh'));
  });

  test(
      'Photo upload finishes before GPS is sampled for the final attendance request',
      () async {
    final sequence = <String>[];
    final container = await setup(
        photoRequired: true,
        locate: () async {
          sequence.add('gps');
          return position;
        },
        handler: (request) async {
          if (request.path.endsWith('/storage/uploads')) {
            sequence.add('upload');
            return response({'storageKey': 'uploaded-photo'});
          }
          sequence.add('attendance');
          expect(request.data['photoEvidence']['storageKey'], 'uploaded-photo');
          return response({'attendanceId': 30});
        });
    container
        .read(attendanceControllerProvider.notifier)
        .setPhoto(Uint8List.fromList([255, 216, 255, 0]));
    await container.read(attendanceControllerProvider.notifier).submit();
    expect(sequence, ['upload', 'gps', 'attendance']);
  });

  test(
      'An uncertain checkout retries the same operation without recapture or duplicate upload',
      () async {
    int attempts = 0, locations = 0;
    final bodies = <Object?>[], keys = <Object?>[];
    final container = await setup(
        photoRequired: false,
        checkout: true,
        locate: () async {
          locations++;
          return position;
        },
        handler: (request) async {
          expect(request.path, '/api/v1/attendance/check-out');
          bodies.add(request.data);
          keys.add(request.headers['Idempotency-Key']);
          if (++attempts == 1) {
            throw DioException(
                requestOptions: request, type: DioExceptionType.receiveTimeout);
          }
          return response({'attendanceId': 30});
        });
    final controller = container.read(attendanceControllerProvider.notifier);
    await controller.submit();
    expect(container.read(attendanceControllerProvider).requireValue.pending,
        isNotNull);
    await controller.submit(retry: true);
    expect(attempts, 2);
    expect(locations, 1);
    expect(bodies[0], bodies[1]);
    expect(keys[0], keys[1]);
    expect((bodies.first as Map)['attendanceId'], 30);
    expect(
        await container.read(sessionStoreProvider).read('attendance-pending-1'),
        isNull);
  });

  for (final required in [true, false]) {
    testWidgets(
        'Camera selection $required controls the capture step and confirmation button',
        (tester) async {
      tester.view.physicalSize = const Size(420, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = await setup(
          photoRequired: required, handler: (_) async => response({}));
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: CheckInScreen()))));
      await tester.pumpAndSettle();
      expect(find.text('Mở camera và chụp ảnh'),
          required ? findsOneWidget : findsNothing);
      expect(find.text('Lượt này không yêu cầu chụp ảnh'),
          required ? findsNothing : findsOneWidget);
      final submit = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Xác nhận check-in'));
      expect(submit.onPressed == null, required);
      expect(tester.takeException(), isNull);
    });
  }
}
