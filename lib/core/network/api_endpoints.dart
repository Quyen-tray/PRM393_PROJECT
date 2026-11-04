import 'package:flutter/foundation.dart';

abstract final class ApiEndpoints {
  /// Android emulator: 10.0.2.2. Other local targets: localhost.
  /// Override with `--dart-define=API_BASE_URL=http://host:8080`.
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    final isAndroidApp =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final configured = _configuredBaseUrl.trim();
    if (configured.isNotEmpty) {
      final uri = Uri.tryParse(configured);
      if (!isAndroidApp && uri?.host == '10.0.2.2') {
        return uri!.replace(host: 'localhost').toString();
      }
      return configured;
    }
    return isAndroidApp ? 'http://10.0.2.2:8080' : 'http://localhost:8080';
  }

  static const authGoogle = '/api/v1/auth/google';
  static const authRefresh = '/api/v1/auth/refresh';
  static const authLogout = '/api/v1/auth/logout';
  static const authMe = '/api/v1/users/me';
}
