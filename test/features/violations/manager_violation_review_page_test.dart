import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_client.dart';
import 'package:hrm_coffee_shop_flutter/data/repositories/employee_providers.dart';
import 'package:hrm_coffee_shop_flutter/data/repositories/employee_repository.dart';
import 'package:hrm_coffee_shop_flutter/features/violations/presentation/manager_violation_review_page.dart';

void main() {
  testWidgets(
    'manager confirmation keeps its note and refreshes the violation',
    (tester) async {
      final api = _ManagerViolationApi(initialStatus: 'OPEN');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            employeeRepositoryProvider.overrideWithValue(
              EmployeeRepository(api),
            ),
          ],
          child: const MaterialApp(home: ManagerViolationReviewPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Xác nhận').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Reviewed by manager');
      await tester.tap(find.text('Xác nhận').last);
      await tester.pumpAndSettle();

      expect(api.confirmBody, {'note': 'Reviewed by manager'});
      expect(api.currentStatus, 'CONFIRMED');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('manager sees employee explanation separately from review note', (
    tester,
  ) async {
    final api = _ManagerViolationApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          employeeRepositoryProvider.overrideWithValue(EmployeeRepository(api)),
        ],
        child: const MaterialApp(home: ManagerViolationReviewPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Ghi chú: Check camera'), findsOneWidget);
    expect(find.text('Employee explains context here.'), findsNothing);
    await tester.tap(find.text('Giải trình của nhân viên'));
    await tester.pumpAndSettle();

    expect(api.explanationCalls, 1);
    expect(find.text('Employee explains context here.'), findsOneWidget);
    expect(find.textContaining('Ghi chú: Check camera'), findsOneWidget);
    expect(find.text('Xác nhận'), findsNothing);
  });
}

class _ManagerViolationApi extends ApiClient {
  _ManagerViolationApi({String initialStatus = 'CONFIRMED'})
    : currentStatus = initialStatus,
      super(dio: Dio(), storage: const FlutterSecureStorage());

  int explanationCalls = 0;
  String currentStatus;
  Map<String, dynamic>? confirmBody;

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    dynamic data;
    if (path == '/api/v1/users/me/permissions') {
      data = {
        'roles': ['STORE_MANAGER'],
        'permissions': [
          'VIOLATION_REVIEW',
          'REWARD_APPROVE',
          'REWARD_APPROVE_CRITICAL',
        ],
      };
    } else if (path == '/api/v1/violations') {
      data = {
        'items': [
          {
            'violationId': 77,
            'employeeId': 42,
            'employeeName': 'Nguyen Van An',
            'ruleName': 'Checklist incomplete',
            'severity': 'MINOR',
            'status': currentStatus,
            'details': 'Area was left untidy.',
            'reviewNote': 'Check camera',
            'incidentAt': '2031-03-01T10:00:00+07:00',
          },
        ],
        'page': 0,
        'totalPages': 1,
        'totalElements': 1,
      };
    } else if (path == '/api/v1/violations/77/explanations') {
      explanationCalls++;
      data = [
        {
          'explanationId': 900,
          'violationId': 77,
          'explanation': 'Employee explains context here.',
          'submittedAt': '2031-03-01T11:00:00+07:00',
        },
      ];
    } else {
      throw StateError('Unexpected GET $path');
    }
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      data: {'success': true, 'data': data},
    );
  }

  @override
  Future<Response<dynamic>> post(String path, {Object? data}) async {
    if (path != '/api/v1/violations/77/confirm') {
      throw StateError('Unexpected POST $path');
    }
    confirmBody = Map<String, dynamic>.from(data! as Map);
    currentStatus = 'CONFIRMED';
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      data: {
        'success': true,
        'data': {'violationId': 77, 'status': currentStatus},
      },
    );
  }
}
