import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/data/auth_providers.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/data/auth_repository.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/domain/entities/user.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/presentation/login_page.dart';

void main() {
  testWidgets(
    'an EMPLOYEE role opens the employee dashboard after Google sign-in',
    (tester) async {
      final repository = _EmployeeAuthRepository();
      final router = GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(
            path: '/login',
            builder: (context, state) => const LoginPage(),
          ),
          GoRoute(
            path: '/employee',
            builder: (context, state) =>
                const Scaffold(body: Text('employee-dashboard')),
          ),
          GoRoute(
            path: '/admin',
            builder: (context, state) =>
                const Scaffold(body: Text('admin-dashboard')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWith((ref) => repository)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ti\u1ebfp t\u1ee5c v\u1edbi Google'));
      await tester.pumpAndSettle();

      expect(repository.signInCalls, 1);
      expect(find.text('employee-dashboard'), findsOneWidget);
    },
  );

  testWidgets('unlinked employee account still opens employee navigation', (
    tester,
  ) async {
    final repository = _EmployeeAuthRepository(linkedEmployee: false);
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
        GoRoute(
          path: '/employee',
          builder: (context, state) =>
              const Scaffold(body: Text('employee-dashboard')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWith((ref) => repository)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiếp tục với Google'));
    await tester.pumpAndSettle();

    expect(find.text('employee-dashboard'), findsOneWidget);
    expect(find.text('account-profile'), findsNothing);
  });
}

class _EmployeeAuthRepository implements AuthRepository {
  _EmployeeAuthRepository({this.linkedEmployee = true});

  final bool linkedEmployee;
  int signInCalls = 0;

  @override
  Future<void> clearLocalSession() async {}

  @override
  Future<User> getCurrentUser() async => User(
    id: '1',
    email: 'employee@example.test',
    fullName: 'Employee',
    roles: const ['EMPLOYEE'],
    employeeId: linkedEmployee ? 1 : null,
  );

  @override
  Future<User> updateCurrentUser({
    String? displayName,
    String? phoneNumber,
  }) async => getCurrentUser();

  @override
  Future<void> signOut() async {}

  @override
  Future<User> signInWithGoogle() async {
    signInCalls++;
    return await getCurrentUser();
  }
}
