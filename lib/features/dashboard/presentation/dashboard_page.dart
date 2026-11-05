import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hrm_coffee_shop_flutter/core/presentation/business_labels.dart';
import 'package:hrm_coffee_shop_flutter/core/presentation/resource_widgets.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/data/session_controller.dart';
import 'package:hrm_coffee_shop_flutter/app/router/module_registry.dart';
import 'package:hrm_coffee_shop_flutter/features/dashboard/presentation/widgets/dashboard_quick_links.dart';
import 'widgets/manager_insights.dart';
import 'package:hrm_coffee_shop_flutter/features/approvals/presentation/approval_queues.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final u = s.user!;
    return PageBody(
      onRefresh: () async {
        await ref.read(sessionProvider.notifier).loadProfile();
        ref.read(dataRevisionProvider.notifier).changed();
      },
      children: [
        const SizedBox(height: 10),
        Text(
          'Xin chào, ${u.name}',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          s.workspace!.label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        if (s.workspace == Workspace.employee && u.employeeId != null) ...[
          const SectionTitle('Ca làm và chấm công'),
          ResourceView(
            const ResourceQuery('/attendance/me/current'),
            builder: (data) {
              final shift = json(data);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.schedule),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              shift['shiftName'] ?? 'Chưa có ca hiện tại',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (shift['attendanceStatus'] != null)
                            StatusChip(shift['attendanceStatus']),
                        ],
                      ),
                      if (data != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          '${dateText(shift['plannedStartAt'])}\n→ ${dateText(shift['plannedEndAt'])}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if ((shift['blockers'] as List? ?? []).isNotEmpty)
                          const Text(
                            'Mở trang chấm công để xem điều kiện cần xử lý.',
                          ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: () => context.push('/attendance/check-in'),
                          icon: const Icon(Icons.fingerprint),
                          label: Text(
                            shift['attendanceId'] != null &&
                                    !['CHECKED_OUT', 'FINALIZED']
                                        .contains(shift['attendanceStatus'])
                                ? 'Check-out'
                                : 'Check-in · xem điều kiện',
                          ),
                        ),
                      ] else
                        TextButton(
                          onPressed: () => context.push('/module/my-schedule'),
                          child: const Text('Xem lịch làm và gửi giải trình'),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          ResourceView(
            const ResourceQuery('/dashboard/employee/overview'),
            builder: (data) {
              final d = json(data);
              return InfoCard({
                'profileStatus': d['profileStatus'],
                'shiftEligibility': d['shiftEligibility'],
              }, title: 'Hồ sơ và điều kiện');
            },
          ),
          const SectionTitle('Truy cập nhanh'),
          DashboardQuickLinks(const [
            'my-schedule',
            'my-checklists',
            'training',
            'my-documents',
            'my-devices',
            'my-attendance',
          ]),
          const SectionTitle('Checklist cần thực hiện'),
          ResourceView(
            const ResourceQuery('/checklists/me'),
            builder: (data) {
              final rows = ResourcePage.parse(data).items.take(4);
              return rows.isEmpty
                  ? const EmptyPanel(
                      message: 'Không có checklist cần thực hiện.',
                    )
                  : Column(
                      children: rows
                          .map(
                            (r) => Card(
                              child: ListTile(
                                leading: const Icon(Icons.checklist),
                                title: Text('${r['checklistName']}'),
                                subtitle: Text(
                                  '${statusLabel(r['status'])} · ${dateText(r['dueAt'])}',
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => context.push(
                                  '/record/my-checklists/${r['taskId']}',
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    );
            },
          ),
        ],
        if (s.workspace == Workspace.manager && u.has('DASHBOARD_MANAGER')) ...[
          const SectionTitle('Điều phối cửa hàng'),
          DashboardQuickLinks(
            [
              'employees',
              'assignments',
              'attendance',
              'checklists',
              'payroll',
            ].where((key) => module(key).access(u)).toList(),
          ),
          const ManagerInsights(),
        ],
        if (s.workspace == Workspace.admin) ...[
          const SectionTitle('Hệ thống hiện tại'),
          ResourceView(
            const ResourceQuery('/dashboard/admin/overview'),
            builder: (data) => LayoutBuilder(
              builder: (context, size) {
                final entries = json(data).entries.toList();
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: entries
                      .map(
                        (e) => SizedBox(
                          width: size.maxWidth < 500
                              ? (size.maxWidth - 12) / 2
                              : (size.maxWidth - 36) / 4,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${e.value}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  Text(fieldLabels[e.key] ?? e.key),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ),
          const SectionTitle('Cấu hình và quản trị'),
          const DashboardQuickLinks([
            'accounts',
            'positions',
            'courses',
            'templates',
            'store-settings',
            'audit',
          ]),
        ],
        const SectionTitle('Tác vụ được giao theo quyền'),
        const ApprovalQueues(),
      ],
    );
  }
}
