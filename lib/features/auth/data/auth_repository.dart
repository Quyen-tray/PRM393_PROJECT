import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exception.dart';
import '../domain/entities/user.dart';
import '../domain/repositories/auth_repository.dart' as domain;

class AuthRepository implements domain.AuthRepository {
  AuthRepository(this._api)
    : _googleSignIn = GoogleSignIn(
        scopes: const ['email', 'profile'],
        serverClientId: const String.fromEnvironment('GOOGLE_CLIENT_ID'),
      );

  final ApiClient _api;
  final GoogleSignIn _googleSignIn;

  @override
  Future<User> signInWithGoogle() async {
    final account = await _googleSignIn.signIn();
    if (account == null) {
      throw const ApiException(message: 'Bạn đã hủy đăng nhập Google.');
    }

    final authentication = await account.authentication;
    final idToken = authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const ApiException(
        message:
            'Không lấy được Google ID token. Hãy kiểm tra GOOGLE_CLIENT_ID.',
      );
    }

    final response = await _api.post(
      ApiEndpoints.authGoogle,
      data: {'idToken': idToken},
    );
    final body = response.data;
    if (body is! Map || body['success'] != true || body['data'] is! Map) {
      throw const ApiException(
        message: 'Phản hồi đăng nhập từ máy chủ không hợp lệ.',
      );
    }

    final data = Map<String, dynamic>.from(body['data'] as Map);
    final accessToken = data['accessToken'];
    final refreshToken = data['refreshToken'];
    if (accessToken is! String || refreshToken is! String) {
      throw const ApiException(message: 'Máy chủ không trả về đầy đủ token.');
    }

    final user = data['user'];
    if (user is! Map) {
      throw const ApiException(
        message: 'Máy chủ không trả về thông tin người dùng.',
      );
    }
    final currentUser = User.fromJson(Map<String, dynamic>.from(user));
    await _api.saveTokens(accessToken: accessToken, refreshToken: refreshToken);
    return currentUser;
  }

  @override
  Future<User> getCurrentUser() async {
    final response = await _api.get(ApiEndpoints.authMe);
    return _userFromResponse(response.data);
  }

  @override
  Future<User> updateCurrentUser({
    String? displayName,
    String? phoneNumber,
  }) async {
    final changes = <String, dynamic>{
      if (displayName != null) 'displayName': displayName,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
    };
    final response = await _api.patch(ApiEndpoints.authMe, data: changes);
    return _userFromResponse(response.data);
  }

  User _userFromResponse(dynamic response) {
    if (response is! Map ||
        response['success'] != true ||
        response['data'] is! Map) {
      throw const ApiException(message: 'Không lấy được thông tin tài khoản.');
    }
    return User.fromJson(Map<String, dynamic>.from(response['data'] as Map));
  }

  @override
  Future<void> signOut() async {
    try {
      final refreshToken = await _api.readRefreshToken();
      await _api.post(
        ApiEndpoints.authLogout,
        data: {'refreshToken': refreshToken},
      );
    } finally {
      try {
        await _api.clearTokens();
      } finally {
        await _googleSignIn.signOut();
      }
    }
  }

  Future<void> clearLocalSession() async {
    await _api.clearTokens();
    await _googleSignIn.signOut();
  }
}
