import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/presentation/business_labels.dart';
import '../../../core/presentation/resource_widgets.dart';
import '../../auth/data/session_controller.dart';
import '../data/operations_repository.dart';
import '../domain/module_registry.dart';
import 'record_form.dart';
import 'specialized_pages.dart';

class ModulePage extends ConsumerStatefulWidget {
  const ModulePage(this.spec, {this.initialStatus, super.key});
  final ModuleSpec spec;
  final String? initialStatus;
  @override
  ConsumerState<ModulePage> createState() => _ModulePageState();
}

class _ModulePageState extends ConsumerState<ModulePage> {
  int page = 0;
  String status = '', search = '', entityType = '', actionCode = '';
  DateTime? from, to;
  @override
  void initState() {
    super.initState();
    status =
        widget.initialStatus ?? (widget.spec.key == 'devices' ? 'PENDING' : '');
    if (widget.spec.kind == 'schedule') {
      from = DateUtils.dateOnly(DateTime.now())
          .subtract(Duration(days: DateTime.now().weekday - 1));
      to = from!.add(const Duration(days: 6));
    }
  }

  Json get query => {
        'page': page,
        'size': 20,
        if (status.isNotEmpty) 'status': status,
        if (search.isNotEmpty) 'q': search,
        if (entityType.isNotEmpty) 'entityType': entityType,
        if (actionCode.isNotEmpty) 'actionCode': actionCode,
        if (from != null) 'from': from!.toIso8601String().substring(0, 10),
        if (to != null) 'to': to!.toIso8601String().substring(0, 10),
        if (widget.spec.key == 'courses' &&
            ref.read(sessionProvider).user!.admin)
          'includeInactive': true
      };
  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final user = ref.watch(sessionProvider).user!;
    if (spec.kind == 'training') return const TrainingPage();
    if (spec.kind == 'documents') return const MyDocumentsPage();
    if (spec.kind == 'settings') return const StoreSettingsPage();
    final q = ResourceQuery(spec.path, query);
    return PageBody(
        onRefresh: () async {
          ref.invalidate(resourceProvider(q));
          await ref.read(resourceProvider(q).future);
        },
        children: [
          Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(spec.title,
                    style: Theme.of(context).textTheme.headlineSmall),
                if (spec.createPath != null &&
                    (spec.createAccess?.call(user) ?? false))
                  FilledButton.icon(
                      onPressed: () => editRecord(context, ref,
                          title: 'Tạo ${spec.title.toLowerCase()}',
                          fields: spec.fields,
                          path: spec.createPath!),
                      icon: const Icon(Icons.add),
                      label: const Text('Tạo mới')),
                if (spec.key == 'my-devices') const RegisterDeviceButton(),
                if (spec.kind == 'notifications')
                  TextButton.icon(
                      onPressed: () => ref
                              .read(operationProvider.notifier)
                              .run('read-all', () async {
                            await ref
                                .read(operationsRepositoryProvider)
                                .write('POST', '/notifications/read-all');
                          }),
                      icon: const Icon(Icons.done_all),
                      label: const Text('Đọc tất cả')),
              ]),
          const SizedBox(height: 16),
          if (spec.search)
            Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: TextField(
                    decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        labelText: spec.key == 'devices'
                            ? 'Tìm thiết bị, tên hoặc mã nhân viên'
                            : 'Tìm nhân viên',
                        border: const OutlineInputBorder()),
                    onSubmitted: (s) => setState(() {
                          search = s.trim();
                          page = 0;
                        }))),
          if (spec.filters.isNotEmpty)
            Wrap(
                spacing: 8,
                children: ['', ...spec.filters]
                    .map((s) => ChoiceChip(
                        label: Text(s.isEmpty ? 'Tất cả' : statusLabel(s)),
                        selected: status == s,
                        onSelected: (_) => setState(() {
                              status = s;
                              page = 0;
                            })))
                    .toList()),
          if (['schedule', 'report'].contains(spec.kind) ||
              ['my-attendance', 'attendance', 'audit'].contains(spec.key))
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (spec.kind == 'schedule')
                        IconButton(
                            tooltip: 'Tuần trước',
                            onPressed: () => shiftWeek(-7),
                            icon: const Icon(Icons.chevron_left)),
                      OutlinedButton.icon(
                          onPressed: pickRange,
                          icon: const Icon(Icons.date_range),
                          label: Text(from == null
                              ? 'Chọn khoảng ngày'
                              : '${dateText(from!.toIso8601String().substring(0, 10))} → ${dateText(to!.toIso8601String().substring(0, 10))}')),
                      if (spec.kind == 'schedule')
                        IconButton(
                            tooltip: 'Tuần sau',
                            onPressed: () => shiftWeek(7),
                            icon: const Icon(Icons.chevron_right)),
                      if (from != null && spec.kind != 'schedule')
                        TextButton(
                            onPressed: () => setState(() {
                                  from = null;
                                  to = null;
                                  page = 0;
                                }),
                            child: const Text('Xóa bộ lọc'))
                    ])),
          if (spec.key == 'devices')
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                    'Lọc theo trạng thái hoặc tìm thiết bị, tên/mã nhân viên. Mở thiết bị để duyệt, thu hồi hoặc xem lịch sử thiết bị của nhân viên.')),
          if (spec.key.contains('adjustments'))
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                    'Mỗi giờ vào hoặc giờ ra đề nghị là một trường điều chỉnh riêng. Quản lý duyệt trước, nhân sự duyệt và áp dụng sau.')),
          if (spec.key == 'audit') ...[
            TextField(
                decoration: const InputDecoration(
                    labelText: 'Lọc theo đối tượng',
                    hintText: 'Attendance, Employee, …'),
                onSubmitted: (v) => setState(() {
                      entityType = v.trim();
                      page = 0;
                    })),
            TextField(
                decoration: const InputDecoration(
                    labelText: 'Lọc theo mã hành động',
                    hintText: 'ATTENDANCE_CHECK_IN, …'),
                onSubmitted: (v) => setState(() {
                      actionCode = v.trim();
                      page = 0;
                    })),
            AuditExportButton({
              if (from != null)
                'from': from!.toIso8601String().substring(0, 10),
              if (to != null) 'to': to!.toIso8601String().substring(0, 10)
            }),
          ],
          if (spec.kind == 'notifications' &&
              ref.watch(operationProvider).errors['read-all'] != null)
            ErrorPanel(ref.watch(operationProvider).errors['read-all']!),
          ResourceView(q, builder: (data) {
            final result = ResourcePage.parse(data);
            if (spec.kind == 'report' && data is Map) {
              return InfoCard(json(data));
            }
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (result.items.isEmpty) const EmptyPanel(),
                  ...result.items.map((row) => spec.kind == 'report'
                      ? InfoCard(row)
                      : Card(
                          child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              leading: CircleAvatar(
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                  child: Icon(spec.icon, size: 21)),
                              title: Text(rowTitle(spec, row),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 5),
                                  child: Text(rowSubtitle(spec, row))),
                              trailing: spec.kind == 'report'
                                  ? null
                                  : const Icon(Icons.chevron_right),
                              onTap: spec.kind == 'report'
                                  ? null
                                  : () => openRow(row)))),
                  if (result.totalPages > 1)
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      IconButton(
                          tooltip: 'Trang trước',
                          onPressed:
                              page > 0 ? () => setState(() => page--) : null,
                          icon: const Icon(Icons.chevron_left)),
                      Text(
                          'Trang ${page + 1}/${result.totalPages} · ${result.total} bản ghi'),
                      IconButton(
                          tooltip: 'Trang sau',
                          onPressed: page + 1 < result.totalPages
                              ? () => setState(() => page++)
                              : null,
                          icon: const Icon(Icons.chevron_right))
                    ]),
                ]);
          }),
        ]);
  }

  Future<void> openRow(Json row) async {
    final spec = widget.spec;
    if (spec.kind == 'notifications') {
      final ok = await ref
          .read(operationProvider.notifier)
          .run('notification-${row['notificationId']}', () async {
        await ref
            .read(operationsRepositoryProvider)
            .write('POST', '/notifications/${row['notificationId']}/read');
      });
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ref
                .read(operationProvider)
                .errors['notification-${row['notificationId']}']
                .toString())));
        return;
      }
      final target = notificationRoute(row, ref.read(sessionProvider).user);
      if (target != null) {
        context.push(target);
      } else {
        await showDialog(
            context: context,
            builder: (_) => AlertDialog(
                    title: Text('${row['title'] ?? 'Thông báo'}'),
                    content: Text(
                        '${row['message'] ?? 'Thông báo không có hồ sơ liên quan.'}'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Đóng'))
                    ]));
      }
      return;
    }
    context.push(spec.recordRoute(recordId(spec, row)), extra: row);
  }

  void shiftWeek(int days) => setState(() {
        from = from!.add(Duration(days: days));
        to = to!.add(Duration(days: days));
        page = 0;
      });
  Future<void> pickRange() async {
    final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        initialDateRange:
            from == null ? null : DateTimeRange(start: from!, end: to!));
    if (range != null) {
      setState(() {
        from = range.start;
        to = range.end;
        page = 0;
      });
    }
  }
}

String rowTitle(ModuleSpec spec, Json row) =>
    valueText(spec.titleKey, row[spec.titleKey] ?? row['title'] ?? spec.title);
String rowSubtitle(ModuleSpec spec, Json row) {
  if (spec.kind == 'notifications') {
    return '${row['message'] ?? ''}\n${dateText(row['createdAt'])}${row['readAt'] == null ? ' · Chưa đọc' : ''}';
  }
  if (spec.kind == 'schedule') {
    return '${json(row['workShift'])['shiftName'] ?? ''}\n${dateText(row['plannedStartAt'])} → ${dateText(row['plannedEndAt'])} · ${statusLabel(row['status'])}';
  }
  return [
    if (row['employeeCode'] != null) '${row['employeeCode']}',
    if (row['email'] != null) '${row['email']}',
    if (row['employeeName'] != null && spec.titleKey != 'employeeName')
      '${row['employeeName']}',
    if (row['workDate'] != null && spec.titleKey != 'workDate')
      dateText(row['workDate']),
    if (spec.key == 'devices' && row['deviceLabel'] != null)
      '${row['deviceLabel']}',
    if ((row['status'] ?? row['reviewStatus'] ?? row['employmentStatus']) !=
        null)
      statusLabel(
          row['status'] ?? row['reviewStatus'] ?? row['employmentStatus']),
    if (row['dueAt'] != null) 'Hạn ${dateText(row['dueAt'])}',
    if (row['description'] != null) '${row['description']}'
  ].join(' · ');
}

String? notificationRoute(Json notification, [CurrentUser? user]) {
  final type = notification['entityType'] ?? notification['relatedEntityType'];
  final id = notification['entityId'] ?? notification['relatedEntityId'];
  if (id == null) return null;
  final key = switch (type) {
    'Attendance' =>
      user?.has('ATTENDANCE_VIEW_ALL') == true ? 'attendance' : 'my-attendance',
    'AttendanceDevice' =>
      user?.has('DEVICE_APPROVE') == true ? 'devices' : 'my-devices',
    'ShiftAssignment' ||
    'WorkSchedule' =>
      user?.manager == true ? 'assignments' : 'my-schedule',
    'ChecklistTask' =>
      user?.has('CHECKLIST_VIEW') == true ? 'checklists' : 'my-checklists',
    'EmployeeDocument' => 'my-document-records',
    'AttendanceExceptionRequest' =>
      user?.manager == true ? 'explanations' : 'my-explanations',
    'OvertimeRequest' => user?.manager == true ? 'overtime' : 'my-overtime',
    'AttendanceAdjustmentRequest' =>
      user != null && canAdjust(user) ? 'adjustments' : 'my-adjustments',
    'EmployeeRewardPenalty' =>
      user?.has('REWARD_VIEW') == true ? 'decisions' : 'my-rewards',
    'ViolationEvent' =>
      user?.has('VIOLATION_REVIEW') == true ? 'violations' : 'my-violations',
    'PayrollPeriod' => 'payroll',
    'EmployeeTraining' => 'enrollments',
    _ => null
  };
  return key == null ? null : module(key).recordRoute(id);
}
