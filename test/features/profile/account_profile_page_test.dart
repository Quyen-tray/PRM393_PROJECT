import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_client.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/data/auth_providers.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/data/auth_repository.dart';
import 'package:hrm_coffee_shop_flutter/data/repositories/employee_providers.dart';
import 'package:hrm_coffee_shop_flutter/data/repositories/employee_repository.dart';
import 'package:hrm_coffee_shop_flutter/features/profile/presentation/account_profile_page.dart';

void main() {
  testWidgets('profile shows personal and position details from the API', (
    tester,
  ) async {
    final api = _ProfileApi();
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    expect(find.text('Nguyễn Văn An'), findsOneWidget);
    expect(find.text('NV001'), findsOneWidget);
    expect(find.text('Nhân viên phục vụ'), findsNWidgets(2));
    expect(find.text('an@example.test'), findsOneWidget);
    expect(find.text('0901000000'), findsOneWidget);
    expect(find.text('Đang làm việc'), findsNWidgets(2));
    expect(find.text('Toàn thời gian'), findsOneWidget);
    expect(find.text('Đã hoàn thiện'), findsOneWidget);
    expect(find.text('Đủ điều kiện nhận ca'), findsOneWidget);

    await tester.tap(find.text('Chức danh'));
    await tester.pumpAndSettle();
    expect(find.text('Mã chức danh'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('linked employee edits the shared account record', (
    tester,
  ) async {
    final api = _ProfileApi();
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Chỉnh sửa thông tin'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Chỉnh sửa thông tin'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'Nguyễn An');
    await tester.enterText(find.byType(TextField).at(1), '0902222333');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(api.patchPath, '/api/v1/users/me');
    expect(api.patchBody, {
      'displayName': 'Nguyễn An',
      'phoneNumber': '0902222333',
    });
    expect(find.text('Nguyễn An'), findsOneWidget);
    expect(find.text('Đã cập nhật hồ sơ.'), findsOneWidget);
  });

  testWidgets('account without employee link can open and edit profile', (
    tester,
  ) async {
    final api = _ProfileApi(linkedEmployee: false);
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    expect(find.text('Quản trị hệ thống'), findsOneWidget);
    expect(find.text('an@example.test'), findsOneWidget);
    expect(find.text('Chức danh'), findsNothing);
    expect(api.employeeProfileCalls, 0);

    await tester.tap(find.text('Chỉnh sửa thông tin'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Nguyễn An');
    await tester.enterText(find.byType(TextField).at(1), '0902222333');
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();

    expect(api.patchPath, '/api/v1/users/me');
    expect(find.text('Nguyễn An'), findsOneWidget);
  });
}

Widget _app(_ProfileApi api) => ProviderScope(
  overrides: [
    employeeRepositoryProvider.overrideWithValue(EmployeeRepository(api)),
    authRepositoryProvider.overrideWithValue(AuthRepository(api)),
  ],
  child: const MaterialApp(home: AccountProfilePage()),
);

class _ProfileApi extends ApiClient {
  _ProfileApi({this.linkedEmployee = true})
    : super(dio: Dio(), storage: const FlutterSecureStorage());

  final bool linkedEmployee;
  int employeeProfileCalls = 0;
  final Map<String, dynamic> account = {
    'userId': 9,
    'email': 'an@example.test',
    'displayName': 'Nguyễn Văn An',
    'phoneNumber': '0901000000',
    'roles': ['SYSTEM_ADMIN'],
    'employeeId': 42,
    'status': 'ACTIVE',
  };

  final Map<String, dynamic> employee = {
    'employeeId': 42,
    'employeeCode': 'NV001',
    'fullName': 'Nguyễn Văn An',
    'email': 'an@example.test',
    'phone': '0901000000',
    'hireDate': '2026-01-01',
    'jobTitle': 'Nhân viên phục vụ',
    'positionId': 5,
    'employmentType': 'FULL_TIME',
    'employmentStatus': 'ACTIVE',
    'profileStatus': 'COMPLETE',
    'shiftEligibility': 'ELIGIBLE',
  };
  String? patchPath;
  Object? patchBody;

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    if (path != '/api/v1/employees/me') {
      if (path == '/api/v1/users/me') {
        return Response<dynamic>(
          requestOptions: RequestOptions(path: path),
          data: {
            'success': true,
            'data': {
              ...account,
              'roles': linkedEmployee ? ['EMPLOYEE'] : ['SYSTEM_ADMIN'],
              if (!linkedEmployee) 'employeeId': null,
            },
          },
        );
      }
      throw StateError('Unexpected GET $path');
    }
    employeeProfileCalls++;
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      data: {'success': true, 'data': employee},
    );
  }

  @override
  Future<Response<dynamic>> patch(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    patchPath = path;
    patchBody = data;
    final body = Map<String, dynamic>.from(data! as Map);
    account['displayName'] = body['displayName'];
    account['phoneNumber'] = body['phoneNumber'];
    employee['fullName'] = body['displayName'];
    employee['phone'] = body['phoneNumber'];
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      data: {'success': true, 'data': account},
    );
  }
}
