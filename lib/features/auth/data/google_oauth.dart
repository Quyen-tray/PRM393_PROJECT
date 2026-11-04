import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/network/api_exception.dart';

String resolveGoogleClientId({
  String serverClientId =
      const String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID'),
  String clientId = const String.fromEnvironment('GOOGLE_CLIENT_ID'),
}) {
  final resolved = serverClientId.trim().isNotEmpty
      ? serverClientId.trim()
      : clientId.trim();
  if (resolved.isEmpty) {
    throw const ApiException(
        message:
            'Chưa cấu hình Google OAuth. Truyền GOOGLE_SERVER_CLIENT_ID hoặc GOOGLE_CLIENT_ID bằng --dart-define với Web OAuth Client ID, rồi dừng và chạy lại ứng dụng.');
  }
  return resolved;
}

final googleClientIdProvider =
    Provider<String>((ref) => resolveGoogleClientId());

final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  final clientId = ref.watch(googleClientIdProvider);
  return GoogleSignIn(
      scopes: ['email'],
      clientId: kIsWeb ? clientId : null,
      serverClientId: kIsWeb ? null : clientId);
});
