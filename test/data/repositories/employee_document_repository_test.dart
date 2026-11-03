import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_client.dart';
import 'package:hrm_coffee_shop_flutter/data/repositories/employee_repository.dart';

void main() {
  test(
    'employeeRepositoryUsesSelfViolationEndpointsAndKeepsEvidenceKeyOptional',
    () async {
      final api = _RecordingApiClient();
      final dynamic repository = EmployeeRepository(api);

      await repository.getMyViolations();
      expect(api.lastGetPath, '/api/v1/employees/me/violations');
      await repository.getMyViolationExplanations(77);
      expect(
        api.lastGetPath,
        '/api/v1/employees/me/violations/77/explanations',
      );

      await repository.submitViolationExplanation(
        77,
        explanation: 'I completed the task before close.',
        evidenceStorageKey: 'private-documents/employee-42/evidence.png',
      );
      expect(
        api.lastPostPath,
        '/api/v1/employees/me/violations/77/explanations',
      );
      expect(api.lastPostData, {
        'explanation': 'I completed the task before close.',
        'evidenceStorageKey': 'private-documents/employee-42/evidence.png',
      });

      await repository.getViolationExplanationsForReview(77);
      expect(api.lastGetPath, '/api/v1/violations/77/explanations');
    },
  );

  test(
    'employeeRepositorySendsDocumentBytesAsDocumentPurposeAndSubmitsReturnedKey',
    () async {
      final api = _RecordingApiClient();
      final dynamic repository = EmployeeRepository(api);
      final bytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46]);
      String? storageKey;
      Object? missingUploadMethod;
      try {
        storageKey =
            await repository.uploadDocument(
                  bytes: bytes,
                  contentType: 'application/pdf',
                )
                as String;
      } on NoSuchMethodError catch (error) {
        missingUploadMethod = error;
      }

      expect(
        missingUploadMethod,
        isNull,
        reason: 'EmployeeRepository must expose uploadDocument',
      );
      expect(storageKey, 'private-documents/employee-42/file.pdf');
      expect(api.uploadPath, '/api/v1/storage/uploads?purpose=DOCUMENT');
      expect(api.uploadedBytes, bytes);
      expect(api.uploadContentType, 'application/pdf');

      Object? missingSubmitMethod;
      try {
        await repository.submitDocument(
          documentTypeId: 9,
          storageKey: storageKey!,
        );
      } on NoSuchMethodError catch (error) {
        missingSubmitMethod = error;
      }
      expect(
        missingSubmitMethod,
        isNull,
        reason: 'EmployeeRepository must expose submitDocument',
      );
      expect(api.lastPostPath, '/api/v1/employees/me/documents');
      expect(api.lastPostData, {
        'documentTypeId': 9,
        'storageKey': 'private-documents/employee-42/file.pdf',
      });
    },
  );
}

class _RecordingApiClient extends ApiClient {
  _RecordingApiClient()
    : super(dio: Dio(), storage: const FlutterSecureStorage());

  String? uploadPath;
  Uint8List? uploadedBytes;
  String? uploadContentType;
  String? lastPostPath;
  Object? lastPostData;
  String? lastGetPath;

  @override
  Future<Response<dynamic>> uploadBytes(
    String path, {
    required List<int> bytes,
    required String contentType,
  }) async {
    uploadPath = path;
    uploadedBytes = Uint8List.fromList(bytes);
    uploadContentType = contentType;
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      data: {
        'success': true,
        'data': {'storageKey': 'private-documents/employee-42/file.pdf'},
      },
    );
  }

  @override
  Future<Response<dynamic>> post(String path, {Object? data}) async {
    lastPostPath = path;
    lastPostData = data;
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      data: {
        'success': true,
        'data': {'documentId': 12, 'employeeId': 42, 'reviewStatus': 'PENDING'},
      },
    );
  }

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    lastGetPath = path;
    final data = path.endsWith('/violations')
        ? {'items': <Map<String, dynamic>>[], 'page': 0, 'totalPages': 0}
        : <Map<String, dynamic>>[];
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      data: {'success': true, 'data': data},
    );
  }
}
