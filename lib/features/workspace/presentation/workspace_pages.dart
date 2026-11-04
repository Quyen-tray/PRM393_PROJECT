import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/presentation/resource_widgets.dart';
import '../../auth/data/session_controller.dart';
import '../../operations/data/operations_repository.dart';
import '../../operations/domain/module_registry.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return Scaffold(
        body: Center(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Card(
                        child: Padding(
                            padding: const EdgeInsets.all(30),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Icon(Icons.coffee,
                                      size: 54,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary),
                                  const SizedBox(height: 20),
                                  Text('HRM Coffee Shop',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 10),
                                  const Text(
                                      'Một nơi cho lịch làm, chấm công và công việc tại cửa hàng.',
                                      textAlign: TextAlign.center),
                                  const SizedBox(height: 28),
                                  if (session.error != null) ...[
                                    ErrorPanel(session.error!,
                                        retry: () => ref
                                            .read(sessionProvider.notifier)
                                            .restore()),
                                    const SizedBox(height: 16)
                                  ],
                                  FilledButton.icon(
                                      onPressed: session.loading
                                          ? null
                                          : () => ref
                                              .read(sessionProvider.notifier)
                                              .googleLogin(),
                                      icon: session.loading
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2))
                                          : const Icon(Icons.login),
                                      label: Text(session.loading
                                          ? 'Đang xác thực…'
                                          : 'Đăng nhập bằng Google')),
                                  const SizedBox(height: 16),
                                  const Text(
                                      'Dùng tài khoản đã được quản trị viên cấp. Liên hệ quản lý nếu bạn chưa có quyền truy cập.',
                                      style: TextStyle(fontSize: 12),
                                      textAlign: TextAlign.center),
                                ])))))));
  }
}

class WorkspaceSelector extends ConsumerWidget {
  const WorkspaceSelector({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).user;
    return Scaffold(
        appBar: AppBar(title: const Text('Chọn không gian làm việc'), actions: [
          TextButton(
              onPressed: () => ref.read(sessionProvider.notifier).logout(),
              child: const Text('Đăng xuất'))
        ]),
        body: PageBody(children: [
          const SizedBox(height: 28),
          Text('Xin chào, ${user?.name ?? ''}',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 10),
          const Text('Chọn nhóm công việc bạn muốn thực hiện.'),
          ...?user?.workspaces.map((w) => Card(
              child: ListTile(
                  contentPadding: const EdgeInsets.all(20),
                  leading: Icon(workspaceIcon(w), size: 32),
                  title: Text(w.label),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () async {
                    await ref.read(sessionProvider.notifier).select(w);
                  }))),
          if (user != null && user.workspaces.isEmpty)
            const EmptyPanel(
                message:
                    'Tài khoản chưa được gán workspace. Liên hệ quản trị viên.'),
        ]));
  }
}

IconData workspaceIcon(Workspace w) => switch (w) {
      Workspace.employee => Icons.badge_outlined,
      Workspace.manager => Icons.storefront,
      Workspace.admin => Icons.admin_panel_settings_outlined
    };

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
      ref
          .read(sessionProvider.notifier)
          .loadProfile()
          .catchError((_) {/* Resources retain their own error states. */});
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
          ('/more', Icons.person_outline, 'Cá nhân')
        ],
      Workspace.manager => [
          ('/', Icons.home_outlined, 'Tổng quan'),
          ('/module/employees', Icons.groups_outlined, 'Nhân viên'),
          ('/module/assignments', Icons.calendar_month, 'Lịch ca'),
          ('/tasks', Icons.task_alt, 'Duyệt'),
          ('/more', Icons.menu, 'Khác')
        ],
      Workspace.admin => [
          ('/', Icons.home_outlined, 'Tổng quan'),
          ('/module/accounts', Icons.manage_accounts, 'Tài khoản'),
          ('/tasks', Icons.task_alt, 'Tác vụ'),
          ('/more', Icons.settings_outlined, 'Quản trị')
        ],
    };
    final allowedBottom = bottom
        .where((item) =>
            !item.$1.startsWith('/module/') ||
            module(item.$1.split('/').last).access(user))
        .toList();
    final active =
        allowedBottom.indexWhere((item) => item.$1 == widget.location);
    final segments = Uri.parse(widget.location).pathSegments;
    final current =
        segments.length >= 2 && ['module', 'record'].contains(segments.first)
            ? modules.where((m) => m.key == segments[1]).firstOrNull
            : null;
    final title = widget.location == '/'
        ? 'HRM Coffee Shop'
        : widget.location == '/tasks'
            ? 'Trung tâm công việc'
            : widget.location == '/work'
                ? 'Công việc của tôi'
                : widget.location == '/profile'
                    ? 'Hồ sơ cá nhân'
                    : widget.location == '/attendance/check-in'
                        ? 'Chấm công'
                        : widget.location.startsWith('/quiz/')
                            ? 'Bài kiểm tra'
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
            label: Text(workspace.label, overflow: TextOverflow.ellipsis)));
    final body = Row(children: [
      if (wide)
        SizedBox(
            width: 252,
            child: ColoredBox(
                color: Theme.of(context).colorScheme.surface,
                child: Column(children: [
                  Padding(
                      padding: const EdgeInsets.all(16),
                      child: workspaceChoice()),
                  Expanded(
                      child: ListView(children: [
                    ListTile(
                        leading: const Icon(Icons.home_outlined),
                        title: const Text('Tổng quan'),
                        selected: widget.location == '/',
                        onTap: () => context.go('/')),
                    ListTile(
                        leading: const Icon(Icons.task_alt),
                        title: const Text('Trung tâm công việc'),
                        selected: widget.location == '/tasks',
                        onTap: () => context.go('/tasks')),
                    ...menu.map((m) => ListTile(
                        dense: true,
                        leading: Icon(m.icon),
                        title: Text(m.title),
                        selected: widget.location.contains('/${m.key}'),
                        onTap: () => context.go(m.listRoute))),
                  ])),
                  ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text(user.name),
                      subtitle: const Text('Hồ sơ và tài khoản'),
                      onTap: () => context.push('/profile')),
                  ListTile(
                      leading: const Icon(Icons.logout),
                      title: const Text('Đăng xuất'),
                      onTap: () => ref.read(sessionProvider.notifier).logout()),
                  const SizedBox(height: 12)
                ]))),
      Expanded(child: widget.child)
    ]);
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
                    }),
            actions: [
              if (!wide)
                Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: workspaceChoice()),
              IconButton(
                  tooltip: 'Thông báo',
                  onPressed: () => context.push('/module/notifications'),
                  icon: Consumer(builder: (context, ref, _) {
                    final count = ref
                        .watch(resourceProvider(const ResourceQuery(
                            '/notifications/me/unread-count')))
                        .asData
                        ?.value;
                    final n =
                        (json(count)['unreadCount'] as num?)?.toInt() ?? 0;
                    return Badge(
                        isLabelVisible: n > 0,
                        label: Text('$n'),
                        child: const Icon(Icons.notifications_outlined));
                  }))
            ]),
        body: SafeArea(top: false, child: body),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: active < 0 ? 0 : active,
                onDestinationSelected: (i) => context.go(allowedBottom[i].$1),
                destinations: allowedBottom
                    .map((item) => NavigationDestination(
                        icon: Icon(item.$2), label: item.$3))
                    .toList()));
  }
}

class ModuleMenu extends ConsumerWidget {
  const ModuleMenu({this.workOnly = false, super.key});
  final bool workOnly;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final user = s.user!;
    final visible = modules
        .where((m) =>
            m.visible(user, s.workspace!) &&
            (!workOnly || m.group == 'Công việc'))
        .toList();
    final groups = visible.map((m) => m.group).toSet();
    return PageBody(children: [
      for (final group in groups) ...[
        SectionTitle(group),
        ...visible.where((m) => m.group == group).map((m) => Card(
            child: ListTile(
                leading: Icon(m.icon),
                title: Text(m.title),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(m.listRoute))))
      ],
      if (!workOnly) ...[
        const SectionTitle('Tài khoản'),
        Card(
            child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Hồ sơ cá nhân'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/profile'))),
        TextButton.icon(
            onPressed: () => ref.read(sessionProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
            label: const Text('Đăng xuất'))
      ]
    ]);
  }
}
