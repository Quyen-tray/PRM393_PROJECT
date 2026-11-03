import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hrm_coffee_shop_flutter/app/router/route_names.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_client.dart';
import 'package:hrm_coffee_shop_flutter/data/repositories/employee_providers.dart';
import 'package:hrm_coffee_shop_flutter/data/repositories/employee_repository.dart';
import 'package:hrm_coffee_shop_flutter/features/schedule/presentation/employee_schedule_page.dart';

void main() {
  testWidgets('schedule renders API shifts and switches week/month periods', (
    tester,
  ) async {
    final api = _ScheduleApi();
    await tester.pumpWidget(_scheduleApp(api));
    await tester.pumpAndSettle();

    expect(find.text('Opening shift'), findsOneWidget);
    expect(find.text('Đã xác nhận'), findsOneWidget);
    expect(api.scheduleCalls, 1);

    await tester.tap(find.text('Tháng'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tháng '), findsOneWidget);
    await tester.tap(find.byTooltip('Tháng sau'));
    await tester.pumpAndSettle();
    expect(api.scheduleCalls, 2);

    await tester.tap(find.text('Tuần'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tuần '), findsOneWidget);
  });

  testWidgets('schedule offers retry after its API request fails', (
    tester,
  ) async {
    final api = _ScheduleApi(failFirstRequest: true);
    await tester.pumpWidget(_scheduleApp(api));
    await tester.pumpAndSettle();

    expect(find.text('Thử lại'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Opening shift'), findsOneWidget);
    expect(api.scheduleCalls, 2);
  });

  testWidgets('schedule bottom navigation opens checklist and profile', (
    tester,
  ) async {
    final api = _ScheduleApi();
    final router = GoRouter(
      initialLocation: RouteNames.employeeSchedule,
      routes: [
        GoRoute(
          path: RouteNames.employeeSchedule,
          builder: (_, __) => const EmployeeSchedulePage(),
        ),
        GoRoute(
          path: RouteNames.employeeChecklist,
          builder: (_, __) => const Text('Checklist destination'),
        ),
        GoRoute(
          path: RouteNames.employeeProfile,
          builder: (_, __) => const Text('Profile destination'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          employeeRepositoryProvider.overrideWithValue(EmployeeRepository(api)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Checklist'));
    await tester.pumpAndSettle();
    expect(find.text('Checklist destination'), findsOneWidget);
    router.go(RouteNames.employeeSchedule);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cá nhân'));
    await tester.pumpAndSettle();
    expect(find.text('Profile destination'), findsOneWidget);
  });
}

Widget _scheduleApp(_ScheduleApi api) => ProviderScope(
  overrides: [
    employeeRepositoryProvider.overrideWithValue(EmployeeRepository(api)),
  ],
  child: const MaterialApp(home: EmployeeSchedulePage()),
);

class _ScheduleApi extends ApiClient {
  _ScheduleApi({this.failFirstRequest = false})
    : super(dio: Dio(), storage: const FlutterSecureStorage());

  final bool failFirstRequest;
  int scheduleCalls = 0;

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    if (path != '/api/v1/shift-assignments/me') {
      throw StateError('Unexpected GET $path');
    }
    scheduleCalls++;
    if (failFirstRequest && scheduleCalls == 1) {
      throw StateError('temporary failure');
    }
    final date = DateTime.now();
    final workDate =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      data: {
        'success': true,
        'data': [
          {
            'workDate': workDate,
            'plannedStartAt': '${workDate}T08:00:00+07:00',
            'plannedEndAt': '${workDate}T16:00:00+07:00',
            'status': 'PUBLISHED',
            'workShift': {'shiftName': 'Opening shift'},
          },
        ],
      },
    );
  }
}
