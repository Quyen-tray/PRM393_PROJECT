import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'route_names.dart';

final appRouter = GoRouter(
  initialLocation: RouteNames.home,
  routes: [
    GoRoute(
      path: RouteNames.home,
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: RouteNames.login,
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: RouteNames.profile,
      builder: (context, state) => const ProfilePage(),
    ),
  ],
);

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BeanHub')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('BeanHub - HRM Coffee Shop'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(RouteNames.login),
              child: const Text('Đến trang đăng nhập'),
            ),
            TextButton(
              onPressed: () => context.go(RouteNames.profile),
              child: const Text('Đến trang cá nhân'),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập')),
      body: const Center(child: Text('Login - Đang phát triển')),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cá nhân')),
      body: const Center(child: Text('Profile - Đang phát triển')),
    );
  }
}