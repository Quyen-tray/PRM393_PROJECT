// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_coffee_shop_flutter/app/app.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_client.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_providers.dart';
import 'package:dio/dio.dart';

void main() {
  testWidgets('app opens the login screen without framework exceptions', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(_NoSessionApiClient())],
        child: const BeanHubApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('BeanHub'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _NoSessionApiClient extends ApiClient {
  _NoSessionApiClient() : super(dio: Dio());

  @override
  Future<String?> readAccessToken() async => null;
}
