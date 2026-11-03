import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_client.dart';
import 'package:hrm_coffee_shop_flutter/data/repositories/employee_providers.dart';
import 'package:hrm_coffee_shop_flutter/data/repositories/employee_repository.dart';
import 'package:hrm_coffee_shop_flutter/features/notifications/data/notification_providers.dart';
import 'package:hrm_coffee_shop_flutter/features/notifications/data/notification_repository.dart';
import 'package:hrm_coffee_shop_flutter/features/notifications/presentation/employee_notifications_page.dart';

void main() {
  testWidgets('marking a notification read persists after refresh', (
    tester,
  ) async {
    final api = _NotificationApi();
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    expect(find.text('Ca làm ngày mai'), findsOneWidget);
    expect(find.text('1 chưa đọc'), findsOneWidget);
    await tester.tap(find.text('Ca làm ngày mai'));
    await tester.pumpAndSettle();

    expect(api.markReadCalls, 1);
    expect(find.text('1 chưa đọc'), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, 400));
    await tester.pumpAndSettle();

    expect(api.listCalls, greaterThanOrEqualTo(2));
    expect(api.unreadCountCalls, greaterThanOrEqualTo(2));
    expect(find.text('0 chưa đọc'), findsNothing);
    expect(find.text('Ca làm ngày mai'), findsOneWidget);
  });

  testWidgets('mark all read calls the persisted read-all endpoint', (
    tester,
  ) async {
    final api = _NotificationApi();
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Đánh dấu tất cả đã đọc'));
    await tester.pumpAndSettle();

    expect(api.markAllCalls, 1);
    expect(find.text('1 chưa đọc'), findsNothing);
    expect(find.text('Ca làm ngày mai'), findsOneWidget);
  });

  testWidgets('notification type from API drives the category filter', (
    tester,
  ) async {
    final api = _NotificationApi(notificationType: 'DOCUMENT_REVIEWED');
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Duyệt'));
    await tester.pumpAndSettle();

    expect(find.text('Hồ sơ đã được duyệt'), findsOneWidget);
    expect(find.byIcon(Icons.fact_check_outlined), findsOneWidget);
  });

  testWidgets('checklist review notifications appear under the review filter', (
    tester,
  ) async {
    final api = _NotificationApi(notificationType: 'CHECKLIST_REVIEWED');
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Duyệt'));
    await tester.pumpAndSettle();

    expect(find.text('Checklist bị từ chối - cần làm lại'), findsOneWidget);
    expect(find.byIcon(Icons.fact_check_outlined), findsOneWidget);
  });

  testWidgets('employee can load notifications after the first page', (
    tester,
  ) async {
    final api = _NotificationApi(includeSecondPage: true);
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Tải thêm thông báo'),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Tải thêm thông báo'));
    await tester.pumpAndSettle();

    expect(api.requestedPages, [0, 1]);
    expect(find.text('Thông báo trang 2'), findsOneWidget);
  });
}

Widget _app(_NotificationApi api) => ProviderScope(
  overrides: [
    employeeRepositoryProvider.overrideWithValue(EmployeeRepository(api)),
    notificationRepositoryProvider.overrideWithValue(
      NotificationRepository(api),
    ),
  ],
  child: const MaterialApp(home: EmployeeNotificationsPage()),
);

class _NotificationApi extends ApiClient {
  _NotificationApi({
    this.includeSecondPage = false,
    this.notificationType = 'SHIFT_REMINDER',
  }) : super(dio: Dio(), storage: const FlutterSecureStorage());

  final bool includeSecondPage;
  final String notificationType;

  int listCalls = 0;
  int unreadCountCalls = 0;
  int markReadCalls = 0;
  int markAllCalls = 0;
  DateTime? readAt;
  final List<int> requestedPages = [];

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    dynamic data;
    if (path == '/api/v1/notifications/me') {
      listCalls++;
      final page = (queryParameters?['page'] as num?)?.toInt() ?? 0;
      requestedPages.add(page);
      if (includeSecondPage && page == 0) {
        data = {
          'items': List.generate(
            50,
            (index) => {
              'notificationId': 100 + index,
              'type': 'DOCUMENT_APPROVED',
              'title': 'Thông báo ${index + 1}',
              'message': 'Nội dung ${index + 1}',
              'createdAt': '2026-11-03T08:00:00+07:00',
            },
          ),
        };
      } else if (includeSecondPage && page == 1) {
        data = {
          'items': [
            {
              'notificationId': 200,
              'type': 'DOCUMENT_APPROVED',
              'title': 'Thông báo trang 2',
              'message': 'Dữ liệu trang tiếp theo.',
              'createdAt': '2026-11-03T08:00:00+07:00',
            },
          ],
        };
      } else {
        data = {
          'items': [
            {
              'notificationId': 91,
              'type': notificationType,
              'title': notificationType == 'DOCUMENT_REVIEWED'
                  ? 'Hồ sơ đã được duyệt'
                  : notificationType == 'CHECKLIST_REVIEWED'
                  ? 'Checklist bị từ chối - cần làm lại'
                  : 'Ca làm ngày mai',
              'message': notificationType == 'SHIFT_REMINDER'
                  ? 'Bạn có ca lúc 08:00.'
                  : 'Có cập nhật về nội dung cần duyệt.',
              'createdAt': '2026-11-03T08:00:00+07:00',
              'readAt': readAt?.toIso8601String(),
            },
          ],
        };
      }
    } else if (path == '/api/v1/notifications/me/unread-count') {
      unreadCountCalls++;
      data = {'unreadCount': readAt == null ? 1 : 0};
    } else {
      throw StateError('Unexpected GET $path');
    }
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      data: {'success': true, 'data': data},
    );
  }

  @override
  Future<Response<dynamic>> post(String path, {Object? data}) async {
    if (path == '/api/v1/notifications/91/read') {
      markReadCalls++;
      readAt = DateTime.utc(2026, 11, 3, 1);
    } else if (path == '/api/v1/notifications/read-all') {
      markAllCalls++;
      readAt = DateTime.utc(2026, 11, 3, 1);
    } else {
      throw StateError('Unexpected POST $path');
    }
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      data: {'success': true},
    );
  }
}
