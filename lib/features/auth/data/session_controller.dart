import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_providers.dart';

enum Workspace {
  employee('EMPLOYEE', 'Nhân viên'),
  manager('STORE_MANAGER', 'Quản lý cửa hàng'),
  admin('SYSTEM_ADMIN', 'Quản trị hệ thống');

  const Workspace(this.code, this.label);
  final String code;
  final String label;
}

class CurrentUser {
  const CurrentUser(
      {required this.id,
      required this.name,
      required this.email,
      required this.roles,
      required this.permissions,
      this.employeeId});
  final int id;
  final String name, email;
  final int? employeeId;
  final Set<String> roles, permissions;
  factory CurrentUser.fromJson(
          Map<String, dynamic> profile, Map<String, dynamic> grants) =>
      CurrentUser(
          id: (profile['userId'] as num).toInt(),
          name: profile['displayName'] as String? ?? '',
          email: profile['email'] as String? ?? '',
          employeeId: (profile['employeeId'] as num?)?.toInt(),
          roles: Set<String>.from(
              grants['roles'] as List? ?? profile['roles'] as List? ?? []),
          permissions: Set<String>.from(grants['permissions'] as List? ?? []));
  bool has(String permission) => permissions.contains(permission);
  bool role(String role) => roles.contains(role);
  bool get manager => role('STORE_MANAGER');
  bool get admin => role('SYSTEM_ADMIN');
  List<Workspace> get workspaces => [
        if (employeeId != null || role('EMPLOYEE')) Workspace.employee,
        if (manager || role('OPERATIONS_DIRECTOR')) Workspace.manager,
        if (admin) Workspace.admin,
      ];
}

class SessionState {
  const SessionState(
      {this.loading = false, this.user, this.workspace, this.error});
  final bool loading;
  final CurrentUser? user;
  final Workspace? workspace;
  final Object? error;
}

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
      const clientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
      final google = GoogleSignIn(
          scopes: ['email'],
          clientId: kIsWeb && clientId.isNotEmpty ? clientId : null,
          serverClientId: !kIsWeb && clientId.isNotEmpty ? clientId : null);
      final account = await google.signIn();
      if (account == null) {
        state = const SessionState();
        return;
      }
      final token = (await account.authentication).idToken;
      if (token == null) {
        throw const ApiException(
            message:
                'Google không cấp ID token. Kiểm tra cấu hình OAuth của ứng dụng.');
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
    final selected =
        state.workspace != null && user.workspaces.contains(state.workspace)
            ? state.workspace
            : user.workspaces.where((w) => w.code == saved).firstOrNull ??
                (user.workspaces.length == 1 ? user.workspaces.first : null);
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
      await GoogleSignIn().signOut();
    } catch (_) {/* Local session was already cleared. */}
  }
}
