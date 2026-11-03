import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_client.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_exception.dart';
import 'package:hrm_coffee_shop_flutter/data/repositories/employee_providers.dart';
import 'package:hrm_coffee_shop_flutter/data/repositories/employee_repository.dart';
import 'package:hrm_coffee_shop_flutter/features/checklist/data/checklist_providers.dart';
import 'package:hrm_coffee_shop_flutter/features/checklist/data/checklist_repository.dart';
import 'package:hrm_coffee_shop_flutter/features/checklist/presentation/employee_checklist_page.dart';

void main() {
  testWidgets('employee can reopen returned work and submit it to manager', (
    tester,
  ) async {
    final api = _ChecklistApi(initialStatus: 'REJECTED');
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    expect(find.text('Cần làm lại'), findsOneWidget);
    expect(find.text('Vui lòng vệ sinh lại khu vực máy pha.'), findsOneWidget);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(api.startCalls, 1);
    expect(api.completeCalls, 1);
    expect(find.text('Hoàn tất'), findsOneWidget);
    await tester.tap(find.textContaining('Gửi checklist'));
    await tester.pumpAndSettle();
    expect(api.submitCalls, 1);
    expect(find.textContaining('đang chờ quản lý duyệt'), findsOneWidget);
  });

  testWidgets(
    'employee starts a fully completed rejected run before resubmitting',
    (tester) async {
      final api = _ChecklistApi(initialStatus: 'REJECTED', completed: true);
      await tester.pumpWidget(_app(api));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Gửi checklist'));
      await tester.pumpAndSettle();

      expect(api.startCalls, 1);
      expect(api.submitCalls, 1);
      expect(find.textContaining('đang chờ quản lý duyệt'), findsOneWidget);
    },
  );

  testWidgets('checklist blocks submission when required evidence is missing', (
    tester,
  ) async {
    final api = _ChecklistApi(
      initialStatus: 'IN_PROGRESS',
      completed: true,
      requiresEvidence: true,
    );
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Gửi checklist'));
    await tester.pumpAndSettle();
    expect(api.submitCalls, 0);
    expect(find.textContaining('cần ảnh minh chứng'), findsOneWidget);
  });

  testWidgets('unchecked optional checklist items do not block submission', (
    tester,
  ) async {
    final api = _ChecklistApi(
      initialStatus: 'IN_PROGRESS',
      completed: true,
      optionalTask: true,
    );
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    expect(find.text('Wipe the menu board'), findsOneWidget);
    await tester.tap(find.textContaining('Gửi checklist'));
    await tester.pumpAndSettle();

    expect(api.submitCalls, 1);
  });

  testWidgets('employee can switch between every assigned checklist run', (
    tester,
  ) async {
    final api = _ChecklistApi(initialStatus: 'PENDING', twoRuns: true);
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    expect(find.text('Sanitize the espresso station'), findsOneWidget);
    expect(find.text('Closing checklist'), findsOneWidget);
    await tester.tap(find.text('Closing checklist'));
    await tester.pumpAndSettle();

    expect(find.text('Close the front door'), findsOneWidget);
    expect(find.text('Sanitize the espresso station'), findsNothing);
  });
}

Widget _app(_ChecklistApi api) => ProviderScope(
  overrides: [
    employeeRepositoryProvider.overrideWithValue(EmployeeRepository(api)),
    checklistRepositoryProvider.overrideWithValue(ChecklistRepository(api)),
  ],
  child: const MaterialApp(home: EmployeeChecklistPage()),
);

class _ChecklistApi extends ApiClient {
  _ChecklistApi({
    required this.initialStatus,
    this.completed = false,
    this.requiresEvidence = false,
    this.twoRuns = false,
    this.optionalTask = false,
  }) : super(dio: Dio(), storage: const FlutterSecureStorage());

  final String initialStatus;
  final bool completed;
  final bool requiresEvidence;
  final bool twoRuns;
  final bool optionalTask;
  var status = '';
  var itemCompleted = false;
  int startCalls = 0;
  int completeCalls = 0;
  int submitCalls = 0;

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    status = status.isEmpty ? initialStatus : status;
    itemCompleted = itemCompleted || completed;
    if (path == '/api/v1/checklists/me') {
      return _response(path, [_summary(54), if (twoRuns) _summary(55)]);
    }
    final taskId = int.tryParse(path.split('/').last);
    if (taskId == 54 || (taskId == 55 && twoRuns)) {
      return _response(path, _details(taskId!));
    }
    throw StateError('Unexpected GET $path');
  }

  Map<String, dynamic> _summary(int taskId) => {
    'taskId': taskId,
    'checklistName': taskId == 54 ? 'Opening checklist' : 'Closing checklist',
    'dueAt': taskId == 54
        ? '2031-03-01T08:00:00+07:00'
        : '2031-03-01T22:00:00+07:00',
    'status': taskId == 54 ? status : 'PENDING',
  };

  Map<String, dynamic> _details(int taskId) => {
    ..._summary(taskId),
    if (taskId == 54 && initialStatus == 'REJECTED')
      'reviewNote': 'Vui lòng vệ sinh lại khu vực máy pha.',
    'items': taskId == 54
        ? [
            {
              'runItemId': 81,
              'itemName': 'Sanitize the espresso station',
              'isCompleted': itemCompleted,
              'isRequired': true,
              'requiresEvidence': requiresEvidence,
              'hasEvidence': false,
            },
            if (optionalTask)
              {
                'runItemId': 83,
                'itemName': 'Wipe the menu board',
                'isCompleted': false,
                'isRequired': false,
                'requiresEvidence': false,
                'hasEvidence': false,
              },
          ]
        : [
            {
              'runItemId': 82,
              'itemName': 'Close the front door',
              'isCompleted': false,
              'isRequired': true,
              'requiresEvidence': false,
              'hasEvidence': false,
            },
          ],
  };

  @override
  Future<Response<dynamic>> post(String path, {Object? data}) async {
    if (path == '/api/v1/checklists/tasks/54/start') {
      startCalls++;
      status = 'IN_PROGRESS';
      return _response(path, {'taskId': 54, 'status': status});
    }
    if (path == '/api/v1/checklists/tasks/54/items/81/complete') {
      completeCalls++;
      itemCompleted = true;
      status = 'IN_PROGRESS';
      return _response(path, {'taskId': 54, 'status': status});
    }
    if (path == '/api/v1/checklists/tasks/54/submit') {
      submitCalls++;
      if (!['IN_PROGRESS', 'OVERDUE'].contains(status)) {
        throw const ApiException(
          message: 'Checklist không ở trạng thái đang thực hiện',
        );
      }
      status = 'SUBMITTED';
      return _response(path, {'taskId': 54, 'status': status});
    }
    throw StateError('Unexpected POST $path');
  }

  Response<dynamic> _response(String path, Object data) => Response<dynamic>(
    requestOptions: RequestOptions(path: path),
    data: {'success': true, 'data': data},
  );
}
