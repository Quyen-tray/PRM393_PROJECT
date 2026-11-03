import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_client.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_exception.dart';
import 'package:hrm_coffee_shop_flutter/features/checklist/data/checklist_repository.dart';

void main() {
  test(
    'loads employee checklist summaries with an optional status filter',
    () async {
      final api = _ChecklistApi();
      final repository = ChecklistRepository(api);

      final summaries = await repository.getMyChecklists(status: 'PENDING');

      expect(api.lastGetPath, '/api/v1/checklists/me');
      expect(api.lastQuery, {'status': 'PENDING'});
      expect(summaries, [
        {'taskId': 12, 'status': 'PENDING'},
      ]);

      await repository.getMyChecklists();
      expect(api.lastQuery, isEmpty);
    },
  );

  test(
    'checklist actions use task endpoints and preserve request payloads',
    () async {
      final api = _ChecklistApi();
      final repository = ChecklistRepository(api);

      expect(await repository.getChecklist(12), {'taskId': 12});
      expect(api.lastGetPath, '/api/v1/checklists/tasks/12');

      await repository.startChecklist(12);
      expect(api.lastPostPath, '/api/v1/checklists/tasks/12/start');

      await repository.addEvidence(
        taskId: 12,
        runItemId: 34,
        storageKey: 'checklists/private/evidence.jpg',
      );
      expect(api.lastPostPath, '/api/v1/checklists/tasks/12/evidence');
      expect(api.lastPostData, {
        'runItemId': 34,
        'evidenceStorageKey': 'checklists/private/evidence.jpg',
      });

      await repository.completeItem(taskId: 12, runItemId: 34, note: 'Done');
      expect(api.lastPostPath, '/api/v1/checklists/tasks/12/items/34/complete');
      expect(api.lastPostData, {'note': 'Done'});

      await repository.submitChecklist(12);
      expect(api.lastPostPath, '/api/v1/checklists/tasks/12/submit');
    },
  );

  test('rejects malformed checklist responses', () async {
    final repository = ChecklistRepository(_ChecklistApi(invalid: true));

    await expectLater(
      repository.getMyChecklists(),
      throwsA(isA<ApiException>()),
    );
  });
}

class _ChecklistApi extends ApiClient {
  _ChecklistApi({this.invalid = false})
    : super(dio: Dio(), storage: const FlutterSecureStorage());

  final bool invalid;
  String? lastGetPath;
  Map<String, dynamic>? lastQuery;
  String? lastPostPath;
  Object? lastPostData;

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    lastGetPath = path;
    lastQuery = queryParameters ?? {};
    final data = path.endsWith('/me')
        ? [
            {'taskId': 12, 'status': 'PENDING'},
          ]
        : {'taskId': 12};
    return _response(
      path,
      invalid ? {'success': false} : {'success': true, 'data': data},
    );
  }

  @override
  Future<Response<dynamic>> post(String path, {Object? data}) async {
    lastPostPath = path;
    lastPostData = data;
    return _response(path, {
      'success': true,
      'data': {'taskId': 12},
    });
  }

  Response<dynamic> _response(String path, Object data) => Response<dynamic>(
    requestOptions: RequestOptions(path: path),
    data: data,
  );
}
