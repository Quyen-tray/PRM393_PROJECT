import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_endpoints.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('Android emulator uses the host bridge by default', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    expect(ApiEndpoints.baseUrl, 'http://10.0.2.2:8080');
  });

  test('desktop and iOS simulator use localhost by default', () {
    for (final platform in [
      TargetPlatform.windows,
      TargetPlatform.macOS,
      TargetPlatform.linux,
      TargetPlatform.iOS,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      expect(ApiEndpoints.baseUrl, 'http://localhost:8080');
    }
  });
}
