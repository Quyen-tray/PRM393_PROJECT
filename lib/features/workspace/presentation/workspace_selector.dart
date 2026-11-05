import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_coffee_shop_flutter/core/presentation/resource_widgets.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/data/session_controller.dart';
import 'package:hrm_coffee_shop_flutter/features/workspace/presentation/workspace_icon.dart';

class WorkspaceSelector extends ConsumerWidget {
  const WorkspaceSelector({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn không gian làm việc'),
        actions: [
          TextButton(
            onPressed: () => ref.read(sessionProvider.notifier).logout(),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
      body: PageBody(
        children: [
          const SizedBox(height: 28),
          Text(
            'Xin chào, ${user?.name ?? ''}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          const Text('Chọn nhóm công việc bạn muốn thực hiện.'),
          ...?user?.workspaces.map(
            (w) => Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(20),
                leading: Icon(workspaceIcon(w), size: 32),
                title: Text(w.label),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () async {
                  await ref.read(sessionProvider.notifier).select(w);
                },
              ),
            ),
          ),
          if (user != null && user.workspaces.isEmpty)
            const EmptyPanel(
              message:
                  'Tài khoản chưa được gán workspace. Liên hệ quản trị viên.',
            ),
        ],
      ),
    );
  }
}
