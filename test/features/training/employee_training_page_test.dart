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
    'training shows courses, skills, certificates and non-blocking progress',
    (tester) async {
      final api = _TrainingApi();
      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();

      expect(find.text('Food safety'), findsOneWidget);
      expect(find.text('Ghi danh'), findsOneWidget);
      expect(find.text('Làm bài trắc nghiệm'), findsNothing);
      expect(find.textContaining('không chặn nhận ca'), findsOneWidget);

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

  testWidgets('employee passes the quiz and training progress refreshes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _TrainingApi();
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).first, const Offset(0, -160));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ghi danh').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Làm bài trắc nghiệm'));
    await tester.pumpAndSettle();

    expect(find.text('Khi bắt đầu ca, nhân viên cần làm gì?'), findsOneWidget);
    await tester.tap(
      find.widgetWithText(
        RadioListTile<String>,
        'A. Kiểm tra lịch ca và nhận bàn giao',
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
          .groupValue,
      'A',
    );
    expect(find.byType(SnackBar), findsNothing);
    final submitButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Nộp bài'),
    );
    expect(submitButton.onPressed, isNotNull);
    await tester.tap(find.widgetWithText(FilledButton, 'Nộp bài'));
    await tester.pumpAndSettle();

    expect(find.text('Bạn đã đạt khóa học'), findsOneWidget);
    expect(find.text('100 điểm · cần 70 điểm'), findsOneWidget);
    expect(api.quizSubmission?['answers'], [
      {'questionId': 501, 'selectedOption': 'A'},
    ]);

    await tester.tap(find.text('Hoàn tất'));
    await tester.pumpAndSettle();

    expect(api.quizGetCalls, 1);
    expect(api.quizSubmitCalls, 1);
    expect(find.text('Đã đạt'), findsWidgets);
    expect(find.text('Làm bài trắc nghiệm'), findsNothing);
  });

  testWidgets('employee enrolls in a practical course for manager review', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _TrainingApi(includeNoTestCourse: true);
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Store opening practical'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Ghi danh').last);
    await tester.pumpAndSettle();

    expect(api.enrollCalls, 1);
    expect(
      find.textContaining('Admin hoặc quản lý sẽ xác nhận'),
      findsOneWidget,
    );
    expect(find.text('Gửi yêu cầu hoàn thành'), findsNothing);
  });
}

Widget _app(_TrainingApi api) => ProviderScope(
  overrides: [
    employeeRepositoryProvider.overrideWithValue(EmployeeRepository(api)),
  ],
  child: const MaterialApp(home: EmployeeTrainingPage()),
);

class _TrainingApi extends ApiClient {
  _TrainingApi({this.includeNoTestCourse = false})
    : super(dio: Dio(), storage: const FlutterSecureStorage());

  final bool includeNoTestCourse;

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
  int quizGetCalls = 0;
  int quizSubmitCalls = 0;
  Map<String, dynamic>? quizSubmission;

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
          if (includeNoTestCourse)
            {
              'courseId': 3,
              'courseCode': 'STORE_OPENING',
              'courseName': 'Store opening practical',
              'description': 'Thực hành quy trình mở cửa hàng.',
              'passScore': 0,
              'validityMonths': 12,
              'isMandatoryTest': false,
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
            'blocksShiftAssignment': false,
            'status': 'NOT_ENROLLED',
            'satisfied': false,
          },
        ];
      case '/api/v1/training/courses/1/quiz':
        quizGetCalls++;
        data = [
          {
            'questionId': 501,
            'questionText': 'Khi bắt đầu ca, nhân viên cần làm gì?',
            'options': [
              {'key': 'A', 'text': 'Kiểm tra lịch ca và nhận bàn giao'},
              {'key': 'B', 'text': 'Tự đổi vị trí làm việc'},
              {'key': 'C', 'text': 'Rời cửa hàng mua đồ'},
              {'key': 'D', 'text': 'Bắt đầu trước khi chấm công'},
            ],
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
    if (path.endsWith('/enroll')) {
      enrollCalls++;
      final courseId = int.parse(path.split('/')[5]);
      final courseName = courseId == 3
          ? 'Store opening practical'
          : 'Food safety';
      mine.add({
        'courseId': courseId,
        'courseName': courseName,
        'status': 'IN_PROGRESS',
      });
      return Response<dynamic>(
        requestOptions: RequestOptions(path: path),
        data: {
          'success': true,
          'data': {'courseId': courseId, 'status': 'IN_PROGRESS'},
        },
      );
    }
    if (path == '/api/v1/training/courses/1/quiz-attempts') {
      quizSubmitCalls++;
      quizSubmission = Map<String, dynamic>.from(data! as Map);
      final training = mine.firstWhere((item) => item['courseId'] == 1);
      training['status'] = 'PASSED';
      training['testScore'] = 100;
      training['completedAt'] = '2031-02-25T10:00:00+07:00';
      return Response<dynamic>(
        requestOptions: RequestOptions(path: path),
        data: {
          'success': true,
          'data': {
            'courseId': 1,
            'courseName': 'Food safety',
            'totalQuestions': 1,
            'correctAnswers': 1,
            'score': 100,
            'passScore': 70,
            'passed': true,
            'attemptNo': 1,
            'trainingStatus': 'PASSED',
            'answers': [
              {
                'questionId': 501,
                'questionText': 'Khi bắt đầu ca, nhân viên cần làm gì?',
                'selectedOption': 'A',
                'correctOption': 'A',
                'correct': true,
              },
            ],
          },
        },
      );
    }
    throw StateError('Unexpected POST $path');
  }
}
