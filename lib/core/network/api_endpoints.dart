abstract final class ApiEndpoints {
  /// Android emulator: 10.0.2.2; iOS simulator: localhost.
  /// Override with --dart-define=API_BASE_URL=http://<host>:8080
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  static const authGoogle = '/api/v1/auth/google';
  static const authRefresh = '/api/v1/auth/refresh';
  static const authLogout = '/api/v1/auth/logout';
  static const authMe = '/api/v1/users/me';
}
