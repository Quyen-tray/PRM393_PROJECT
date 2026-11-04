import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/data/session_controller.dart';
import 'package:hrm_coffee_shop_flutter/app/router/module_registry.dart';
import 'package:hrm_coffee_shop_flutter/features/workspace/presentation/workspace_icon.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.child, required this.location, super.key});
  final Widget child;
  final String location;
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(sessionProvider.notifier).loadProfile().catchError((_) {
        /* Resources retain their own error states. */
      });
      ref.read(dataRevisionProvider.notifier).changed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final user = session.user;
    final workspace = session.workspace;
    if (user == null || workspace == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final menu = modules.where((m) => m.visible(user, workspace)).toList();
    final bottom = switch (workspace) {
      Workspace.employee => [
          ('/', Icons.home_outlined, 'Tổng quan'),
          ('/module/my-schedule', Icons.calendar_month_outlined, 'Lịch làm'),
          ('/work', Icons.checklist, 'Công việc'),
          ('/more', Icons.person_outline, 'Cá nhân'),
        ],
      Workspace.manager => [
          ('/', Icons.home_outlined, 'Tổng quan'),
          ('/module/employees', Icons.groups_outlined, 'Nhân viên'),
          ('/module/assignments', Icons.calendar_month, 'Lịch ca'),
          ('/tasks', Icons.task_alt, 'Duyệt'),
          ('/more', Icons.menu, 'Khác'),
        ],
      Workspace.admin => [
          ('/', Icons.home_outlined, 'Tổng quan'),
          ('/module/accounts', Icons.manage_accounts, 'Tài khoản'),
          ('/tasks', Icons.task_alt, 'Tác vụ'),
          ('/more', Icons.settings_outlined, 'Quản trị'),
        ],
    };
    final allowedBottom = bottom
        .where(
          (item) =>
              !item.$1.startsWith('/module/') ||
              module(item.$1.split('/').last).access(user),
        )
        .toList();
    final active = allowedBottom.indexWhere(
      (item) => item.$1 == widget.location,
    );
    final segments = Uri.parse(widget.location).pathSegments;
    final current =
        segments.length >= 2 && ['module', 'record'].contains(segments.first)
            ? modules.where((m) => m.key == segments[1]).firstOrNull
            : null;
    final title = widget.location == '/'
        ? 'Tổng quan'
        : widget.location == '/tasks'
            ? 'Trung tâm công việc'
            : widget.location.startsWith('/employee-records/')
                ? 'Hồ sơ nhân viên'
                : widget.location == '/work'
                    ? 'Công việc của tôi'
                    : widget.location == '/profile'
                        ? 'Hồ sơ cá nhân'
                        : widget.location == '/attendance/check-in'
                            ? 'Chấm công'
                            : widget.location.startsWith('/quiz/')
                                ? 'Bài kiểm tra'
                                : widget.location == '/more'
                                    ? (workspace == Workspace.admin
                                        ? 'Quản trị'
                                        : workspace == Workspace.employee
                                            ? 'Cá nhân'
                                            : 'Chức năng khác')
                                    : current?.title ?? 'Không gian làm việc';
    Widget workspaceChoice() => PopupMenuButton<Workspace>(
          tooltip: 'Đổi không gian làm việc',
          initialValue: workspace,
          onSelected: (w) async {
            await ref.read(sessionProvider.notifier).select(w);
            ref.read(dataRevisionProvider.notifier).changed();
            if (context.mounted) context.go('/');
          },
          itemBuilder: (_) => user.workspaces
              .map((w) => PopupMenuItem(value: w, child: Text(w.label)))
              .toList(),
          child: Chip(
            avatar: Icon(workspaceIcon(workspace), size: 17),
            label: Text(
                wide
                    ? workspace.label
                    : switch (workspace) {
                        Workspace.admin => 'Admin',
                        Workspace.manager => 'Quản lý',
                        Workspace.employee => 'Nhân viên'
                      },
                overflow: TextOverflow.ellipsis),
          ),
        );
    final body = Row(
      children: [
        if (wide)
          SizedBox(
            width: 252,
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: workspaceChoice(),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.home_outlined),
                          title: const Text('Tổng quan'),
                          selected: widget.location == '/',
                          onTap: () => context.go('/'),
                        ),
                        ListTile(
                          leading: const Icon(Icons.task_alt),
                          title: const Text('Trung tâm công việc'),
                          selected: widget.location == '/tasks',
                          onTap: () => context.go('/tasks'),
                        ),
                        ...menu.map(
                          (m) => ListTile(
                            dense: true,
                            leading: Icon(m.icon),
                            title: Text(m.title),
                            selected: widget.location.contains('/${m.key}'),
                            onTap: () => context.go(m.listRoute),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(user.name),
                    subtitle: const Text('Hồ sơ và tài khoản'),
                    onTap: () => context.push('/profile'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Đăng xuất'),
                    onTap: () => ref.read(sessionProvider.notifier).logout(),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
        leading: widget.location == '/' ||
                widget.location == '/more' ||
                widget.location == '/work' ||
                widget.location == '/tasks'
            ? null
            : IconButton(
                tooltip: 'Quay lại',
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                },
              ),
        actions: [
          if (!wide)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: workspaceChoice(),
            ),
          IconButton(
            tooltip: 'Thông báo',
            onPressed: () => context.push('/module/notifications'),
            icon: Consumer(
              builder: (context, ref, _) {
                final count = ref
                    .watch(
                      resourceProvider(
                        const ResourceQuery('/notifications/me/unread-count'),
                      ),
                    )
                    .asData
                    ?.value;
                final n = (json(count)['unreadCount'] as num?)?.toInt() ?? 0;
                return Badge(
                  isLabelVisible: n > 0,
                  label: Text('$n'),
                  child: const Icon(Icons.notifications_outlined),
                );
              },
            ),
          ),
        ],
      ),
      body: SafeArea(top: false, child: body),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: active < 0 ? 0 : active,
              onDestinationSelected: (i) => context.go(allowedBottom[i].$1),
              destinations: allowedBottom
                  .map(
                    (item) => NavigationDestination(
                      icon: Icon(item.$2),
                      label: item.$3,
                    ),
                  )
                  .toList(),
            ),
    );
  }
}
