import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

class ChecklistRepository {
  const ChecklistRepository(this._api);

  final ApiClient _api;

  Future<List<Map<String, dynamic>>> getMyChecklists({String? status}) async {
    final response = await _api.get(
      '/api/v1/checklists/me',
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    final body = response.data;
    if (body is! Map || body['success'] != true || body['data'] is! List) {
      throw const ApiException(message: 'Dữ liệu checklist không hợp lệ.');
    }
    return (body['data'] as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> getChecklist(int taskId) async =>
      _unwrapMap(await _api.get('/api/v1/checklists/tasks/$taskId'));

  Future<Map<String, dynamic>> startChecklist(int taskId) async =>
      _unwrapMap(await _api.post('/api/v1/checklists/tasks/$taskId/start'));

  Future<Map<String, dynamic>> addEvidence({
    required int taskId,
    required int runItemId,
    required String storageKey,
  }) async => _unwrapMap(
    await _api.post(
      '/api/v1/checklists/tasks/$taskId/evidence',
      data: {'runItemId': runItemId, 'evidenceStorageKey': storageKey},
    ),
  );

  Future<Map<String, dynamic>> completeItem({
    required int taskId,
    required int runItemId,
    String? note,
    String? evidenceStorageKey,
  }) async => _unwrapMap(
    await _api.post(
      '/api/v1/checklists/tasks/$taskId/items/$runItemId/complete',
      data: {
        if (note != null) 'note': note,
        if (evidenceStorageKey != null)
          'evidenceStorageKey': evidenceStorageKey,
      },
    ),
  );

  Future<Map<String, dynamic>> submitChecklist(int taskId) async =>
      _unwrapMap(await _api.post('/api/v1/checklists/tasks/$taskId/submit'));

  Map<String, dynamic> _unwrapMap(dynamic response) {
    final body = response.data;
    if (body is! Map || body['success'] != true) {
      throw const ApiException(message: 'Dữ liệu checklist không hợp lệ.');
    }
    final data = body['data'];
    if (data is! Map) {
      throw const ApiException(message: 'Dữ liệu checklist không hợp lệ.');
    }
    return Map<String, dynamic>.from(data);
  }
}
