abstract final class ApiEndpoints {
  // Thay bằng địa chỉ backend của bạn.
  static const baseUrl = 'http://10.0.2.2:8080';

  static const authGoogle = '/api/v1/auth/google';
  static const authMe = '/api/v1/auth/me';
  static const authLogout = '/api/v1/auth/logout';
}