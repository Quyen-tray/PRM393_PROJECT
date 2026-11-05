import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hrm_coffee_shop_flutter/core/presentation/resource_widgets.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/data/session_controller.dart';
import 'package:hrm_coffee_shop_flutter/app/router/module_registry.dart';

class ModuleMenu extends ConsumerWidget {
  const ModuleMenu({this.workOnly = false, super.key});
  final bool workOnly;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final user = s.user!;
    final visible = modules
        .where(
          (m) =>
              m.visible(user, s.workspace!) &&
              (!workOnly || m.group == 'Công việc'),
        )
        .toList();
    final groups = visible.map((m) => m.group).toSet();
    return PageBody(
      children: [
        for (final group in groups) ...[
          SectionTitle(group),
          ...visible.where((m) => m.group == group).map(
                (m) => Card(
                  child: ListTile(
                    leading: Icon(m.icon),
                    title: Text(m.title),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(m.listRoute),
                  ),
                ),
              ),
        ],
        if (!workOnly) ...[
          const SectionTitle('Tài khoản'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Hồ sơ cá nhân'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/profile'),
            ),
          ),
          TextButton.icon(
            onPressed: () => ref.read(sessionProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
            label: const Text('Đăng xuất'),
          ),
        ],
      ],
    );
  }
}
