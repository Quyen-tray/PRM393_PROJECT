import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_client.dart';
import 'package:hrm_coffee_shop_flutter/data/repositories/employee_providers.dart';
import 'package:hrm_coffee_shop_flutter/data/repositories/employee_repository.dart';
import 'package:hrm_coffee_shop_flutter/features/training/presentation/manager_training_completion_review_page.dart';

void main() {
  testWidgets('manager approves an employee practical completion', (
    tester,
  ) async {
    final api = _CompletionReviewApi();
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    expect(find.text('Store opening practical'), findsOneWidget);
    expect(find.text('Ghi danh: 01/03/2031'), findsOneWidget);
    await tester.tap(find.text('Xác nhận hoàn thành'));
    await tester.pumpAndSettle();

    expect(api.approveCalls, 1);
    expect(
      find.text('Không có khóa học thực hành cần xác nhận.'),
      findsOneWidget,
    );
  });

  testWidgets('manager can record that a practical course is not complete', (
    tester,
  ) async {
    final api = _CompletionReviewApi();
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Chưa hoàn thành'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'Thực hành lại bước kiểm tra nhiệt độ',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Ghi nhận'));
    await tester.pumpAndSettle();

    expect(api.rejectCalls, 1);
    expect(api.rejectReason, 'Thực hành lại bước kiểm tra nhiệt độ');
    expect(find.text('Store opening practical'), findsOneWidget);
    expect(
      find.text('Lần xác nhận trước: Thực hành lại bước kiểm tra nhiệt độ'),
      findsOneWidget,
    );
  });
}

Widget _app(_CompletionReviewApi api) => ProviderScope(
  overrides: [
    employeeRepositoryProvider.overrideWithValue(EmployeeRepository(api)),
  ],
  child: const MaterialApp(home: ManagerTrainingCompletionReviewPage()),
);

class _CompletionReviewApi extends ApiClient {
  _CompletionReviewApi()
    : super(dio: Dio(), storage: const FlutterSecureStorage());

  bool pending = true;
  int approveCalls = 0;
  int rejectCalls = 0;
  String? rejectReason;
  String? reviewNote;

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    if (path != '/api/v1/training/completion-reviews/pending') {
      throw StateError('Unexpected GET $path');
    }
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      data: {
        'success': true,
        'data': pending
            ? [
                {
                  'employeeTrainingId': 900,
                  'employeeId': 42,
                  'employeeCode': 'EMP-42',
                  'employeeName': 'Nguyen Van An',
                  'courseId': 3,
                  'courseName': 'Store opening practical',
                  'enrolledAt': '2031-03-01T10:30:00+07:00',
                  if (reviewNote != null) 'reviewNote': reviewNote,
                },
              ]
            : [],
      },
    );
  }

  @override
  Future<Response<dynamic>> post(String path, {Object? data}) async {
    if (path.endsWith('/900/approve')) {
      approveCalls++;
    } else if (path.endsWith('/900/not-complete')) {
      rejectCalls++;
      rejectReason = (data as Map)['reason']?.toString();
      reviewNote = rejectReason;
    } else {
      throw StateError('Unexpected POST $path');
    }
    if (path.endsWith('/approve')) pending = false;
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      data: {
        'success': true,
        'data': {
          'status': path.endsWith('/approve') ? 'PASSED' : 'IN_PROGRESS',
          'completionReviewNote': rejectReason,
        },
      },
    );
  }
}
