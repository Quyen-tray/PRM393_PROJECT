import 'dart:typed_data';
import 'dart:convert';
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
  final bool photoRequired;
  bool checkout;
  String deviceStatus = 'ACTIVE';
  @override
  Future<dynamic> read(String path, [Json query = const {}]) async =>
      switch (path) {
        '/attendance/me/current' => {
            'shiftAssignmentId': 20,
            'shiftName': 'Ca hiện tại',
            if (checkout) 'attendanceId': 30,
            if (checkout) 'attendanceStatus': 'CHECKED_IN',
            'canCheckIn': !checkout && deviceStatus == 'ACTIVE',
            'canCheckOut': checkout && deviceStatus == 'ACTIVE',
            'photoRequired': photoRequired,
            'blockers': [],
          },
        '/attendance/devices/current' => {
            'deviceId': 5,
            'status': deviceStatus
          },
        _ => super.read(path, query),
      };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final photoBytes = Uint8List.fromList(base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII='));
  final position = Position(
      latitude: 21.0278,
      longitude: 105.8342,
      timestamp: DateTime.now().toUtc(),
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
      'Manual GPS survives photo capture and is sent with required photo evidence',
      () async {
    final requests = <RequestOptions>[];
    final container = await setup(
        photoRequired: false,
        handler: (request) async {
          requests.add(request);
          if (request.path.endsWith('/storage/uploads')) {
            return response({'storageKey': 'uploaded-photo'});
          }
          return response({'attendanceId': 30});
        });
    final controller = container.read(attendanceControllerProvider.notifier);
    await controller.locate();
    controller.setPhoto(photoBytes);
    expect(container.read(attendanceControllerProvider).requireValue.positionFresh,
        true);
    await controller.submit();
    expect(requests, hasLength(2));
    final attendance = requests.firstWhere(
        (request) => request.path.endsWith('/attendance/check-in'));
    expect(attendance.headers['X-Device-Credential'], 'installation-5');
    final body = attendance.data as Map;
    expect(body['photoEvidence']['storageKey'], 'uploaded-photo');
    expect(body['shiftAssignmentId'], 20);
    expect(body['location']['accuracyMeters'], 5);
    expect(body['location']['isMocked'], false);
    expect(attendance.headers['Idempotency-Key'], body['idempotencyKey']);
    expect(
        await container.read(sessionStoreProvider).read('attendance-pending-1'),
        isNull);
  });

  test(
      'Device approval refresh unlocks check-in and preserves the captured photo',
      () async {
    final container =
        await setup(photoRequired: true, handler: (_) async => response({}));
    final repository =
        container.read(resourceRepositoryProvider) as ReadyAttendanceRepository;
    final controller = container.read(attendanceControllerProvider.notifier);
    repository.deviceStatus = 'PENDING';
    await controller.refreshStatus();
    expect(
        container
            .read(attendanceControllerProvider)
            .requireValue
            .shift!['canCheckIn'],
        false);
    final photo = Uint8List.fromList([255, 216, 255, 0]);
    controller.setPhoto(photo);
    repository.deviceStatus = 'ACTIVE';
    await controller.refreshStatus();
    final state = container.read(attendanceControllerProvider).requireValue;
    expect(state.shift!['canCheckIn'], true);
    expect(state.device!['status'], 'ACTIVE');
    expect(state.photo, same(photo));
  });

  test('Refreshing a completed check-in prepares check-out with a new photo',
      () async {
    final container =
        await setup(photoRequired: true, handler: (_) async => response({}));
    final controller = container.read(attendanceControllerProvider.notifier);
    controller.setPhoto(Uint8List.fromList([255, 216, 255, 0]));
    (container.read(resourceRepositoryProvider) as ReadyAttendanceRepository)
        .checkout = true;
    await controller.refreshStatus();
    final state = container.read(attendanceControllerProvider).requireValue;
    expect(state.checkout, true);
    expect(state.photo, isNull);
  });

  test('An already committed check-in updates the screen to check-out',
      () async {
    late ProviderContainer container;
    container = await setup(
        photoRequired: false,
        handler: (_) async {
          (container.read(resourceRepositoryProvider)
                  as ReadyAttendanceRepository)
              .checkout = true;
          return response(null,
              status: 409, code: 'ATTENDANCE_ALREADY_CHECKED_IN');
        });
    final controller = container.read(attendanceControllerProvider.notifier);
    await controller.locate();
    controller.setPhoto(Uint8List.fromList([255, 216, 255, 0]));
    await controller.submit();
    final state = container.read(attendanceControllerProvider).requireValue;
    expect(state.checkout, true);
    expect(state.pending, isNull);
    expect(state.error, isNull);
    expect(state.message, contains('tiếp tục check-out'));
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
      'Manual GPS remains valid after photo upload and is used for attendance',
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
    final controller = container.read(attendanceControllerProvider.notifier);
    await controller.locate();
    controller.setPhoto(Uint8List.fromList([255, 216, 255, 0]));
    expect(container.read(attendanceControllerProvider).requireValue.positionFresh,
        true);
    await controller.submit();
    expect(sequence, ['gps', 'upload', 'attendance']);
  });

  test(
      'An uncertain checkout retries the same operation without recapture or duplicate upload',
      () async {
    int attempts = 0, locations = 0, uploads = 0;
    final bodies = <Object?>[], keys = <Object?>[];
    final container = await setup(
        photoRequired: false,
        checkout: true,
        locate: () async {
          locations++;
          return position;
        },
        handler: (request) async {
          if (request.path.endsWith('/storage/uploads')) {
            uploads++;
            return response({'storageKey': 'uploaded-photo'});
          }
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
    await controller.locate();
    controller.setPhoto(Uint8List.fromList([255, 216, 255, 0]));
    await controller.submit();
    expect(container.read(attendanceControllerProvider).requireValue.pending,
        isNotNull);
    await controller.submit(retry: true);
    expect(attempts, 2);
    expect(locations, 1);
    expect(uploads, 1);
    expect(bodies[0], bodies[1]);
    expect(keys[0], keys[1]);
    expect((bodies.first as Map)['attendanceId'], 30);
    expect(
        await container.read(sessionStoreProvider).read('attendance-pending-1'),
        isNull);
  });

  testWidgets(
      'The waiting screen detects device approval without leaving the page',
      (tester) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container =
        await setup(photoRequired: false, handler: (_) async => response({}));
    final repository =
        container.read(resourceRepositoryProvider) as ReadyAttendanceRepository;
    final controller = container.read(attendanceControllerProvider.notifier);
    await controller.locate();
    controller.setPhoto(photoBytes);
    repository.deviceStatus = 'PENDING';
    await controller.refreshStatus();
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: CheckInScreen()))));
    await tester.pumpAndSettle();
    FilledButton submit() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Xác nhận check-in'));
    expect(submit().onPressed, isNull);
    repository.deviceStatus = 'ACTIVE';
    await tester.pump(const Duration(seconds: 20));
    await tester.pumpAndSettle();
    expect(submit().onPressed, isNotNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'Photo and manually captured GPS are required even if server marks photo optional',
      (tester) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container =
        await setup(photoRequired: false, handler: (_) async => response({}));
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: CheckInScreen()))));
    await tester.pumpAndSettle();
    expect(find.text('Mở camera và chụp ảnh'), findsOneWidget);
    expect(find.text('Ảnh xác minh'), findsOneWidget);
    final submit = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Xác nhận check-in'));
    expect(submit.onPressed, isNull);
    await tester.tap(find.text('Lấy vị trí GPS'));
    await tester.pumpAndSettle();
    container.read(attendanceControllerProvider.notifier).setPhoto(photoBytes);
    await tester.pumpAndSettle();
    final readySubmit = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Xác nhận check-in'));
    expect(readySubmit.onPressed, isNotNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('Spot-check photo capture preserves its manually captured GPS',
      () async {
    final container =
        await setup(photoRequired: false, handler: (_) async => response({}));
    final controller = container.read(attendanceControllerProvider.notifier);
    await controller.locateSpotCheck();
    controller.setSpotCheckPhoto(Uint8List.fromList([255, 216, 255, 0]));
    final state = container.read(attendanceControllerProvider).requireValue;
    expect(state.spotCheckPosition, same(position));
    expect(state.spotCheckPositionFresh, true);
    expect(state.spotCheckPhoto, isNotNull);
  });
}
