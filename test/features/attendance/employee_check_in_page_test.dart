import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_client.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_exception.dart';
import 'package:hrm_coffee_shop_flutter/data/repositories/employee_providers.dart';
import 'package:hrm_coffee_shop_flutter/data/repositories/employee_repository.dart';
import 'package:hrm_coffee_shop_flutter/features/attendance/presentation/employee_check_in_page.dart';

void main() {
  final originalGeolocator = GeolocatorPlatform.instance;
  setUp(() {
    GeolocatorPlatform.instance = _DisabledLocationGeolocator();
  });
  tearDown(() {
    GeolocatorPlatform.instance = originalGeolocator;
  });

  testWidgets('check-in shows server shift and device approval requirement', (
    tester,
  ) async {
    final api = _CheckInApi();
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    expect(
      api.requestedPaths,
      containsAll([
        '/api/v1/attendance/me/current',
        '/api/v1/attendance/devices/me',
        '/api/v1/stores/current',
      ]),
    );
    expect(find.textContaining('Ca sáng'), findsOneWidget);
    expect(
      find.text('Cần đăng ký và được quản lý phê duyệt trước khi chấm công.'),
      findsOneWidget,
    );
    expect(find.text('Đăng ký thiết bị này'), findsOneWidget);
    expect(find.text('Ảnh xác minh'), findsOneWidget);
    expect(find.text('Xác nhận check-in'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Xác nhận check-in'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('check-in load failure exposes a retry action', (tester) async {
    final api = _CheckInApi(failShiftFirst: true);
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Tạm thời không kết nối.'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Tạm thời không kết nối.'), findsOneWidget);
    await tester.tap(find.byTooltip('Tải lại ca làm'));
    await tester.pumpAndSettle();

    expect(api.shiftCalls, 2);
    await tester.drag(
      find.byType(Scrollable).first,
      const Offset(0, 900),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Ca sáng'), findsOneWidget);
  });
}

class _DisabledLocationGeolocator extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => false;
}

Widget _app(_CheckInApi api) => ProviderScope(
  overrides: [
    employeeRepositoryProvider.overrideWithValue(EmployeeRepository(api)),
  ],
  child: const MaterialApp(home: EmployeeCheckInPage()),
);

class _CheckInApi extends ApiClient {
  _CheckInApi({this.failShiftFirst = false})
    : super(dio: Dio(), storage: const FlutterSecureStorage());

  final bool failShiftFirst;
  final List<String> requestedPaths = [];
  var shiftCalls = 0;

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    requestedPaths.add(path);
    dynamic data;
    if (path == '/api/v1/attendance/me/current') {
      shiftCalls++;
      if (failShiftFirst && shiftCalls == 1) {
        throw const ApiException(message: 'Tạm thời không kết nối.');
      }
      data = {
        'shiftAssignmentId': 301,
        'shiftName': 'Ca sáng',
        'plannedStartAt': '2026-11-03T08:00:00+07:00',
        'plannedEndAt': '2026-11-03T16:00:00+07:00',
        'attendanceStatus': 'NOT_STARTED',
        'canCheckIn': true,
        'canCheckOut': false,
        'blockers': [],
      };
    } else if (path == '/api/v1/attendance/devices/me') {
      data = <Map<String, dynamic>>[];
    } else if (path == '/api/v1/stores/current') {
      data = {
        'storeName': 'HRM Coffee Shop',
        'latitude': 10.7769,
        'longitude': 106.7009,
        'attendanceRadiusMeters': 150,
        'gpsMaxAccuracyMeters': 100,
      };
    } else {
      throw StateError('Unexpected GET $path');
    }
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      data: {'success': true, 'data': data},
    );
  }
}
