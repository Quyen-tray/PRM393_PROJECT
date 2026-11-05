import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_providers.dart';
import 'google_oauth.dart';

import 'package:hrm_coffee_shop_flutter/features/auth/domain/current_user.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/domain/session_state.dart';
import 'package:hrm_coffee_shop_flutter/features/workspace/domain/workspace.dart';

export 'package:hrm_coffee_shop_flutter/features/auth/domain/current_user.dart';
export 'package:hrm_coffee_shop_flutter/features/auth/domain/session_state.dart';
export 'package:hrm_coffee_shop_flutter/features/workspace/domain/workspace.dart';

final sessionProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    Future.microtask(restore);
    return const SessionState(loading: true);
  }

  Future<void> restore() async {
    final api = ref.read(authenticatedApiProvider);
    api.onExpired = expire;
    try {
      await api.vault.load();
      if (api.vault.accessToken == null && api.vault.refreshToken != null) {
        await api.refresh();
      }
      if (api.vault.accessToken == null) {
        state = const SessionState();
        return;
      }
      await loadProfile();
    } catch (e) {
      state = SessionState(error: e);
    }
  }

  Future<void> googleLogin() async {
    state = const SessionState(loading: true);
    try {
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.linux)) {
        throw const ApiException(
            message:
                'Đăng nhập Google hiện hỗ trợ Android, iOS và trình duyệt. Hãy chạy ứng dụng trên một nền tảng được hỗ trợ.');
      }
      final google = ref.read(googleSignInProvider);
      final account = await google.signIn();
      if (account == null) {
        state = const SessionState();
        return;
      }
      final token = (await account.authentication).idToken;
      if (token == null || token.trim().isEmpty) {
        throw const ApiException(
            message:
                'Google không cấp ID token. Kiểm tra Web OAuth Client ID trong GOOGLE_SERVER_CLIENT_ID/GOOGLE_CLIENT_ID và cấu hình Android package/SHA-1, rồi dừng và chạy lại ứng dụng.');
      }
      final api = ref.read(authenticatedApiProvider);
      await api.vault.load();
      final tokens =
          await api.data('POST', '/auth/google', body: {'idToken': token});
      await api.vault.save(Map<String, dynamic>.from(tokens as Map));
      await loadProfile();
    } catch (e) {
      state = SessionState(error: e);
    }
  }

  Future<void> loadProfile() async {
    final api = ref.read(authenticatedApiProvider);
    final result = await Future.wait([
      api.data('GET', '/users/me'),
      api.data('GET', '/users/me/permissions')
    ]);
    final user = CurrentUser.fromJson(Map<String, dynamic>.from(result[0]),
        Map<String, dynamic>.from(result[1]));
    final saved =
        await ref.read(sessionStoreProvider).read('workspace-${user.id}');
    final selected = state.user?.id == user.id &&
            state.workspace != null &&
            user.workspaces.contains(state.workspace)
        ? state.workspace
        : user.workspaces.where((w) => w.code == saved).firstOrNull ??
            (user.workspaces.contains(Workspace.admin)
                ? Workspace.admin
                : user.workspaces.contains(Workspace.manager)
                    ? Workspace.manager
                    : user.workspaces.firstOrNull);
    state = SessionState(user: user, workspace: selected);
  }

  Future<void> select(Workspace workspace) async {
    final user = state.user;
    if (user == null || !user.workspaces.contains(workspace)) return;
    await ref
        .read(sessionStoreProvider)
        .write('workspace-${user.id}', workspace.code);
    state = SessionState(user: user, workspace: workspace);
  }

  void expire() {
    state = const SessionState();
  }

  Future<void> logout() async {
    final api = ref.read(authenticatedApiProvider);
    Object? error;
    try {
      await api.data('POST', '/auth/logout',
          body: {'refreshToken': api.vault.refreshToken});
    } catch (e) {
      error = e;
    } finally {
      await api.vault.clear();
      state = SessionState(error: error);
    }
    try {
      await ref.read(googleSignInProvider).signOut();
    } catch (_) {/* Local session was already cleared. */}
  }
}
