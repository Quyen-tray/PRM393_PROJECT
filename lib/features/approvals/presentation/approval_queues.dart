import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hrm_coffee_shop_flutter/core/presentation/resource_widgets.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';
import 'package:hrm_coffee_shop_flutter/features/approvals/domain/approval_routes.dart';

class ApprovalQueues extends StatelessWidget {
  const ApprovalQueues({super.key});
  @override
  Widget build(BuildContext context) => ResourceView(
        const ResourceQuery('/dashboard/tasks'),
        builder: (data) {
          final pending = json(json(data)['pending']);
          if (pending.isEmpty) {
            return const EmptyPanel(
              message:
                  'Tài khoản không có tác vụ phê duyệt. Các công việc cá nhân nằm trong không gian Nhân viên.',
            );
          }
          return Column(
            children: pending.entries
                .where((e) => approvalQueueRoutes.containsKey(e.key))
                .map((e) {
              final route = approvalQueueRoutes[e.key]!;
              final count = int.tryParse('${e.value}') ?? 0;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text('$count')),
                  title: Text(route.$1),
                  subtitle: Text(e.key.startsWith('adjustments')
                      ? '$count trường giờ công chờ xử lý'
                      : '$count hồ sơ chờ xử lý'),
                  trailing: TextButton.icon(
                    onPressed: () => context.push(route.$2),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Mở danh sách'),
                  ),
                  onTap: () => context.push(route.$2),
                ),
              );
            }).toList(),
          );
        },
      );
}
