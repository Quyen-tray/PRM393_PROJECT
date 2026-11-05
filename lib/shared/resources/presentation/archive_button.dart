import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/resource_repository.dart';
import '../domain/module_spec.dart';
import '../../../features/auth/data/session_controller.dart';
import '../../../core/presentation/resource_widgets.dart';

class ArchiveButton extends ConsumerWidget {
  const ArchiveButton(this.spec, this.row, {super.key});
  final ModuleSpec spec;
  final Json row;
  static const paths = {
    'accounts': '/admin/users',
    'courses': '/admin/training/courses',
    'templates': '/admin/checklist-templates',
    'shifts': '/work-shifts',
    'skills': '/admin/skills',
    'reminder-rules': '/admin/reminder-rules'
  };
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).user!;
    if (!user.admin ||
        !paths.containsKey(spec.key) ||
        row['isActive'] == false ||
        row['status'] == 'INACTIVE') {
      return const SizedBox.shrink();
    }
    final own = spec.key == 'accounts' && '${row['userId']}' == '${user.id}';
    final key = 'archive-${spec.key}-${recordId(spec, row)}';
    final operation = ref.watch(operationProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextButton.icon(
          onPressed: own || operation.busy.contains(key)
              ? null
              : () async {
                  final approved = await showDialog<bool>(
                      context: context,
                      builder: (dialog) => AlertDialog(
                            title: Text(spec.key == 'accounts'
                                ? 'Lưu trữ tài khoản?'
                                : 'Xóa khỏi danh mục đang sử dụng?'),
                            content: Text(spec.key == 'accounts'
                                ? 'Tài khoản sẽ bị ngừng truy cập. Hồ sơ và lịch sử thao tác vẫn được giữ lại.'
                                : 'Mục này sẽ ngừng được sử dụng cho nghiệp vụ mới. Các ca, bài kiểm tra và hồ sơ đã phát sinh vẫn giữ nguyên lịch sử.'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(dialog, false),
                                  child: const Text('Hủy')),
                              FilledButton(
                                  onPressed: () => Navigator.pop(dialog, true),
                                  child: const Text('Xác nhận ngừng sử dụng'))
                            ],
                          ));
                  if (approved != true) return;
                  final ok = await ref.read(operationProvider.notifier).run(key,
                      () async {
                    await ref.read(resourceRepositoryProvider).write(
                        'DELETE', '${paths[spec.key]}/${recordId(spec, row)}');
                  });
                  if (ok && context.mounted) context.go(spec.listRoute);
                },
          icon: const Icon(Icons.archive_outlined),
          label: Text(own
              ? 'Không thể lưu trữ tài khoản đang đăng nhập'
              : 'Ngừng sử dụng / lưu trữ')),
      if (operation.errors[key] != null) ErrorPanel(operation.errors[key]!),
    ]);
  }
}
