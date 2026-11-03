import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../data/auth_providers.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  bool _loading = false;

  Future<void> _signIn() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final user = await ref.read(authRepositoryProvider).signInWithGoogle();
      if (!mounted) return;

      if (user.hasRole('SYSTEM_ADMIN')) {
        context.go(RouteNames.adminHome);
      } else if (user.hasRole('STORE_MANAGER') ||
          user.hasRole('OPERATIONS_DIRECTOR')) {
        context.go(RouteNames.home);
      } else if (user.hasRole('EMPLOYEE')) {
        context.go(RouteNames.employeeHome);
      } else {
        await ref.read(authRepositoryProvider).clearLocalSession();
        throw Exception('Tài khoản chưa được cấp vai trò sử dụng ứng dụng.');
      }
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
                  const SizedBox(height: 16),
                  Text(
                    'Chỉ tài khoản đã được quản trị viên cấp quyền mới có thể đăng nhập.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
