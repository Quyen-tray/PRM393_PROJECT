import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';

class AuthRepository {
  AuthRepository(this._api)
      : _googleSignIn = GoogleSignIn(
          scopes: const ['email', 'profile'],
          serverClientId: const String.fromEnvironment('GOOGLE_CLIENT_ID'),
        );

  final ApiClient _api;
  final GoogleSignIn _googleSignIn;

  Future<Map<String, dynamic>> signInWithGoogle() async {
    final account = await _googleSignIn.signIn();
    if (account == null) {
      throw const ApiException(message: 'Bạn đã hủy đăng nhập Google.');
    }

    final authentication = await account.authentication;
    final idToken = authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const ApiException(
        message: 'Không lấy được Google ID token. Hãy kiểm tra GOOGLE_CLIENT_ID.',
      );
    }

    final response = await _api.post(
      ApiEndpoints.authGoogle,
      data: {'idToken': idToken},
    );
    final body = response.data;
    if (body is! Map || body['success'] != true || body['data'] is! Map) {
      throw const ApiException(message: 'Phản hồi đăng nhập từ máy chủ không hợp lệ.');
    }

    final data = Map<String, dynamic>.from(body['data'] as Map);
    final accessToken = data['accessToken'];
    final refreshToken = data['refreshToken'];
    if (accessToken is! String || refreshToken is! String) {
      throw const ApiException(message: 'Máy chủ không trả về đầy đủ token.');
    }

    await _api.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );

    final user = data['user'];
    if (user is! Map) {
      throw const ApiException(message: 'Máy chủ không trả về thông tin người dùng.');
    }
    return Map<String, dynamic>.from(user);
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    final response = await _api.get(ApiEndpoints.authMe);
    final body = response.data;
    if (body is! Map || body['success'] != true || body['data'] is! Map) {
      throw const ApiException(message: 'Không lấy được thông tin tài khoản.');
    }
    return Map<String, dynamic>.from(body['data'] as Map);
  }

  Future<void> signOut() async {
    final refreshToken = await _api.readRefreshToken();
    try {
      await _api.post(
        ApiEndpoints.authLogout,
        data: {'refreshToken': refreshToken},
      );
    } finally {
      await _api.clearTokens();
      await _googleSignIn.signOut();
    }
  }

  Future<void> clearLocalSession() async {
    await _api.clearTokens();
    await _googleSignIn.signOut();
  }
}
