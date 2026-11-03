import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/data/auth_providers.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/data/auth_repository.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/domain/entities/user.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/presentation/sign_out_flow.dart';
import 'package:hrm_coffee_shop_flutter/features/admin/presentation/widgets/admin_more_menu.dart';
import 'package:hrm_coffee_shop_flutter/features/home/presentation/widgets/manager_more_menu.dart';
import 'package:hrm_coffee_shop_flutter/features/profile/presentation/account_profile_page.dart';
import 'package:hrm_coffee_shop_flutter/data/repositories/employee_providers.dart';
import 'package:hrm_coffee_shop_flutter/data/repositories/employee_repository.dart';

typedef _ShowMoreMenu =
    Future<void> Function(
      BuildContext context, {
      required Future<void> Function() onSignOut,
    });

void main() {
  testWidgets('admin can sign out when the remote logout request fails', (
    tester,
  ) async {
    await _expectMenuLogout(tester, showAdminMoreMenu);
  });

  testWidgets('manager can sign out when the remote logout request fails', (
    tester,
  ) async {
    await _expectMenuLogout(tester, showManagerMoreMenu);
  });

  testWidgets('employee can sign out from the profile page', (tester) async {
    final repository = _FakeAuthRepository();
    final router = GoRouter(
      initialLocation: '/employee/profile',
      routes: [
        GoRoute(
          path: '/employee/profile',
          builder: (context, state) => const AccountProfilePage(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) =>
              const Scaffold(body: Text('login-screen')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWith((ref) => repository),
          employeeRepositoryProvider.overrideWith(
            (ref) => _FakeEmployeeRepository(),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('\u0110\u0103ng xu\u1ea5t'));
    await tester.pumpAndSettle();

    expect(repository.signOutCalls, 1);
    expect(find.text('login-screen'), findsOneWidget);
  });
}

Future<void> _expectMenuLogout(
  WidgetTester tester,
  _ShowMoreMenu showMenu,
) async {
  final repository = _FakeAuthRepository(failSignOut: true);
  final router = GoRouter(
    initialLocation: '/protected',
    routes: [
      GoRoute(
        path: '/protected',
        builder: (context, state) => Consumer(
          builder: (context, ref, child) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showMenu(
                  context,
                  onSignOut: () => signOutAndReturnToLogin(context, ref),
                ),
                child: const Text('more-menu'),
              ),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const Scaffold(body: Text('login-screen')),
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
  await tester.tap(find.text('more-menu'));
  await tester.pumpAndSettle();
  await tester.drag(find.byType(ListView), const Offset(0, -400));
  await tester.pumpAndSettle();
  await tester.tap(find.text('\u0110\u0103ng xu\u1ea5t'));
  await tester.pumpAndSettle();

  expect(repository.signOutCalls, 1);
  expect(find.text('login-screen'), findsOneWidget);
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.failSignOut = false});

  final bool failSignOut;
  int signOutCalls = 0;

  @override
  Future<void> clearLocalSession() async {}

  @override
  Future<User> getCurrentUser() async => const User(
    id: '1',
    email: 'user@example.test',
    fullName: 'Test User',
    roles: [],
  );

  @override
  Future<User> updateCurrentUser({
    String? displayName,
    String? phoneNumber,
  }) async => getCurrentUser();

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (failSignOut) throw StateError('remote logout unavailable');
  }

  @override
  Future<User> signInWithGoogle() async => getCurrentUser();
}

class _FakeEmployeeRepository implements EmployeeRepository {
  @override
  Future<Map<String, dynamic>> getEmployeeProfile() async => const {
    'fullName': 'Test Employee',
    'employeeCode': 'IT-001',
    'jobTitle': 'Crew',
    'employmentStatus': 'ACTIVE',
  };

  @override
  Future<List<Map<String, dynamic>>> getMyTraining() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
