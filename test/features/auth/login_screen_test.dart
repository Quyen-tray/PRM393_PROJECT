import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_coffee_shop_flutter/app/app.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_providers.dart';
import '../../support/test_support.dart';

void main() {
  testWidgets('An empty secure session opens real sign-in UI', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionStoreProvider.overrideWithValue(MemoryStore())],
        child: const BeanHubApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Đăng nhập bằng Google'), findsOneWidget);
    expect(find.textContaining('Tài khoản đã được'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
