import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_client.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_exception.dart';
import 'package:hrm_coffee_shop_flutter/data/repositories/employee_providers.dart';
import 'package:hrm_coffee_shop_flutter/data/repositories/employee_repository.dart';
import 'package:hrm_coffee_shop_flutter/features/rewards/presentation/employee_rewards_page.dart';

void main() {
  testWidgets('employee can page through their own reward decisions', (
    tester,
  ) async {
    final api = _RewardsApi();
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    expect(find.text('Thưởng · Hỗ trợ khách hàng tốt'), findsOneWidget);
    expect(find.text('Chờ duyệt'), findsOneWidget);
    expect(find.textContaining('50.000 ₫'), findsOneWidget);

    await tester.tap(find.text('Tải thêm'));
    await tester.pumpAndSettle();

    expect(api.pages, [0, 1]);
    expect(find.text('Phạt · Đi muộn'), findsOneWidget);
    expect(find.text('Đã duyệt'), findsOneWidget);
  });

  testWidgets('employee rewards shows retry after an API failure', (
    tester,
  ) async {
    final api = _RewardsApi(failFirstRequest: true);
    await tester.pumpWidget(_app(api));
    await tester.pumpAndSettle();

    expect(find.text('Tạm thời không kết nối.'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(find.text('Thưởng · Hỗ trợ khách hàng tốt'), findsOneWidget);
    expect(api.pages, [0, 0]);
  });
}

Widget _app(_RewardsApi api) => ProviderScope(
  overrides: [
    employeeRepositoryProvider.overrideWithValue(EmployeeRepository(api)),
  ],
  child: const MaterialApp(home: EmployeeRewardsPage()),
);

class _RewardsApi extends ApiClient {
  _RewardsApi({this.failFirstRequest = false})
    : super(dio: Dio(), storage: const FlutterSecureStorage());

  final bool failFirstRequest;
  final List<int> pages = [];

  @override
  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    if (path != '/api/v1/rewards-penalties/me') {
      throw StateError('Unexpected GET $path');
    }
    final page = (queryParameters?['page'] as num?)?.toInt() ?? 0;
    pages.add(page);
    if (failFirstRequest && pages.length == 1) {
      throw const ApiException(message: 'Tạm thời không kết nối.');
    }
    final item = page == 0
        ? {
            'decisionType': 'REWARD',
            'status': 'PENDING_APPROVAL',
            'reasonName': 'Hỗ trợ khách hàng tốt',
            'amount': 50000,
            'effectiveAt': '2026-11-03T00:00:00+07:00',
          }
        : {
            'decisionType': 'PENALTY',
            'status': 'APPROVED',
            'reasonName': 'Đi muộn',
            'amount': 20000,
            'effectiveAt': '2026-11-02T00:00:00+07:00',
          };
    return Response<dynamic>(
      requestOptions: RequestOptions(path: path),
      data: {
        'success': true,
        'data': {
          'items': [item],
          'page': page,
          'totalPages': 2,
          'totalElements': 2,
        },
      },
    );
  }
}
