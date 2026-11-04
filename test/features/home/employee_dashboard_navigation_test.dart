import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hrm_coffee_shop_flutter/app/router/app_router.dart';
import 'package:hrm_coffee_shop_flutter/app/router/route_names.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_client.dart';
import 'package:hrm_coffee_shop_flutter/data/repositories/employee_providers.dart';
import 'package:hrm_coffee_shop_flutter/data/repositories/employee_repository.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/data/auth_providers.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/data/auth_repository.dart';
import 'package:hrm_coffee_shop_flutter/features/home/presentation/employee_dashboard_page.dart';

void main() {
  testWidgets('employee dashboard opens every employee workflow', (
    tester,
  ) async {
    final api = _EmployeeApi();
    final destinations = <String, String>{
      'Lịch làm việc': RouteNames.employeeSchedule,
      'Checklist': RouteNames.employeeChecklist,
      'Đào tạo': RouteNames.employeeTraining,
      'Hồ sơ': RouteNames.employeeProfile,
      'Thông báo': RouteNames.employeeNotifications,
      'Lịch sử công': RouteNames.employeeAttendanceHistory,
      'Hồ sơ giấy tờ': RouteNames.employeeDocuments,
      'Vi phạm': RouteNames.employeeViolations,
      'Thưởng / phạt': RouteNames.employeeRewards,
    };
    final routes = <GoRoute>[
      GoRoute(
        path: '/employee',
        builder: (_, __) => const EmployeeDashboardPage(),
      ),
      for (final path in destinations.values)
        GoRoute(path: path, builder: (_, __) => Text('Destination $path')),
      GoRoute(
        path: RouteNames.checkIn,
        builder: (_, __) => const Text('Destination check-in'),
      ),
    ];
    final router = GoRouter(initialLocation: '/employee', routes: routes);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          employeeRepositoryProvider.overrideWithValue(EmployeeRepository(api)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nguyen Van An'), findsOneWidget);
    expect(find.text('Đang làm việc'), findsOneWidget);
    expect(find.text('Tình trạng hồ sơ: Đã hoàn thiện'), findsOneWidget);
    expect(
      find.text('Điều kiện nhận ca: Đủ điều kiện nhận ca'),
      findsOneWidget,
    );
    expect(find.text('Duyệt hồ sơ'), findsNothing);
    for (final entry in destinations.entries) {
      final tile = find.text(entry.key);
      final scrollable = find.byType(ListView).first;
      for (
        var attempt = 0;
        attempt < 8 && tile.hitTestable().evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(scrollable, const Offset(0, -160));
        await tester.pumpAndSettle();
      }
      expect(
        tile.hitTestable(),
        findsOneWidget,
        reason: 'Quick link is not reachable: ${entry.key}',
      );
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.text('Destination ${entry.value}'), findsOneWidget);
      router.go('/employee');
      await tester.pumpAndSettle();
    }

    final checkIn = find.text('Check-in').first;
    final checkInButton = find.widgetWithText(FilledButton, 'Check-in').first;
    expect(checkInButton.hitTestable(), findsOneWidget);
    expect(tester.widget<FilledButton>(checkInButton).onPressed, isNotNull);
    final scrollable = find.byType(ListView).first;
    for (
      var attempt = 0;
      attempt < 8 && checkIn.hitTestable().evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(scrollable, const Offset(0, 160));
      await tester.pumpAndSettle();
    }
    await tester.tap(checkIn);
    await tester.pumpAndSettle();
    expect(find.text('Destination check-in'), findsOneWidget);
  });

  testWidgets('employee dashboard exposes document review to an HR employee', (
    tester,
  ) async {
    final api = _EmployeeApi(documentReviewer: true);
    final router = GoRouter(
      initialLocation: '/employee',
      routes: [
        GoRoute(
          path: '/employee',
          builder: (_, __) => const EmployeeDashboardPage(),
        ),
        GoRoute(
          path: RouteNames.managerDocumentReview,
          builder: (_, __) => const Text('Document review destination'),
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

    final reviewLink = find.text('Duyệt hồ sơ');
    final scrollable = find.byType(ListView).first;
    for (
      var attempt = 0;
      attempt < 8 && reviewLink.hitTestable().evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(scrollable, const Offset(0, -180));
      await tester.pumpAndSettle();
    }
    await tester.tap(reviewLink);
    await tester.pumpAndSettle();

    expect(api.permissionRequests, 1);
    expect(find.text('Document review destination'), findsOneWidget);
  });

  testWidgets('legacy profile route opens the shared account profile', (
    tester,
  ) async {
    final router = appRouter;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          employeeRepositoryProvider.overrideWithValue(
            EmployeeRepository(_EmployeeApi()),
          ),
          authRepositoryProvider.overrideWithValue(
            AuthRepository(_EmployeeApi()),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.go(RouteNames.profile);
    await tester.pumpAndSettle();

    expect(find.text('Profile - Đang phát triển'), findsNothing);
    expect(find.text('Thông tin tài khoản'), findsOneWidget);
    expect(find.text('Nguyen Van An'), findsOneWidget);
  });
}

class _EmployeeApi extends ApiClient {
  _EmployeeApi({this.documentReviewer = false})
    : super(dio: Dio(), storage: const FlutterSecureStorage());

  final bool documentReviewer;
  int permissionRequests = 0;

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    dynamic data;
    switch (path) {
      case '/api/v1/users/me':
        data = {
          'userId': 12,
          'email': 'an@example.test',
          'displayName': 'Nguyen Van An',
          'phoneNumber': '0900000001',
          'roles': ['EMPLOYEE'],
          'employeeId': 42,
          'status': 'ACTIVE',
        };
      case '/api/v1/employees/me':
        data = {
          'fullName': 'Nguyen Van An',
          'employeeCode': 'NV001',
          'jobTitle': 'Barista',
          'employmentStatus': 'ACTIVE',
          'email': 'an@example.test',
          'phone': '0900000001',
          'employmentType': 'FULL_TIME',
          'profileStatus': 'COMPLETE',
          'shiftEligibility': 'ELIGIBLE',
        };
      case '/api/v1/dashboard/employee/overview':
        data = {
          'openChecklists': 1,
          'unreadNotifications': 2,
          'profileStatus': 'COMPLETE',
          'shiftEligibility': 'ELIGIBLE',
        };
      case '/api/v1/attendance/me/current':
        data = {
          'plannedStartAt': '2031-03-01T08:00:00+07:00',
          'plannedEndAt': '2031-03-01T16:00:00+07:00',
          'shiftName': 'Ca sáng',
          'attendanceStatus': 'CHƯA CHECK-IN',
          'canCheckIn': false,
          'canCheckOut': false,
          'deviceActive': false,
          'blockers': ['DEVICE_NOT_ACTIVE'],
        };
      case '/api/v1/users/me/permissions':
        permissionRequests++;
        data = {
          'roles': ['EMPLOYEE'],
          'permissions': documentReviewer ? ['DOCUMENT_REVIEW'] : <String>[],
        };
      default:
        throw StateError('Unexpected GET $path');
    }
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      data: {'success': true, 'data': data},
    );
  }
}
