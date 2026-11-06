import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:hrm_coffee_shop_flutter/core/network/authenticated_api.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_exception.dart';
import 'package:hrm_coffee_shop_flutter/core/storage/session_store.dart';
import '../../support/test_support.dart';

void main() {
  test('A delayed 401 reuses the token rotated by a parallel request',
      () async {
    final waiting = Completer<void>(), release = Completer<void>();
    final vault =
        TokenVault(MemoryStore({'access': 'old', 'refresh': 'original'}));
    await vault.load();
    int refreshes = 0;
    final dio = Dio();
    dio.httpClientAdapter = TestAdapter((request) async {
      if (request.path.endsWith('/auth/refresh')) {
        refreshes++;
        return response({'accessToken': 'new', 'refreshToken': 'rotated'});
      }
      if (request.headers['Authorization'] == 'Bearer new') {
        return response({'ok': true});
      }
      if (request.path.endsWith('/permissions')) {
        waiting.complete();
        await release.future;
      }
      return response(null, status: 401, code: 'INVALID_TOKEN');
    });
    final api = AuthenticatedApi(transport: dio, vault: vault);
    final delayed = api.data('GET', '/users/me/permissions');
    await waiting.future;
    expect((await api.data('GET', '/users/me'))['ok'], true);
    release.complete();
    expect((await delayed)['ok'], true);
    expect(refreshes, 1);
    expect(vault.refreshToken, 'rotated');
  });

  test('A failed refresh cannot clear a new account selected while waiting',
      () async {
    final waiting = Completer<void>(), release = Completer<void>();
    final vault =
        TokenVault(MemoryStore({'access': 'old', 'refresh': 'old-refresh'}));
    await vault.load();
    final dio = Dio();
    dio.httpClientAdapter = TestAdapter((request) async {
      if (request.path.endsWith('/auth/refresh')) {
        waiting.complete();
        await release.future;
      }
      return response(null, status: 401, code: 'INVALID_TOKEN');
    });
    final api = AuthenticatedApi(transport: dio, vault: vault);
    final result =
        expectLater(api.data('GET', '/users/me'), throwsA(isA<ApiException>()));
    await waiting.future;
    await vault
        .save({'accessToken': 'new-account', 'refreshToken': 'new-refresh'});
    release.complete();
    await result;
    expect(vault.accessToken, 'new-account');
    expect(vault.refreshToken, 'new-refresh');
  });

  test('A previous account 401 cannot clear the newly selected account',
      () async {
    final started = Completer<void>();
    final finish = Completer<void>();
    final vault =
        TokenVault(MemoryStore({'access': 'old', 'refresh': 'old-refresh'}));
    await vault.load();
    final dio = Dio();
    dio.httpClientAdapter = TestAdapter((r) async {
      started.complete();
      await finish.future;
      return response(null, status: 401, code: 'INVALID_TOKEN');
    });
    final api = AuthenticatedApi(transport: dio, vault: vault);
    final pending =
        expectLater(api.data('GET', '/users/me'), throwsA(isA<ApiException>()));
    await started.future;
    await vault
        .save({'accessToken': 'new-account', 'refreshToken': 'new-refresh'});
    finish.complete();
    await pending;
    expect(vault.accessToken, 'new-account');
    expect(vault.refreshToken, 'new-refresh');
  });
  test(
    'Concurrent 401 responses rotate refresh token once and retry with new access token',
    () async {
      final vault = TokenVault(
        MemoryStore({'access': 'old', 'refresh': 'original'}),
      );
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
        api.data('GET', '/users/me/permissions'),
      ]);
      expect(refreshes, 1);
      expect(result.every((v) => v['ok'] == true), true);
      expect(await vault.store.read('refresh'), 'rotated');
    },
  );

  test(
    '403 preserves business message, error code and field details without refresh',
    () async {
      final dio = Dio();
      dio.httpClientAdapter = TestAdapter(
        (_) async => response(
          null,
          status: 403,
          message: 'Không thể tự duyệt thiết bị của chính mình',
          code: 'PERMISSION_DENIED',
          details: {'reason': 'Cần người duyệt khác'},
        ),
      );
      final api = AuthenticatedApi(
        transport: dio,
        vault: TokenVault(MemoryStore()),
      );
      await expectLater(
        api.data('POST', '/attendance/devices/1/approve'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.message, 'message', contains('tự duyệt'))
              .having((e) => e.code, 'code', 'PERMISSION_DENIED')
              .having(
                (e) => e.details['reason'],
                'details',
                'Cần người duyệt khác',
              ),
        ),
      );
    },
  );

  test(
    'A failed refresh caused by network/server retains recoverable credentials',
    () async {
      final vault = TokenVault(
        MemoryStore({'access': 'expired', 'refresh': 'still-valid'}),
      );
      await vault.load();
      final dio = Dio();
      dio.httpClientAdapter = TestAdapter(
        (r) async =>
            response(null, status: r.path.endsWith('/refresh') ? 503 : 401),
      );
      final api = AuthenticatedApi(transport: dio, vault: vault);
      await expectLater(
        api.data('GET', '/users/me'),
        throwsA(isA<ApiException>()),
      );
      expect(vault.refreshToken, 'still-valid');
    },
  );
}
