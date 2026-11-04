import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_coffee_shop_flutter/core/network/authenticated_api.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_exception.dart';
import 'package:hrm_coffee_shop_flutter/core/presentation/business_labels.dart';
import 'package:hrm_coffee_shop_flutter/core/storage/session_store.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/data/session_controller.dart';
import 'package:hrm_coffee_shop_flutter/features/operations/data/operations_repository.dart';
import 'package:hrm_coffee_shop_flutter/features/operations/domain/module_registry.dart';
import 'package:hrm_coffee_shop_flutter/features/operations/presentation/module_page.dart';
import '../support/test_support.dart';

void main() {
  test(
      'Concurrent 401 responses rotate refresh token once and retry with new access token',
      () async {
    final vault =
        TokenVault(MemoryStore({'access': 'old', 'refresh': 'original'}));
    await vault.load();
    int refreshes = 0;
    final dio = Dio(BaseOptions(baseUrl: 'http://unit.test'));
    dio.httpClientAdapter = TestAdapter((request) async {
      if (request.path.endsWith('/auth/refresh')) {
        refreshes++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return response({'accessToken': 'new', 'refreshToken': 'rotated'});
      }
      return request.headers['Authorization'] == 'Bearer new'
          ? response({'ok': true})
          : response(null, status: 401, code: 'INVALID_TOKEN');
    });
    final api = AuthenticatedApi(transport: dio, vault: vault);
    final result = await Future.wait([
      api.data('GET', '/users/me'),
      api.data('GET', '/users/me/permissions')
    ]);
    expect(refreshes, 1);
    expect(result.every((v) => v['ok'] == true), true);
    expect(await vault.store.read('refresh'), 'rotated');
  });
  test(
      '403 preserves business message, error code and field details without refresh',
      () async {
    final dio = Dio();
    dio.httpClientAdapter = TestAdapter((_) async => response(null,
        status: 403,
        message: 'Không thể tự duyệt thiết bị của chính mình',
        code: 'PERMISSION_DENIED',
        details: {'reason': 'Cần người duyệt khác'}));
    final api =
        AuthenticatedApi(transport: dio, vault: TokenVault(MemoryStore()));
    await expectLater(
        api.data('POST', '/attendance/devices/1/approve'),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'message', contains('tự duyệt'))
            .having((e) => e.code, 'code', 'PERMISSION_DENIED')
            .having((e) => e.details['reason'], 'details',
                'Cần người duyệt khác')));
  });
  test(
      'A failed refresh caused by network/server retains recoverable credentials',
      () async {
    final vault = TokenVault(
        MemoryStore({'access': 'expired', 'refresh': 'still-valid'}));
    await vault.load();
    final dio = Dio();
    dio.httpClientAdapter = TestAdapter((r) async =>
        response(null, status: r.path.endsWith('/refresh') ? 503 : 401));
    final api = AuthenticatedApi(transport: dio, vault: vault);
    await expectLater(
        api.data('GET', '/users/me'), throwsA(isA<ApiException>()));
    expect(vault.refreshToken, 'still-valid');
  });
  test('A manager role alone does not grant administrative or HR permissions',
      () {
    const manager = CurrentUser(
        id: 2,
        name: 'Manager',
        email: 'm@test',
        roles: {'STORE_MANAGER'},
        permissions: {});
    expect(module('accounts').access(manager), false);
    expect(module('documents').access(manager), false);
    expect(module('devices').access(manager), false);
    expect(module('assignments').access(manager), true);
  });
  test(
      'Permission-only users see their task without acquiring a manager workspace',
      () {
    const reviewer = CurrentUser(
        id: 3,
        name: 'Reviewer',
        email: 'r@test',
        roles: {'EMPLOYEE'},
        permissions: {'DEVICE_APPROVE', 'ATTENDANCE_ADJUST_HR'},
        employeeId: 13);
    expect(module('devices').access(reviewer), true);
    expect(module('adjustments').access(reviewer), true);
    expect(module('assignments').access(reviewer), false);
    expect(reviewer.workspaces, [Workspace.employee]);
  });
  test('Users with several roles keep all authorized workspaces', () {
    const user = CurrentUser(
        id: 4,
        name: 'Multi',
        email: 'multi@test',
        roles: {'EMPLOYEE', 'STORE_MANAGER', 'SYSTEM_ADMIN'},
        permissions: {},
        employeeId: 14);
    expect(user.workspaces.length, 3);
  });
  test('Pagination retains total count and page boundaries', () {
    final page = ResourcePage.parse({
      'items': [
        {'employeeId': 17}
      ],
      'page': 2,
      'totalPages': 4,
      'totalElements': 61
    });
    expect(page.page, 2);
    expect(page.total, 61);
    expect(page.items.single['employeeId'], 17);
  });
  test(
      'Unknown business states remain visible and midnight-crossing dates include both days',
      () {
    expect(statusLabel('NEW_BACKEND_STATE'), 'NEW_BACKEND_STATE');
    expect(dateText('2026-11-04T22:00:00+07:00'), '04/11/2026 · 22:00');
    expect(dateText('2026-11-05T06:00:00+07:00'), '05/11/2026 · 06:00');
  });
  test(
      'Notification targets preserve their entity identity and permission-specific destination',
      () {
    expect(
        notificationRoute({
          'relatedEntityType': 'EmployeeRewardPenalty',
          'relatedEntityId': 42
        }, employeeUser),
        '/record/my-rewards/42');
    expect(
        notificationRoute(
            {'relatedEntityType': 'EmployeeTraining', 'relatedEntityId': 9},
            employeeUser),
        '/record/enrollments/9');
    expect(
        notificationRoute(
            {'relatedEntityType': 'UNKNOWN', 'relatedEntityId': 9},
            employeeUser),
        null);
  });
}
