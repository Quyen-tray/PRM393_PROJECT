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
import 'package:hrm_coffee_shop_flutter/features/approvals/presentation/manager_device_approval_page.dart';
import 'package:hrm_coffee_shop_flutter/features/home/presentation/widgets/manager_more_menu.dart';

void main() {
  testWidgets('shows device requests and refreshes the approval list', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final api = _DeviceApprovalApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          employeeRepositoryProvider.overrideWithValue(EmployeeRepository(api)),
        ],
        child: const MaterialApp(home: ManagerDeviceApprovalPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pixel 8 Emulator'), findsOneWidget);
    expect(find.text('Nhân viên: Nguyen Van An'), findsOneWidget);
    expect(find.text('Phê duyệt'), findsOneWidget);

    api.addSecondDevice = true;
    await tester.pump(const Duration(seconds: 20));
    await tester.pumpAndSettle();

    expect(find.text('Samsung Test Device'), findsOneWidget);
    expect(api.pendingRequests, greaterThanOrEqualTo(2));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('manager can open device management from the More menu', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/manager',
      routes: [
        GoRoute(
          path: '/manager',
          builder: (context, _) => Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showManagerMoreMenu(context, onSignOut: () async {}),
                child: const Text('More'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: RouteNames.managerDevices,
          builder: (_, _) => const ManagerDeviceApprovalPage(),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          employeeRepositoryProvider.overrideWithValue(
            EmployeeRepository(_DeviceApprovalApi()),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quản lý thiết bị chấm công'));
    await tester.pumpAndSettle();
    expect(find.text('Duyệt thiết bị chấm công'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}

class _DeviceApprovalApi extends ApiClient {
  _DeviceApprovalApi()
    : super(dio: Dio(), storage: const FlutterSecureStorage());

  bool addSecondDevice = false;
  int pendingRequests = 0;

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    if (path != '/api/v1/attendance/devices/pending') {
      throw StateError('Unexpected GET $path');
    }
    pendingRequests++;
    final items = <Map<String, dynamic>>[
      {
        'deviceId': 52,
        'employeeId': 42,
        'employeeName': 'Nguyen Van An',
        'deviceLabel': 'Pixel 8 Emulator',
        'platform': 'ANDROID',
        'status': 'PENDING',
        'requestedAt': '2026-11-04T10:00:00+07:00',
      },
      if (addSecondDevice)
        {
          'deviceId': 53,
          'employeeId': 43,
          'employeeName': 'Le Thi Huong',
          'deviceLabel': 'Samsung Test Device',
          'platform': 'ANDROID',
          'status': 'PENDING',
          'requestedAt': '2026-11-04T10:01:00+07:00',
        },
    ];
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      data: {
        'success': true,
        'data': {'items': items, 'totalElements': items.length},
      },
    );
  }
}
