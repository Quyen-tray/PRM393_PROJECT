import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/data/session_controller.dart';
import 'package:hrm_coffee_shop_flutter/core/network/authenticated_api.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_providers.dart';
import 'package:hrm_coffee_shop_flutter/core/storage/session_store.dart';
import '../../support/test_support.dart';

void main() {
  test('Multi-role login selects a workspace without the selector screen',
      () async {
    final store = MemoryStore({'access': 'valid', 'refresh': 'valid-refresh'});
    final dio = Dio(BaseOptions(baseUrl: 'http://unit.test'));
    dio.httpClientAdapter = TestAdapter((r) async => response(
        r.path.endsWith('/permissions')
            ? {
                'roles': ['EMPLOYEE', 'STORE_MANAGER', 'SYSTEM_ADMIN'],
                'permissions': []
              }
            : {
                'userId': 1,
                'displayName': 'Multi',
                'email': 'multi@test',
                'employeeId': 12
              }));
    final api = AuthenticatedApi(transport: dio, vault: TokenVault(store));
    final container = ProviderContainer(overrides: [
      sessionStoreProvider.overrideWithValue(store),
      authenticatedApiProvider.overrideWithValue(api)
    ]);
    addTearDown(container.dispose);
    final loaded = Completer<SessionState>();
    container.listen(sessionProvider, (_, next) {
      if (!next.loading && !loaded.isCompleted) loaded.complete(next);
    });
    final session = await loaded.future.timeout(const Duration(seconds: 5));
    expect(session.error, isNull);
    expect(container.read(sessionProvider).workspace, Workspace.admin);
  });
}
