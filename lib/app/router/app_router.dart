import 'package:flutter/material.dart';
import '../../features/employees/presentation/employee_related_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/data/session_controller.dart';
import '../../features/attendance/presentation/check_in_screen.dart';
import 'package:hrm_coffee_shop_flutter/app/router/module_registry.dart';
import 'package:hrm_coffee_shop_flutter/features/workspace/presentation/module_page.dart';
import 'package:hrm_coffee_shop_flutter/features/workspace/presentation/record_detail_page.dart';
import 'package:hrm_coffee_shop_flutter/features/training/presentation/quiz_page.dart';
import 'package:hrm_coffee_shop_flutter/features/dashboard/presentation/dashboard_page.dart';
import 'package:hrm_coffee_shop_flutter/features/approvals/presentation/approval_center_page.dart';
import 'package:hrm_coffee_shop_flutter/features/profile/presentation/profile_screen.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/presentation/login_screen.dart';
import 'package:hrm_coffee_shop_flutter/features/workspace/presentation/workspace_selector.dart';
import 'package:hrm_coffee_shop_flutter/features/workspace/presentation/app_shell.dart';
import 'package:hrm_coffee_shop_flutter/features/workspace/presentation/module_menu.dart';
import '../../features/workspace/presentation/refresh_on_return.dart';
import 'navigation_observer.dart';

class RouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = RouterRefresh();
  ref.onDispose(refresh.dispose);
  ref.listen(sessionProvider, (context, state) => refresh.refresh());
  final router = GoRouter(
    refreshListenable: refresh,
    initialLocation: '/',
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final path = state.uri.path;
      final authPaths = ['/login', '/loading', '/workspaces'];
      final destination = authPaths.contains(path)
          ? state.uri.queryParameters['from'] ?? '/'
          : state.uri.toString();
      String gate(String route) =>
          '$route?from=${Uri.encodeQueryComponent(destination)}';
      if (session.loading) {
        return path == '/loading' ? null : gate('/loading');
      }
      if (session.user == null) {
        return path == '/login' ? null : gate('/login');
      }
      if (session.workspace == null) {
        return path == '/workspaces' ? null : gate('/workspaces');
      }
      if (authPaths.contains(path)) {
        return '/';
      }
      // Module routes keep their URL on denial, so the user sees 403 and can navigate back.
      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Không tìm thấy trang')),
      body: Center(
        child: FilledButton(
          onPressed: () => context.go('/'),
          child: const Text('Về tổng quan'),
        ),
      ),
    ),
    routes: [
      GoRoute(
        path: '/loading',
        builder: (context, state) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', redirect: (context, state) => '/login'),
      GoRoute(
        path: '/workspaces',
        builder: (context, state) => const WorkspaceSelector(),
      ),
      ShellRoute(
        observers: [ref.read(shellObserverProvider)],
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const RefreshOnReturn(child: DashboardPage()),
          ),
          GoRoute(
            path: '/tasks',
            builder: (context, state) => const ApprovalCenterPage(),
          ),
          GoRoute(
            path: '/work',
            builder: (context, state) => const ModuleMenu(workOnly: true),
          ),
          GoRoute(
            path: '/more',
            builder: (context, state) => const ModuleMenu(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
              path: '/employee-records/:employeeId/:section',
              builder: (_, state) => SessionAccess(
                  allow: (u) => u.has('EMPLOYEE_VIEW'),
                  child: EmployeeRelatedPage(
                      state.pathParameters['employeeId']!,
                      state.pathParameters['section']!))),
          GoRoute(
            path: '/attendance/check-in',
            builder: (context, state) {
              final assignmentId = int.tryParse(
                  state.uri.queryParameters['assignmentId'] ?? '');
              return SessionAccess(
                allow: employee,
                child: RefreshOnReturn(
                    child: CheckInScreen(assignmentId: assignmentId)),
              );
            },
          ),
          GoRoute(
            path: '/quiz/:courseId',
            builder: (_, state) => SessionAccess(
              allow: employee,
              child: QuizPage(state.pathParameters['courseId']!),
            ),
          ),
          GoRoute(
            path: '/module/:module',
            builder: (_, state) {
              final spec = modules
                  .where((m) => m.key == state.pathParameters['module'])
                  .firstOrNull;
              return spec != null
                  ? SessionAccess(
                      allow: spec.access,
                      child: ModulePage(
                        spec,
                        key: ValueKey(state.uri.toString()),
                        initialStatus: state.uri.queryParameters['status'],
                      ),
                    )
                  : const ForbiddenScreen();
            },
          ),
          GoRoute(
            path: '/record/:module/:id',
            builder: (_, state) {
              final spec = modules
                  .where((m) => m.key == state.pathParameters['module'])
                  .firstOrNull;
              // Record-specific scope is checked by the GET detail service (owner/reviewer).
              return spec != null
                  ? SessionAccess(
                      allow: (_) => true,
                      child: RecordDetailPage(
                        spec,
                        state.pathParameters['id']!,
                      ),
                    )
                  : const ForbiddenScreen();
            },
          ),
        ],
      ),
      GoRoute(
        path: '/manager/employees',
        redirect: (context, state) => '/module/employees',
      ),
      GoRoute(
        path: '/manager/employees/:employeeCode',
        redirect: (_, s) =>
            '/module/employees?q=${Uri.encodeQueryComponent(s.pathParameters['employeeCode']!)}',
      ),
      GoRoute(
        path: '/manager/schedule',
        redirect: (context, state) => '/module/assignments',
      ),
      GoRoute(
        path: '/manager/approvals',
        redirect: (context, state) => '/tasks',
      ),
      GoRoute(
        path: '/manager/checklists/approvals',
        redirect: (context, state) => '/module/checklist-reviews',
      ),
      GoRoute(
        path: '/manager/reports/attendance',
        redirect: (context, state) => '/module/reports-attendance',
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

// Route builders are not guaranteed to run again when permissions change while
// the URL stays the same. Keep access checks subscribed to the live session.
class SessionAccess extends ConsumerWidget {
  const SessionAccess({required this.allow, required this.child, super.key});
  final Access allow;
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).user;
    return user != null && allow(user)
        ? KeyedSubtree(key: ValueKey(user.id), child: child)
        : const ForbiddenScreen();
  }
}

class ForbiddenScreen extends StatelessWidget {
  const ForbiddenScreen({super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 52),
              const SizedBox(height: 14),
              Text(
                '403 · Không đủ quyền',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Tài khoản hiện tại không có quyền mở chức năng này.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Về tổng quan'),
              ),
            ],
          ),
        ),
      );
}
