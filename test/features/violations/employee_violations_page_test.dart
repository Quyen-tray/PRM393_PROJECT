import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_client.dart';
import 'package:hrm_coffee_shop_flutter/data/repositories/employee_providers.dart';
import 'package:hrm_coffee_shop_flutter/data/repositories/employee_repository.dart';
import 'package:hrm_coffee_shop_flutter/features/documents/presentation/employee_documents_tab.dart';
import 'package:hrm_coffee_shop_flutter/features/violations/presentation/employee_violations_page.dart';

void main() {
  testWidgets('employee appends an explanation and optional private evidence', (
    tester,
  ) async {
    final api = _ViolationsApi();
    await tester.pumpWidget(_app(api, picker: _EvidencePicker()));
    await tester.pumpAndSettle();

    expect(find.text('Kiểm tra vệ sinh quầy'), findsOneWidget);
    expect(
      find.byKey(const Key('violation-explanation-field-77')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('violation-explanation-field-88')),
      findsNothing,
    );

    await tester.tap(find.text('Lịch sử giải trình').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('attach-violation-evidence-77')));
    await tester.pumpAndSettle();
    expect(find.text('evidence.png'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('violation-explanation-field-77')),
      'I completed the task before close.',
    );
    await tester.tap(find.byKey(const Key('submit-violation-explanation-77')));
    await tester.pumpAndSettle();

    expect(api.uploadPath, '/api/v1/storage/uploads?purpose=DOCUMENT');
    expect(api.uploadedContentType, 'image/png');
    expect(api.lastPostPath, '/api/v1/employees/me/violations/77/explanations');
    expect(api.lastPostData, {
      'explanation': 'I completed the task before close.',
      'evidenceStorageKey': 'private-documents/employee-42/evidence.png',
    });
    expect(find.text('I completed the task before close.'), findsOneWidget);
    expect(
      find.text('private-documents/employee-42/evidence.png'),
      findsNothing,
    );
    expect(api.violationStatus, 'OPEN');
  });

  testWidgets('closed violations show history without a submission form', (
    tester,
  ) async {
    final api = _ViolationsApi();
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    expect(find.text('Đã xác nhận'), findsOneWidget);
    expect(
      find.byKey(const Key('violation-explanation-field-88')),
      findsNothing,
    );
    expect(
      find.text('Bạn không thể gửi thêm giải trình cho vi phạm đã xử lý.'),
      findsOneWidget,
    );
  });

  testWidgets('employee can retry after violations fail to load', (
    tester,
  ) async {
    final api = _ViolationsApi(failFirstListRequest: true);
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    expect(find.text('Thử lại'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Kiểm tra vệ sinh quầy'), findsOneWidget);
    expect(api.violationListCalls, 2);
  });
}

Widget _app(_ViolationsApi api, {DocumentPicker? picker}) => ProviderScope(
  overrides: [
    employeeRepositoryProvider.overrideWithValue(EmployeeRepository(api)),
  ],
  child: MaterialApp(
    home: picker == null
        ? const EmployeeViolationsPage()
        : EmployeeViolationsPage(picker: picker),
  ),
);

class _EvidencePicker implements DocumentPicker {
  @override
  Future<PickedDocument?> pickDocument() async => PickedDocument(
    name: 'evidence.png',
    contentType: 'image/png',
    bytes: Uint8List.fromList([1, 2, 3]),
  );
}

class _ViolationsApi extends ApiClient {
  _ViolationsApi({this.failFirstListRequest = false})
    : super(dio: Dio(), storage: const FlutterSecureStorage());

  final bool failFirstListRequest;
  int violationListCalls = 0;
  String? uploadPath;
  String? uploadedContentType;
  String? lastPostPath;
  Object? lastPostData;
  String violationStatus = 'OPEN';
  final List<Map<String, dynamic>> explanations = [];

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    if (path == '/api/v1/employees/me/violations') {
      violationListCalls++;
      if (failFirstListRequest && violationListCalls == 1) {
        throw StateError('temporary failure');
      }
      return _response(path, {
        'items': [
          {
            'violationId': 77,
            'employeeId': 42,
            'ruleName': 'Kiểm tra vệ sinh quầy',
            'details': 'Khu vực chưa được vệ sinh đúng checklist.',
            'status': violationStatus,
            'incidentAt': '2031-03-01T10:00:00+07:00',
            'severity': 'MINOR',
          },
          {
            'violationId': 88,
            'employeeId': 42,
            'ruleName': 'Thiếu ảnh checklist',
            'status': 'CONFIRMED',
            'details': 'Thiếu ảnh minh chứng.',
            'incidentAt': '2031-02-20T10:00:00+07:00',
            'severity': 'MAJOR',
            'reviewNote': 'Đã kiểm tra.',
          },
        ],
        'page': 0,
        'totalPages': 1,
        'totalElements': 2,
      });
    }
    if (path == '/api/v1/employees/me/violations/77/explanations') {
      return _response(path, explanations);
    }
    if (path == '/api/v1/employees/me/violations/88/explanations') {
      return _response(path, [
        {
          'explanationId': 801,
          'violationId': 88,
          'explanation': 'I already explained this case.',
          'submittedAt': '2031-02-20T11:00:00+07:00',
        },
      ]);
    }
    throw StateError('Unexpected GET $path');
  }

  @override
  Future<Response<dynamic>> post(String path, {Object? data}) async {
    lastPostPath = path;
    lastPostData = data;
    final body = Map<String, dynamic>.from(data! as Map);
    explanations.add({
      'explanationId': 901,
      'violationId': 77,
      'explanation': body['explanation'],
      'submittedAt': '2031-03-01T12:00:00+07:00',
      'evidenceViewUrl': body['evidenceStorageKey'] == null
          ? null
          : 'https://example.test/evidence',
    });
    return _response(path, explanations.last);
  }

  @override
  Future<Response<dynamic>> uploadBytes(
    String path, {
    required List<int> bytes,
    required String contentType,
  }) async {
    uploadPath = path;
    uploadedContentType = contentType;
    return _response(path, {
      'storageKey': 'private-documents/employee-42/evidence.png',
    });
  }

  Response<dynamic> _response(String path, Object data) => Response<dynamic>(
    requestOptions: RequestOptions(path: path),
    data: {'success': true, 'data': data},
  );
}
