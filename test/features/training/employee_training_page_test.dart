import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_client.dart';
import 'package:hrm_coffee_shop_flutter/data/repositories/employee_providers.dart';
import 'package:hrm_coffee_shop_flutter/data/repositories/employee_repository.dart';
import 'package:hrm_coffee_shop_flutter/features/training/presentation/employee_training_page.dart';

void main() {
  testWidgets(
    'training shows course, skill and certificate views without assessment submission',
    (tester) async {
      final api = _TrainingApi();
      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();

      expect(find.text('Food safety'), findsOneWidget);
      expect(find.text('Ghi danh'), findsOneWidget);
      expect(find.text('Bắt đầu kiểm tra'), findsNothing);

      await tester.tap(find.text('Kỹ năng'));
      await tester.pumpAndSettle();
      expect(find.text('Customer service'), findsOneWidget);
      expect(find.text('Mức 3/5'), findsOneWidget);

      await tester.tap(find.text('Chứng chỉ'));
      await tester.pumpAndSettle();
      expect(find.text('Course passed'), findsOneWidget);
      expect(find.text('Gửi điểm'), findsNothing);
    },
  );

  testWidgets('employee can enroll in a course from the API catalog', (
    tester,
  ) async {
    final api = _TrainingApi();
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).first, const Offset(0, -160));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ghi danh'));
    await tester.pumpAndSettle();

    expect(api.enrollCalls, 1);
    expect(find.text('Food safety'), findsOneWidget);
  });
}

Widget _app(_TrainingApi api) => ProviderScope(
  overrides: [
    employeeRepositoryProvider.overrideWithValue(EmployeeRepository(api)),
  ],
  child: const MaterialApp(home: EmployeeTrainingPage()),
);

class _TrainingApi extends ApiClient {
  _TrainingApi() : super(dio: Dio(), storage: const FlutterSecureStorage());

  final List<Map<String, dynamic>> mine = [
    {
      'courseId': 2,
      'courseName': 'Course passed',
      'status': 'PASSED',
      'completedAt': '2031-02-20T12:00:00+07:00',
      'expiresAt': '2032-02-20T12:00:00+07:00',
      'testScore': 90,
    },
  ];
  int enrollCalls = 0;

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    dynamic data;
    switch (path) {
      case '/api/v1/employees/me':
        data = {'employeeId': 42, 'fullName': 'Nguyen Van An'};
      case '/api/v1/training/courses':
        data = [
          {
            'courseId': 1,
            'courseCode': 'FOOD_SAFE',
            'courseName': 'Food safety',
            'passScore': 70,
            'validityMonths': 12,
            'isMandatoryTest': true,
            'isActive': true,
          },
          {
            'courseId': 2,
            'courseCode': 'SERVICE',
            'courseName': 'Course passed',
            'passScore': 70,
            'validityMonths': 12,
            'isMandatoryTest': true,
            'isActive': true,
          },
        ];
      case '/api/v1/training/me':
        data = mine;
      case '/api/v1/skills':
        data = [
          {
            'skillId': 9,
            'skillCode': 'CUSTOMER_SERVICE',
            'skillName': 'Customer service',
          },
        ];
      case '/api/v1/employees/42/skills':
        data = [
          {
            'skillId': 9,
            'level': 3,
            'assessedAt': '2031-02-25T10:00:00+07:00',
            'note': 'Handles customer questions well',
          },
        ];
      case '/api/v1/employees/42/overview':
        data = {
          'training': {
            'requiredCourses': 1,
            'completedCourses': 0,
            'shiftEligibility': 'RESTRICTED',
            'restrictions': [
              {'courseName': 'Food safety', 'reason': 'NOT_ENROLLED'},
            ],
          },
        };
      case '/api/v1/training/me/requirements':
        data = [
          {
            'courseId': 1,
            'courseName': 'Food safety',
            'blocksShiftAssignment': true,
            'status': 'NOT_ENROLLED',
            'satisfied': false,
          },
        ];
      default:
        throw StateError('Unexpected GET $path');
    }
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      data: {'success': true, 'data': data},
    );
  }

  @override
  Future<Response<dynamic>> post(String path, {Object? data}) async {
    if (path != '/api/v1/training/courses/1/enroll') {
      throw StateError('Unexpected POST $path');
    }
    enrollCalls++;
    mine.add({
      'courseId': 1,
      'courseName': 'Food safety',
      'status': 'IN_PROGRESS',
    });
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      data: {
        'success': true,
        'data': {'courseId': 1, 'status': 'IN_PROGRESS'},
      },
    );
  }
}
