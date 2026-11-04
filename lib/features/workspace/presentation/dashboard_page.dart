import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/presentation/business_labels.dart';
import '../../../core/presentation/resource_widgets.dart';
import '../../auth/data/session_controller.dart';
import '../../operations/data/operations_repository.dart';
import '../../operations/domain/module_registry.dart';
import '../../operations/presentation/record_form.dart';

const queueRoutes = <String, (String, String)>{
  'devices': ('Thiết bị chờ duyệt', '/module/devices'),
  'explanations': (
    'Giải trình chờ quản lý',
    '/module/explanations?status=PENDING'
  ),
  'overtime': ('Tăng ca chờ duyệt', '/module/overtime?status=PENDING'),
  'adjustmentsAwaitingManager': (
    'Điều chỉnh · bước quản lý',
    '/module/adjustments?status=PENDING_MANAGER'
  ),
  'adjustmentsAwaitingHr': (
    'Điều chỉnh · bước nhân sự',
    '/module/adjustments?status=PENDING_HR'
  ),
  'checklistReviews': ('Checklist chờ duyệt', '/module/checklist-reviews'),
  'trainingReviews': ('Đào tạo cần xác nhận', '/module/training-reviews'),
  'documents': ('Hồ sơ chờ duyệt', '/module/documents'),
  'violations': ('Vi phạm cần xem xét', '/module/violations?status=OPEN'),
  'rewardsAndPenalties': (
    'Đề xuất thưởng / phạt',
    '/module/decisions?status=PENDING_APPROVAL'
  ),
};

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
          Text('Xin chào, ${u.name}',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(s.workspace!.label,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          if (s.workspace == Workspace.employee && u.employeeId != null) ...[
            const SectionTitle('Ca làm và chấm công'),
            ResourceView(const ResourceQuery('/attendance/me/current'),
                builder: (data) {
              final shift = json(data);
              return Card(
                  child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(children: [
                              const Icon(Icons.schedule),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Text(
                                      shift['shiftName'] ??
                                          'Chưa có ca hiện tại',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium)),
                              if (shift['attendanceStatus'] != null)
                                StatusChip(shift['attendanceStatus'])
                            ]),
                            if (data != null) ...[
                              const SizedBox(height: 14),
                              Text(
                                  '${dateText(shift['plannedStartAt'])}\n→ ${dateText(shift['plannedEndAt'])}',
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 10),
                              if ((shift['blockers'] as List? ?? []).isNotEmpty)
                                const Text(
                                    'Mở trang chấm công để xem điều kiện cần xử lý.'),
                              const SizedBox(height: 14),
                              FilledButton.icon(
                                  onPressed: () =>
                                      context.push('/attendance/check-in'),
                                  icon: const Icon(Icons.fingerprint),
                                  label: Text(shift['canCheckOut'] == true
                                      ? 'Check-out'
                                      : 'Check-in · xem điều kiện')),
                            ] else
                              TextButton(
                                  onPressed: () =>
                                      context.push('/module/my-schedule'),
                                  child: const Text(
                                      'Xem lịch làm và gửi giải trình')),
                          ])));
            }),
            ResourceView(const ResourceQuery('/dashboard/employee/overview'),
                builder: (data) {
              final d = json(data);
              return InfoCard({
                'profileStatus': d['profileStatus'],
                'shiftEligibility': d['shiftEligibility']
              }, title: 'Hồ sơ và điều kiện');
            }),
            const SectionTitle('Truy cập nhanh'),
            QuickLinks(const [
              'my-schedule',
              'my-checklists',
              'training',
              'my-documents',
              'my-devices',
              'my-attendance'
            ]),
            const SectionTitle('Checklist cần thực hiện'),
            ResourceView(const ResourceQuery('/checklists/me'),
                builder: (data) {
              final rows = ResourcePage.parse(data).items.take(4);
              return rows.isEmpty
                  ? const EmptyPanel(
                      message: 'Không có checklist cần thực hiện.')
                  : Column(
                      children: rows
                          .map((r) => Card(
                              child: ListTile(
                                  leading: const Icon(Icons.checklist),
                                  title: Text('${r['checklistName']}'),
                                  subtitle: Text(
                                      '${statusLabel(r['status'])} · ${dateText(r['dueAt'])}'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => context.push(
                                      '/record/my-checklists/${r['taskId']}'))))
                          .toList());
            }),
          ],
          if (s.workspace == Workspace.manager &&
              u.has('DASHBOARD_MANAGER')) ...[
            const SectionTitle('Chấm công hôm nay'),
            ResourceView(const ResourceQuery('/dashboard/manager/overview'),
                builder: (data) =>
                    InfoCard(json(json(data)['attendanceToday']))),
            const SectionTitle('Điều phối cửa hàng'),
            QuickLinks([
              'employees',
              'assignments',
              'attendance',
              'checklists',
              'payroll'
            ].where((key) => module(key).access(u)).toList()),
          ],
          if (s.workspace == Workspace.admin) ...[
            const SectionTitle('Hệ thống hiện tại'),
            ResourceView(const ResourceQuery('/dashboard/admin/overview'),
                builder: (data) => LayoutBuilder(builder: (context, size) {
                      final entries = json(data).entries.toList();
                      return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: entries
                              .map((e) => SizedBox(
                                  width: size.maxWidth < 500
                                      ? (size.maxWidth - 12) / 2
                                      : (size.maxWidth - 36) / 4,
                                  child: Card(
                                      child: Padding(
                                          padding: const EdgeInsets.all(18),
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text('${e.value}',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .headlineMedium
                                                        ?.copyWith(
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold)),
                                                Text(
                                                    fieldLabels[e.key] ?? e.key)
                                              ])))))
                              .toList());
                    })),
            const SectionTitle('Cấu hình và quản trị'),
            const QuickLinks([
              'accounts',
              'positions',
              'courses',
              'templates',
              'store-settings',
              'audit'
            ]),
          ],
          const SectionTitle('Tác vụ được giao theo quyền'),
          const TaskQueues(),
        ]);
  }
}

class QuickLinks extends StatelessWidget {
  const QuickLinks(this.keys, {super.key});
  final List<String> keys;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (context, size) => Wrap(
          spacing: 12,
          runSpacing: 12,
          children: keys.map((key) {
            final spec = module(key);
            return SizedBox(
                width: size.maxWidth < 500
                    ? (size.maxWidth - 24) / 3
                    : (size.maxWidth - 36) / 4,
                child: Card(
                    child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => context.push(spec.listRoute),
                        child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 20),
                            child: Column(children: [
                              Icon(spec.icon,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 28),
                              const SizedBox(height: 10),
                              Text(spec.title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12))
                            ])))));
          }).toList()));
}

class TaskQueues extends StatelessWidget {
  const TaskQueues({super.key});
  @override
  Widget build(BuildContext context) =>
      ResourceView(const ResourceQuery('/dashboard/tasks'), builder: (data) {
        final pending = json(json(data)['pending']);
        if (pending.isEmpty) {
          return const EmptyPanel(
              message:
                  'Tài khoản không có tác vụ phê duyệt. Các công việc cá nhân nằm trong không gian Nhân viên.');
        }
        return Column(
            children: pending.entries
                .where((e) => queueRoutes.containsKey(e.key))
                .map((e) {
          final route = queueRoutes[e.key]!;
          return Card(
              child: ListTile(
                  leading: CircleAvatar(child: Text('${e.value}')),
                  title: Text(route.$1),
                  subtitle: Text(e.key.startsWith('adjustments')
                      ? 'Số trường giờ công chờ xử lý'
                      : 'Số hồ sơ chờ xử lý'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(route.$2)));
        }).toList());
      });
}

class TaskPage extends StatelessWidget {
  const TaskPage({super.key});
  @override
  Widget build(BuildContext context) => const PageBody(children: [
        SectionTitle('Trung tâm công việc'),
        Text(
            'Các hàng đợi xuất hiện theo quyền thực tế. Mỗi nghiệp vụ có trạng thái và bước phê duyệt riêng.'),
        SizedBox(height: 12),
        TaskQueues()
      ]);
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = ref.watch(sessionProvider).user!;
    return PageBody(children: [
      ResourceView(const ResourceQuery('/users/me'),
          builder: (data) =>
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                InfoCard(json(data), title: 'Tài khoản cá nhân'),
                TextButton.icon(
                    onPressed: () async {
                      final changed = await editRecord(context, ref,
                          title: 'Cập nhật thông tin cá nhân',
                          fields: const [
                            FieldSpec('displayName', 'Tên hiển thị',
                                required: true),
                            FieldSpec('phoneNumber', 'Số điện thoại')
                          ],
                          initial: json(data),
                          path: '/users/me',
                          method: 'PATCH');
                      if (changed == true) {
                        await ref.read(sessionProvider.notifier).loadProfile();
                      }
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Chỉnh sửa thông tin'))
              ])),
      if (u.employeeId != null)
        ResourceView(const ResourceQuery('/employees/me'),
            builder: (data) => InfoCard(json(data), title: 'Hồ sơ nhân viên')),
      const SectionTitle('Vai trò hiện tại'),
      Wrap(
          spacing: 8,
          children:
              u.roles.map((r) => Chip(label: Text(roleName(r)))).toList()),
      TextButton.icon(
          onPressed: () => ref.read(sessionProvider.notifier).loadProfile(),
          icon: const Icon(Icons.refresh),
          label: const Text('Tải lại quyền truy cập')),
      TextButton.icon(
          onPressed: () => ref.read(sessionProvider.notifier).logout(),
          icon: const Icon(Icons.logout),
          label: const Text('Đăng xuất')),
    ]);
  }
}
