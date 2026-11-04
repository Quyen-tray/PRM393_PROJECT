import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hrm_coffee_shop_flutter/core/presentation/resource_widgets.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/data/session_controller.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/presentation/record_form.dart';
import 'package:hrm_coffee_shop_flutter/features/notifications/presentation/notification_target.dart';

const blockerTitles = {
  'PENDING_ADJUSTMENT': 'Điều chỉnh công đang chờ',
  'PENDING_OVERTIME': 'Tăng ca chưa duyệt',
  'UNRESOLVED_EXCEPTION': 'Giải trình chưa xử lý',
  'MISSING_CHECK_OUT': 'Công thiếu giờ ra',
  'MISSING_ABSENCE_REQUEST': 'Ca vắng chưa có đơn',
  'PENDING_ABSENCE': 'Ca vắng chờ xác nhận',
  'REJECTED_ABSENCE': 'Ca vắng có đơn bị từ chối',
};

class PayrollDetail extends ConsumerWidget {
  const PayrollDetail(this.row, {super.key});
  final Json row;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = row['periodId'];
    final user = ref.watch(sessionProvider).user!;
    return ResourceView(
      ResourceQuery('/payroll-periods/$id/readiness'),
      builder: (data) {
        final ready = json(data);
        final stage = ready['periodStatus'];
        final today = DateTime.now()
            .toUtc()
            .add(const Duration(hours: 7))
            .toIso8601String()
            .substring(0, 10);
        final ended = row['endDate'] is String &&
            (row['endDate'] as String).compareTo(today) < 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionTitle('Sẵn sàng chốt công'),
            const Text(
                'Kỳ công dùng để đối soát và khóa dữ liệu chấm công. Xử lý các vướng mắc bên dưới, quản lý xác nhận, sau đó người có quyền chốt kỳ công.'),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              Chip(
                  avatar: Icon(
                      stage == 'HR_REVIEW' || stage == 'LOCKED'
                          ? Icons.check_circle
                          : Icons.looks_one_outlined,
                      size: 18),
                  label: const Text('1. Quản lý xác nhận')),
              Chip(
                  avatar: Icon(
                      stage == 'LOCKED' ? Icons.lock : Icons.looks_two_outlined,
                      size: 18),
                  label: const Text('2. Chốt và khóa kỳ công')),
            ]),
            Text(
                ready['canFinalize'] == true
                    ? 'Không còn vướng mắc cần xử lý.'
                    : 'Cần xử lý các mục sau trước khi khóa kỳ công.',
                style: Theme.of(context).textTheme.titleMedium),
            if (ready['canFinalize'] == true && stage != 'LOCKED')
              const Text(
                'Đã xử lý các vướng mắc. Quản lý cần xác nhận và kỳ công phải kết thúc trước khi chốt.',
              ),
            for (final blocker in ResourcePage.parse(ready['blockers']).items)
              ExpansionTile(
                title: Text(
                  '${blockerTitles[blocker['type']] ?? blocker['type']} · ${blocker['count']}',
                ),
                children: [
                  Wrap(
                    spacing: 8,
                    children: (blocker['ids'] as List? ?? [])
                        .map(
                          (id) => OutlinedButton(
                            onPressed: () {
                              final route = notificationRoute({
                                'relatedEntityType': blocker['entityType'] ??
                                    switch (blocker['type']) {
                                      'PENDING_ADJUSTMENT' =>
                                        'AttendanceAdjustmentRequest',
                                      'PENDING_OVERTIME' => 'OvertimeRequest',
                                      'UNRESOLVED_EXCEPTION' =>
                                        'AttendanceExceptionRequest',
                                      'MISSING_CHECK_OUT' => 'Attendance',
                                      _ => 'ShiftAssignment',
                                    },
                                'relatedEntityId': id,
                              }, user);
                              if (route != null) context.push(route);
                            },
                            child: Text('Mở hồ sơ #$id'),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            if (user.manager && ['OPEN', 'MANAGER_REVIEW'].contains(stage))
              OutlinedButton(
                onPressed: () => editRecord(
                  context,
                  ref,
                  title: 'Quản lý xác nhận kỳ công',
                  fields: const [],
                  path: '/payroll-periods/$id/manager-confirm',
                ),
                child: const Text('Quản lý xác nhận'),
              ),
            if (user.manager &&
                stage != 'LOCKED' &&
                ResourcePage.parse(ready['blockers']).items.any((b) => [
                      'MISSING_ABSENCE_REQUEST',
                      'REJECTED_ABSENCE'
                    ].contains(b['type'])))
              _GenerateAbsences(id),
            if (ResourcePage.parse(ready['blockers'])
                .items
                .any((b) => b['type'] == 'PENDING_ABSENCE'))
              TextButton.icon(
                  onPressed: () =>
                      context.push('/module/explanations?status=PENDING'),
                  icon: const Icon(Icons.pending_actions),
                  label: const Text('Mở danh sách ca vắng chờ duyệt')),
            if (user.has('PAYROLL_FINALIZE') &&
                ready['canFinalize'] == true &&
                stage == 'HR_REVIEW' &&
                ended)
              OutlinedButton(
                onPressed: () => editRecord(
                  context,
                  ref,
                  title: 'Nhân sự chốt kỳ công',
                  fields: const [],
                  path: '/payroll-periods/$id/hr-finalize',
                ),
                child: const Text('Chốt và khóa kỳ công'),
              ),
            if (user.has('PAYROLL_REOPEN') && row['status'] == 'FINALIZED')
              OutlinedButton(
                onPressed: () => editRecord(
                  context,
                  ref,
                  title: 'Mở lại kỳ công',
                  fields: const [
                    FieldSpec(
                      'reason',
                      'Lý do mở lại',
                      kind: FieldKind.multiline,
                      required: true,
                    ),
                  ],
                  path: '/payroll-periods/$id/reopen',
                ),
                child: const Text('Mở lại kỳ công'),
              ),
          ],
        );
      },
    );
  }
}

class _GenerateAbsences extends ConsumerStatefulWidget {
  const _GenerateAbsences(this.id);
  final Object id;
  @override
  ConsumerState<_GenerateAbsences> createState() => _GenerateAbsencesState();
}

class _GenerateAbsencesState extends ConsumerState<_GenerateAbsences> {
  bool busy = false;
  Object? error;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        OutlinedButton.icon(
            icon: const Icon(Icons.playlist_add),
            label: Text(
                busy ? 'Đang tạo đơn…' : 'Tạo đơn cho các ca vắng còn thiếu'),
            onPressed: busy
                ? null
                : () async {
                    setState(() {
                      busy = true;
                      error = null;
                    });
                    try {
                      final result = json(await ref
                          .read(resourceRepositoryProvider)
                          .write('POST',
                              '/payroll-periods/${widget.id}/absence-requests'));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                                'Đã tạo ${result['created'] ?? 0} đơn. Tiếp tục duyệt trong mục Giải trình.'),
                            action: SnackBarAction(
                                label: 'Mở duyệt',
                                onPressed: () => context.push(
                                    '/module/explanations?status=PENDING'))));
                      }
                      ref.read(dataRevisionProvider.notifier).changed();
                    } catch (e) {
                      if (mounted) setState(() => error = e);
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  }),
        if (error != null) ErrorPanel(error!),
      ]);
}
