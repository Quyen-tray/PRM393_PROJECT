import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';

class NotificationRepository {
  const NotificationRepository(this._api);

  static const pageSize = 50;

  final ApiClient _api;

  Future<List<Map<String, dynamic>>> getMyNotifications({
    bool unreadOnly = false,
    int page = 0,
  }) async {
    final response = await _api.get(
      '/api/v1/notifications/me',
      queryParameters: {
        'unreadOnly': unreadOnly,
        'page': page,
        'size': pageSize,
      },
    );
    final body = response.data;
    final data = body is Map ? body['data'] : null;
    final items = data is Map ? data['items'] : null;
    if (body is! Map || body['success'] != true || items is! List) {
      throw const ApiException(message: 'Dữ liệu thông báo không hợp lệ.');
    }
    return items.whereType<Map>().map((item) {
      final notification = Map<String, dynamic>.from(item);
      notification['notificationType'] ??= notification['type'];
      return notification;
    }).toList();
  }

  Future<int> getUnreadCount() async {
    final response = await _api.get('/api/v1/notifications/me/unread-count');
    final body = response.data;
    final data = body is Map ? body['data'] : null;
    final count = data is Map ? data['unreadCount'] : null;
    if (body is! Map || body['success'] != true || count is! num) {
      throw const ApiException(
        message: 'Không đọc được số thông báo chưa xem.',
      );
    }
    return count.toInt();
  }

  Future<void> markRead(int notificationId) async {
    _ensureSuccess(
      (await _api.post('/api/v1/notifications/$notificationId/read')).data,
    );
  }

  Future<void> markAllRead() async {
    _ensureSuccess((await _api.post('/api/v1/notifications/read-all')).data);
  }

  void _ensureSuccess(dynamic response) {
    if (response is! Map || response['success'] != true) {
      throw const ApiException(message: 'Không thể cập nhật thông báo.');
    }
  }
}
