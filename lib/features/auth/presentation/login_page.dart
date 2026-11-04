import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/network/api_providers.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/repositories/employee_providers.dart';
import '../data/auth_providers.dart';
import '../domain/entities/user.dart';
import 'role_selection_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  bool _loading = false;
  bool _restoringSession = true;
  String? _restoreError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreSession());
  }

  Future<void> _restoreSession() async {
    try {
      final token = await ref.read(apiClientProvider).readAccessToken();
      if (!mounted || token == null || token.isEmpty) return;
      final user = await ref.read(authRepositoryProvider).getCurrentUser();
      final access = await ref
          .read(employeeRepositoryProvider)
          .getCurrentAccess();
      if (mounted) _continueWithUser(user.withPermissions(access.permissions));
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await ref.read(authRepositoryProvider).clearLocalSession();
      } else if (mounted) {
        setState(() => _restoreError = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _restoreError = 'Không thể khôi phục phiên đăng nhập.');
      }
    } finally {
      if (mounted) setState(() => _restoringSession = false);
    }
  }

  void _continueWithUser(User user) {
    final options = workspaceOptionsFor(user);
    final available = options.where((workspace) => workspace.enabled).toList();
    if (available.length == 1 && options.length == 1) {
      context.go(available.single.route);
    } else if (options.isNotEmpty) {
      context.go(RouteNames.roleSelection, extra: user);
    } else {
      throw const ApiException(
        message: 'Tài khoản chưa được cấp vai trò sử dụng ứng dụng.',
      );
    }
  }

  Future<void> _signIn() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final signedIn = await ref
          .read(authRepositoryProvider)
          .signInWithGoogle();
      final access = await ref
          .read(employeeRepositoryProvider)
          .getCurrentAccess();
      final user = signedIn.withPermissions(access.permissions);
      if (!mounted) return;
      if (workspaceOptionsFor(user).isEmpty) {
        await ref.read(authRepositoryProvider).clearLocalSession();
        throw const ApiException(
          message: 'Tài khoản chưa được cấp vai trò sử dụng ứng dụng.',
        );
      }
      _continueWithUser(user);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.local_cafe_rounded, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'BeanHub',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Đăng nhập hệ thống quản lý nhân sự',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 36),
                  if (_restoringSession) ...[
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 12),
                    const Text(
                      'Đang khôi phục phiên đăng nhập...',
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    FilledButton.icon(
                      onPressed: _loading ? null : _signIn,
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.g_mobiledata, size: 28),
                      label: Text(
                        _loading ? 'Đang đăng nhập...' : 'Tiếp tục với Google',
                      ),
                    ),
                    if (_restoreError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _restoreError!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'Chỉ tài khoản đã được quản trị viên cấp quyền mới có thể đăng nhập.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
