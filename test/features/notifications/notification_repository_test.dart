import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_client.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_exception.dart';
import 'package:hrm_coffee_shop_flutter/features/notifications/data/notification_repository.dart';

void main() {
  test('loads and normalizes notifications using the requested page', () async {
    final api = _NotificationApi();
    final repository = NotificationRepository(api);

    final items = await repository.getMyNotifications(
      unreadOnly: true,
      page: 2,
    );

    expect(api.lastGetPath, '/api/v1/notifications/me');
    expect(api.lastQuery, {'unreadOnly': true, 'page': 2, 'size': 50});
    expect(items.single['notificationType'], 'SHIFT_REMINDER');
  });

  test('reads unread count and persists read actions', () async {
    final api = _NotificationApi();
    final repository = NotificationRepository(api);

    expect(await repository.getUnreadCount(), 3);
    expect(api.lastGetPath, '/api/v1/notifications/me/unread-count');

    await repository.markRead(91);
    expect(api.lastPostPath, '/api/v1/notifications/91/read');

    await repository.markAllRead();
    expect(api.lastPostPath, '/api/v1/notifications/read-all');
  });

  test('rejects malformed notification responses', () async {
    final repository = NotificationRepository(_NotificationApi(invalid: true));

    await expectLater(
      repository.getUnreadCount(),
      throwsA(isA<ApiException>()),
    );
  });
}

class _NotificationApi extends ApiClient {
  _NotificationApi({this.invalid = false})
    : super(dio: Dio(), storage: const FlutterSecureStorage());

  final bool invalid;
  String? lastGetPath;
  Map<String, dynamic>? lastQuery;
  String? lastPostPath;

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    lastGetPath = path;
    lastQuery = queryParameters;
    final data = path.endsWith('unread-count')
        ? {'unreadCount': 3}
        : {
            'items': [
              {'notificationId': 91, 'type': 'SHIFT_REMINDER'},
            ],
          };
    final body = invalid
        ? {'success': true, 'data': <String, dynamic>{}}
        : {'success': true, 'data': data};
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      data: body,
    );
  }

  @override
  Future<Response<dynamic>> post(String path, {Object? data}) async {
    lastPostPath = path;
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      data: {'success': true},
    );
  }
}
