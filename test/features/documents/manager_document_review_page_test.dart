import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hrm_coffee_shop_flutter/app/router/route_names.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_client.dart';
import 'package:hrm_coffee_shop_flutter/data/repositories/employee_providers.dart';
import 'package:hrm_coffee_shop_flutter/data/repositories/employee_repository.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/data/auth_providers.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/data/auth_repository.dart';
import 'package:hrm_coffee_shop_flutter/features/home/presentation/manager_dashboard_page.dart';
import 'package:hrm_coffee_shop_flutter/features/documents/presentation/manager_document_review_page.dart';

void main() {
  testWidgets(
    'manager dashboard opens document review when permission is granted',
    (tester) async {
      await tester.pumpWidget(_dashboardApp({'DOCUMENT_REVIEW'}));
      await tester.pumpAndSettle();

      expect(find.text('Hồ sơ chờ duyệt'), findsOneWidget);
      await tester.ensureVisible(find.text('Hồ sơ chờ duyệt'));
      await tester.tap(find.text('Hồ sơ chờ duyệt'));
      await tester.pumpAndSettle();

      expect(find.text('Document reviewer destination'), findsOneWidget);
    },
  );

  testWidgets(
    'manager dashboard keeps document review unavailable without permission',
    (tester) async {
      await tester.pumpWidget(_dashboardApp(const {}));
      await tester.pumpAndSettle();

      final tile = tester.widget<ListTile>(
        find.widgetWithText(ListTile, 'Hồ sơ chờ duyệt'),
      );
      expect(tile.onTap, isNull);
    },
  );

  testWidgets('reviewer can inspect and approve a pending employee document', (
    tester,
  ) async {
    final api = _ReviewerApiClient();
    await tester.pumpWidget(_reviewerApp(api));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nguyễn Văn An'), findsOneWidget);
    await tester.tap(find.text('Xem hồ sơ'));
    await tester.pumpAndSettle();
    expect(find.text('Mở tệp'), findsOneWidget);
    expect(api.viewCalls, 1);
    await tester.tap(find.text('Đóng'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Duyệt'));
    await tester.pumpAndSettle();
    expect(api.approveCalls, 1);
    expect(find.text('Không có hồ sơ nào đang chờ duyệt.'), findsOneWidget);
  });

  testWidgets('reviewer must provide a reason before rejecting a document', (
    tester,
  ) async {
    final api = _ReviewerApiClient();
    await tester.pumpWidget(_reviewerApp(api));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Từ chối'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('document-rejection-reason')),
      'Ảnh chưa rõ nét',
    );
    await tester.tap(find.text('Gửi từ chối'));
    await tester.pumpAndSettle();

    expect(api.rejectionReason, 'Ảnh chưa rõ nét');
    expect(find.text('Không có hồ sơ nào đang chờ duyệt.'), findsOneWidget);
  });

  testWidgets('reviewer page does not load a queue without DOCUMENT_REVIEW', (
    tester,
  ) async {
    final api = _ReviewerApiClient(permissions: const {});
    await tester.pumpWidget(_reviewerApp(api));
    await tester.pumpAndSettle();

    expect(
      find.text('Tài khoản chưa được cấp quyền duyệt hồ sơ.'),
      findsOneWidget,
    );
    expect(api.pendingQueueCalls, 0);
  });
}

Widget _reviewerApp(_ReviewerApiClient api) => ProviderScope(
  overrides: [
    employeeRepositoryProvider.overrideWithValue(EmployeeRepository(api)),
  ],
  child: const MaterialApp(home: ManagerDocumentReviewPage()),
);

Widget _dashboardApp(Set<String> permissions) {
  final api = _DashboardApiClient(permissions);
  final router = GoRouter(
    initialLocation: '/dashboard',
    routes: [
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const ManagerDashboardPage(),
      ),
      GoRoute(
        path: RouteNames.managerDocumentReview,
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Document reviewer destination')),
        ),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      employeeRepositoryProvider.overrideWithValue(
        EmployeeRepository(api),
      ),
      authRepositoryProvider.overrideWithValue(AuthRepository(api)),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

class _DashboardApiClient extends ApiClient {
  _DashboardApiClient(this.permissions)
    : super(dio: Dio(), storage: const FlutterSecureStorage());

  final Set<String> permissions;

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    dynamic data;
    switch (path) {
      case '/api/v1/dashboard/manager/overview':
        data = {
          'date': '2026-11-03',
          'attendanceToday': {
            'scheduledShifts': 0,
            'checkedInOnTime': 0,
            'late': 0,
            'absent': 0,
          },
          'pending': {'documents': 1},
          'nextActions': [
            {'queue': 'documents', 'count': 1},
          ],
        };
      case '/api/v1/attendance':
        data = {'items': <Map<String, dynamic>>[]};
      case '/api/v1/users/me':
        data = {'displayName': 'Quản lý demo'};
      case '/api/v1/users/me/permissions':
        data = {
          'roles': ['STORE_MANAGER'],
          'permissions': permissions.toList(),
        };
      default:
        throw StateError('Unexpected GET $path');
    }
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      data: {'success': true, 'data': data},
    );
  }
}

class _ReviewerApiClient extends ApiClient {
  _ReviewerApiClient({this.permissions = const {'DOCUMENT_REVIEW'}})
    : super(dio: Dio(), storage: const FlutterSecureStorage());

  final Set<String> permissions;
  var pendingQueueCalls = 0;
  var viewCalls = 0;
  var approveCalls = 0;
  String? rejectionReason;
  bool reviewed = false;

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    dynamic data;
    if (path == '/api/v1/users/me/permissions') {
      data = {
        'roles': ['STORE_MANAGER'],
        'permissions': permissions.toList(),
      };
    } else if (path == '/api/v1/documents/pending') {
      pendingQueueCalls++;
      data = reviewed ? <Map<String, dynamic>>[] : [_document()];
    } else if (path == '/api/v1/documents/501') {
      viewCalls++;
      data = {
        ..._document(),
        'viewUrl': 'https://example.test/signed-document',
      };
    } else {
      throw StateError('Unexpected reviewer GET $path');
    }
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      data: {'success': true, 'data': data},
    );
  }

  @override
  Future<Response<dynamic>> post(String path, {Object? data}) async {
    if (path == '/api/v1/documents/501/approve') {
      approveCalls++;
      reviewed = true;
      return _response(path, {'documentId': 501, 'reviewStatus': 'APPROVED'});
    }
    if (path == '/api/v1/documents/501/reject') {
      rejectionReason = (data as Map)['reason']?.toString();
      reviewed = true;
      return _response(path, {'documentId': 501, 'reviewStatus': 'REJECTED'});
    }
    throw StateError('Unexpected reviewer POST $path');
  }

  Map<String, dynamic> _document() => {
    'documentId': 501,
    'employeeId': 42,
    'employeeName': 'Nguyễn Văn An',
    'documentType': {
      'documentTypeId': 2,
      'documentCode': 'FIRST_AID',
      'documentName': 'Chứng chỉ sơ cứu',
      'isActive': true,
    },
    'fileName': 'first-aid.pdf',
    'reviewStatus': 'PENDING',
  };

  Response<dynamic> _response(String path, Object data) => Response<dynamic>(
    requestOptions: RequestOptions(path: path),
    data: {'success': true, 'data': data},
  );
}
