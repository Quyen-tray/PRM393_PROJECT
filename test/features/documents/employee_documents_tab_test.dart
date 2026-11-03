import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_client.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_exception.dart';
import 'package:hrm_coffee_shop_flutter/data/repositories/employee_providers.dart';
import 'package:hrm_coffee_shop_flutter/data/repositories/employee_repository.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/data/auth_providers.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/data/auth_repository.dart';
import 'package:hrm_coffee_shop_flutter/features/documents/presentation/employee_documents_tab.dart';
import 'package:hrm_coffee_shop_flutter/features/profile/presentation/account_profile_page.dart';

void main() {
  testWidgets(
    'profile documents tab shows required optional and persisted statuses',
    (tester) async {
      final api = _DocumentApiClient();
      await tester.pumpWidget(_profileApp(api));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hồ sơ'));
      await tester.pumpAndSettle();

      expect(find.text('Thẻ căn cước'), findsOneWidget);
      expect(find.text('Bắt buộc'), findsOneWidget);
      expect(find.text('Đã duyệt'), findsOneWidget);
      expect(find.text('Chứng chỉ sơ cứu'), findsNWidgets(2));
      expect(find.text('Tùy chọn'), findsOneWidget);
      expect(find.text('Bị từ chối'), findsNWidgets(2));
      expect(find.textContaining('private-documents/'), findsNothing);
    },
  );

  testWidgets(
    'picker cancellation leaves document status unchanged and uploads nothing',
    (tester) async {
      final api = _DocumentApiClient();
      final picker = _CancelingDocumentPicker();
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_profileApp(api, initialTab: 2, picker: picker));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Nộp hồ sơ').last);
      await tester.tap(find.text('Nộp hồ sơ').last);
      await tester.pumpAndSettle();

      expect(find.text('Bị từ chối'), findsNWidgets(2));
      expect(picker.calls, 1);
      expect(api.uploadCalls, 0);
      expect(api.documentSubmissionCalls, 0);
    },
  );

  testWidgets(
    'document submission uploads and shows the server outcome without exposing its key',
    (tester) async {
      final api = _DocumentApiClient();
      final picker = _StaticDocumentPicker();
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_profileApp(api, initialTab: 2, picker: picker));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Nộp hồ sơ').last);
      await tester.tap(find.text('Nộp hồ sơ').last);
      await tester.pumpAndSettle();

      expect(picker.calls, 1);
      expect(api.uploadCalls, 1);
      expect(api.uploadPath, '/api/v1/storage/uploads?purpose=DOCUMENT');
      expect(api.uploadContentType, 'application/pdf');
      expect(api.documentSubmissionCalls, 1);
      expect(api.lastPostData, {
        'documentTypeId': 2,
        'storageKey': 'private-documents/employee-42/picked.pdf',
      });
      expect(find.text('Đang chờ duyệt'), findsWidgets);
      // The old rejection reason stays with the old history row, but must not
      // be repeated on the newer pending catalog card.
      expect(find.text('Lý do từ chối: Ảnh chưa rõ.'), findsOneWidget);
      expect(find.textContaining('private-documents/'), findsNothing);
    },
  );

  testWidgets(
    'documents tab retries catalog failure and renders the saved result',
    (tester) async {
      final api = _DocumentApiClient(failFirstCatalogRequest: true);
      await tester.pumpWidget(_profileApp(api));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hồ sơ'));
      await tester.pumpAndSettle();

      expect(find.text('Thử lại'), findsOneWidget);
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      expect(find.text('Thẻ căn cước'), findsOneWidget);
    },
  );
}

Widget _profileApp(
  _DocumentApiClient api, {
  int initialTab = 0,
  DocumentPicker? picker,
}) => ProviderScope(
  overrides: [
    employeeRepositoryProvider.overrideWithValue(EmployeeRepository(api)),
    authRepositoryProvider.overrideWithValue(AuthRepository(api)),
  ],
  child: MaterialApp(
    home: AccountProfilePage(initialTab: initialTab, documentPicker: picker),
  ),
);

class _CancelingDocumentPicker implements DocumentPicker {
  var calls = 0;

  @override
  Future<PickedDocument?> pickDocument() async {
    calls++;
    return null;
  }
}

class _StaticDocumentPicker implements DocumentPicker {
  var calls = 0;

  @override
  Future<PickedDocument?> pickDocument() async {
    calls++;
    return PickedDocument(
      name: 'first-aid.pdf',
      contentType: 'application/pdf',
      bytes: Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
    );
  }
}

class _DocumentApiClient extends ApiClient {
  _DocumentApiClient({this.failFirstCatalogRequest = false})
    : super(dio: Dio(), storage: const FlutterSecureStorage());

  final bool failFirstCatalogRequest;
  var catalogRequests = 0;
  var uploadCalls = 0;
  var documentSubmissionCalls = 0;
  String? uploadPath;
  String? uploadContentType;
  Object? lastPostData;
  bool submitted = false;

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    dynamic data;
    if (path == '/api/v1/users/me') {
      data = {
        'userId': 9,
        'email': 'an@example.test',
        'displayName': 'Nguyễn Văn An',
        'phoneNumber': '0901000000',
        'roles': ['EMPLOYEE'],
        'employeeId': 42,
        'status': 'ACTIVE',
      };
    } else if (path == '/api/v1/employees/me') {
      data = {
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
        'profileStatus': 'INCOMPLETE',
        'shiftEligibility': 'ELIGIBLE',
      };
    } else if (path == '/api/v1/training/me') {
      data = <Map<String, dynamic>>[];
    } else if (path == '/api/v1/employees/me/documents/catalog') {
      catalogRequests++;
      if (failFirstCatalogRequest && catalogRequests == 1) {
        throw const ApiException(message: 'Mất kết nối tạm thời.');
      }
      data = {
        'positionId': 5,
        'asOfDate': '2026-11-03',
        'documents': [
          {
            'documentTypeId': 1,
            'documentCode': 'CITIZEN_ID',
            'documentName': 'Thẻ căn cước',
            'isActive': true,
            'required': true,
            'latestStatus': 'APPROVED',
            'canSubmit': false,
            'blockReason': 'Hồ sơ còn hiệu lực.',
          },
          {
            'documentTypeId': 2,
            'documentCode': 'FIRST_AID',
            'documentName': 'Chứng chỉ sơ cứu',
            'isActive': true,
            'required': false,
            'latestStatus': submitted ? 'PENDING' : 'REJECTED',
            'canSubmit': !submitted,
            'blockReason': null,
          },
        ],
      };
    } else if (path == '/api/v1/employees/me/documents') {
      data = [
        {
          'documentId': 101,
          'documentType': {
            'documentTypeId': 2,
            'documentCode': 'FIRST_AID',
            'documentName': 'Chứng chỉ sơ cứu',
            'isActive': true,
          },
          'fileName': 'first-aid.pdf',
          'reviewStatus': 'REJECTED',
          'rejectionReason': 'Ảnh chưa rõ.',
          'expiresAt': null,
          'uploadedAt': '2026-11-01T10:00:00+07:00',
        },
        if (submitted)
          {
            'documentId': 102,
            'documentType': {
              'documentTypeId': 2,
              'documentCode': 'FIRST_AID',
              'documentName': 'Chứng chỉ sơ cứu',
              'isActive': true,
            },
            'fileName': 'first-aid.pdf',
            'reviewStatus': 'PENDING',
            'rejectionReason': null,
            'uploadedAt': '2026-11-03T10:00:00+07:00',
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
  Future<Response<dynamic>> uploadBytes(
    String path, {
    required List<int> bytes,
    required String contentType,
  }) async {
    uploadCalls++;
    uploadPath = path;
    uploadContentType = contentType;
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      data: {
        'success': true,
        'data': {'storageKey': 'private-documents/employee-42/picked.pdf'},
      },
    );
  }

  @override
  Future<Response<dynamic>> post(String path, {Object? data}) async {
    if (path == '/api/v1/employees/me/documents') {
      documentSubmissionCalls++;
      lastPostData = data;
      submitted = true;
    }
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      data: {
        'success': true,
        'data': {
          'documentId': 102,
          'employeeId': 42,
          'reviewStatus': 'PENDING',
        },
      },
    );
  }
}
