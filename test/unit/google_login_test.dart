import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_exception.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_providers.dart';
import 'package:hrm_coffee_shop_flutter/core/network/authenticated_api.dart';
import 'package:hrm_coffee_shop_flutter/core/storage/session_store.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/data/google_oauth.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/data/session_controller.dart';
import '../support/test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const alias = 'regression-web-client.apps.googleusercontent.com';
  const channel = MethodChannel('plugins.flutter.io/google_sign_in');

  test('Legacy GOOGLE_CLIENT_ID requests an Android server ID token', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    // Run with only --dart-define=GOOGLE_CLIENT_ID=... to reproduce the
    // original launch configuration, without relying on env.json.
    const serverId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
    const legacyId = String.fromEnvironment('GOOGLE_CLIENT_ID');
    final configured = serverId.trim().isNotEmpty || legacyId.trim().isNotEmpty;
    final container = ProviderContainer(overrides: [
      if (!configured)
        googleClientIdProvider.overrideWithValue(
            resolveGoogleClientId(serverClientId: '', clientId: alias))
    ]);
    addTearDown(container.dispose);
    final google = container.read(googleSignInProvider);
    await google.signIn();
    final init = calls.singleWhere((c) => c.method == 'init');
    expect(init.arguments['serverClientId'],
        configured ? resolveGoogleClientId() : alias);
    expect(init.arguments['clientId'], isNull);
  });

  test('Canonical client ID wins when both names are configured', () {
    expect(
        resolveGoogleClientId(
            serverClientId: ' canonical.apps.googleusercontent.com ',
            clientId: alias),
        'canonical.apps.googleusercontent.com');
    expect(resolveGoogleClientId(serverClientId: ' ', clientId: ' $alias '),
        alias);
  });

  test('Missing client ID fails with an actionable configuration error', () {
    expect(
        () => resolveGoogleClientId(serverClientId: '', clientId: ' '),
        throwsA(isA<ApiException>()
            .having((e) => e.message, 'instructions', contains('--dart-define'))
            .having((e) => e.message, 'configuration',
                contains('GOOGLE_CLIENT_ID'))));
  });

  for (final scenario in ['valid', 'missing-token', 'cancelled', 'forbidden']) {
    test('Google login $scenario preserves the backend/session boundary',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final pluginCalls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        pluginCalls.add(call);
        if (call.method == 'signIn') {
          return scenario == 'cancelled'
              ? null
              : {
                  'email': 'employee@example.test',
                  'id': 'google-subject-fixture',
                  'displayName': 'Nhân viên kiểm thử',
                };
        }
        if (call.method == 'getTokens') {
          return {
            'idToken': scenario == 'missing-token' ? null : 'google-id-fixture'
          };
        }
        return null;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null));
      final requests = <RequestOptions>[];
      final store = MemoryStore();
      final dio = Dio(BaseOptions(baseUrl: 'http://unit.test'));
      dio.httpClientAdapter = TestAdapter((request) async {
        requests.add(request);
        if (request.path.endsWith('/auth/google')) {
          expect(request.data, {'idToken': 'google-id-fixture'});
          return scenario == 'forbidden'
              ? response(null,
                  status: 403,
                  code: 'ACCOUNT_NOT_ACTIVE',
                  message: 'Tài khoản chưa hoạt động')
              : response({
                  'accessToken': 'backend-access-fixture',
                  'refreshToken': 'backend-refresh-fixture'
                });
        }
        expect(
            request.headers['Authorization'], 'Bearer backend-access-fixture');
        return response(request.path.endsWith('/permissions')
            ? {
                'roles': ['EMPLOYEE'],
                'permissions': []
              }
            : {
                'userId': 1,
                'displayName': 'Nhân viên kiểm thử',
                'email': 'employee@example.test',
                'employeeId': 12
              });
      });
      final container = ProviderContainer(overrides: [
        googleClientIdProvider.overrideWithValue(alias),
        sessionStoreProvider.overrideWithValue(store),
        authenticatedApiProvider.overrideWithValue(
            AuthenticatedApi(transport: dio, vault: TokenVault(store)))
      ]);
      addTearDown(container.dispose);
      final controller = container.read(sessionProvider.notifier);
      // Finish initial restoration before starting an interactive login.
      await Future<void>.delayed(Duration.zero);
      await controller.googleLogin();
      final state = container.read(sessionProvider);
      expect(state.loading, false);
      expect(pluginCalls.first.arguments['serverClientId'], alias);
      if (scenario == 'valid') {
        expect(state.user?.employeeId, 12);
        expect(state.workspace, Workspace.employee);
        expect(await store.read('access'), 'backend-access-fixture');
        expect(await store.read('refresh'), 'backend-refresh-fixture');
        expect(requests.length, 3);
      } else {
        expect(state.user, isNull);
        expect(await store.read('access'), isNull);
        expect(await store.read('refresh'), isNull);
        if (scenario == 'cancelled') {
          expect(state.error, isNull);
          expect(requests, isEmpty);
        } else if (scenario == 'missing-token') {
          expect(state.error, isA<ApiException>());
          expect('${state.error}', contains('Google không cấp ID token'));
          expect(requests, isEmpty);
        } else {
          expect(state.error, isA<ApiException>());
          expect('${state.error}', contains('Tài khoản chưa hoạt động'));
          expect(requests.length, 1);
        }
      }
    });
  }
}
