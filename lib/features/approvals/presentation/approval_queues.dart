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
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text('${e.value}')),
                  title: Text(route.$1),
                  subtitle: Text(
                    e.key.startsWith('adjustments')
                        ? 'Số trường giờ công chờ xử lý'
                        : 'Số hồ sơ chờ xử lý',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(route.$2),
                ),
              );
            }).toList(),
          );
        },
      );
}
