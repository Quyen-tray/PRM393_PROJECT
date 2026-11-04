import 'package:flutter/material.dart';
import '../../attendance/presentation/attendance_calendar_page.dart';
import '../../schedule/presentation/schedule_board.dart';
import '../../../shared/resources/presentation/lookup_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hrm_coffee_shop_flutter/core/presentation/business_labels.dart';
import 'package:hrm_coffee_shop_flutter/core/presentation/resource_widgets.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/data/session_controller.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';
import 'package:hrm_coffee_shop_flutter/app/router/module_registry.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/presentation/record_form.dart';
import 'package:hrm_coffee_shop_flutter/features/audit/presentation/audit_export_button.dart';
import 'package:hrm_coffee_shop_flutter/features/devices/presentation/register_device_button.dart';
import 'package:hrm_coffee_shop_flutter/features/documents/presentation/my_documents_page.dart';
import 'package:hrm_coffee_shop_flutter/features/notifications/presentation/notification_target.dart';
import 'package:hrm_coffee_shop_flutter/features/store/presentation/store_settings_page.dart';
import 'package:hrm_coffee_shop_flutter/features/training/presentation/training_page.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/presentation/record_summary.dart';

class ModulePage extends ConsumerStatefulWidget {
  const ModulePage(this.spec, {this.initialStatus, super.key});
  final ModuleSpec spec;
  final String? initialStatus;
  @override
  ConsumerState<ModulePage> createState() => _ModulePageState();
}

class _ModulePageState extends ConsumerState<ModulePage> {
  int page = 0, pageSize = 20;
  String ordering = 'desc', role = '';
  bool showArchived = false;
  Json? selectedEmployee;
  String get sortField => switch (widget.spec.key) {
        'accounts' => 'userId',
        'devices' => 'deviceId',
        'attendance' || 'my-attendance' => 'attendanceId',
        'checklists' || 'checklist-reviews' => 'checklistTaskId',
        'explanations' => 'submittedAt',
        'overtime' => 'requestedAt',
        'assignments' => 'plannedStartAt',
        'employees' => 'employeeId',
        'adjustments' || 'my-adjustments' => 'createdAt',
        'notifications' => 'createdAt',
        _ => ''
      };
  String status = '', search = '', entityType = '', actionCode = '';
  DateTime? from, to;
  @override
  void initState() {
    super.initState();
    status = widget.initialStatus ??
        switch (widget.spec.key) {
          'devices' || 'explanations' || 'overtime' => 'PENDING',
          'accounts' => 'ACTIVE',
          _ => ''
        };
    if (widget.spec.kind == 'schedule') {
      ordering = 'asc';
      from = DateUtils.dateOnly(
        DateTime.now(),
      ).subtract(Duration(days: DateTime.now().weekday - 1));
      to = from!.add(const Duration(days: 6));
    }
  }

  Json get query => {
        'page': page,
        'size': pageSize,
        if (widget.spec.filters.isNotEmpty ||
            widget.spec.key == 'my-checklists')
          'status': status,
        if (sortField.isNotEmpty) 'sort': '$sortField,$ordering',
        if (role.isNotEmpty) 'role': role,
        if (selectedEmployee != null)
          'employeeId': selectedEmployee!['employeeId'],
        if (search.isNotEmpty) 'q': search,
        if (entityType.isNotEmpty) 'entityType': entityType,
        if (actionCode.isNotEmpty) 'actionCode': actionCode,
        if (from != null) 'from': from!.toIso8601String().substring(0, 10),
        if (to != null) 'to': to!.toIso8601String().substring(0, 10),
        if (['courses', 'skills'].contains(widget.spec.key) &&
            ref.read(sessionProvider).user!.admin)
          'includeInactive': true,
      };
  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final user = ref.watch(sessionProvider).user!;
    if (spec.key == 'my-attendance') return const AttendanceCalendarPage();
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
            Text(spec.title, style: Theme.of(context).textTheme.headlineSmall),
            if (spec.createPath != null &&
                (spec.createAccess?.call(user) ?? false) &&
                !(spec.key == 'employees' &&
                    ref.read(sessionProvider).workspace == Workspace.manager))
              FilledButton.icon(
                onPressed: () => editRecord(
                  context,
                  ref,
                  title: 'Tạo ${spec.title.toLowerCase()}',
                  fields: spec.fields,
                  path: spec.createPath!,
                ),
                icon: const Icon(Icons.add),
                label: const Text('Tạo mới'),
              ),
            if (spec.key == 'my-devices') const RegisterDeviceButton(),
            if (spec.kind == 'notifications')
              TextButton.icon(
                onPressed: () => ref.read(operationProvider.notifier).run(
                  'read-all',
                  () async {
                    await ref
                        .read(resourceRepositoryProvider)
                        .write('POST', '/notifications/read-all');
                  },
                ),
                icon: const Icon(Icons.done_all),
                label: const Text('Đọc tất cả'),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (spec.search ||
            [
              'accounts',
              'courses',
              'templates',
              'shifts',
              'skills',
              'reminder-rules'
            ].contains(spec.key))
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText: spec.key == 'devices'
                    ? 'Tìm thiết bị, tên hoặc mã nhân viên'
                    : 'Tìm tên, mã hoặc email',
              ),
              onSubmitted: (s) => setState(() {
                search = s.trim();
                page = 0;
              }),
            ),
          ),
        if (spec.key == 'assignments')
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Wrap(spacing: 8, children: [
                OutlinedButton.icon(
                    icon: const Icon(Icons.person_search_outlined),
                    label: Text(selectedEmployee == null
                        ? 'Lọc theo nhân viên'
                        : '${selectedEmployee!['fullName']}'),
                    onPressed: () async {
                      final selected =
                          await Navigator.of(context, rootNavigator: true)
                              .push<Json>(MaterialPageRoute(
                                  builder: (_) =>
                                      const LookupPicker(employeeField)));
                      if (selected != null && mounted) {
                        setState(() {
                          selectedEmployee = selected;
                          page = 0;
                        });
                      }
                    }),
                if (selectedEmployee != null)
                  TextButton(
                      onPressed: () => setState(() {
                            selectedEmployee = null;
                            page = 0;
                          }),
                      child: const Text('Tất cả nhân viên')),
              ])),
        if (spec.kind != 'report')
          Card(
              child: ExpansionTile(
                  leading: const Icon(Icons.tune),
                  title: const Text('Bộ lọc và sắp xếp'),
                  subtitle: Text(
                      '${status.isEmpty ? 'Tất cả trạng thái' : statusLabel(status)} · $pageSize mục/trang${role.isEmpty ? '' : ' · ${roleName(role)}'}'),
                  childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  children: [
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                              width: 158,
                              child: DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  initialValue: ordering,
                                  decoration: const InputDecoration(
                                      labelText: 'Sắp xếp'),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'desc',
                                        child: Text('Mới nhất trước')),
                                    DropdownMenuItem(
                                        value: 'asc',
                                        child: Text('Cũ nhất trước'))
                                  ],
                                  onChanged: (v) => setState(() {
                                        ordering = v!;
                                        page = 0;
                                      }))),
                          SizedBox(
                              width: 130,
                              child: DropdownButtonFormField<int>(
                                  isExpanded: true,
                                  initialValue: pageSize,
                                  decoration: const InputDecoration(
                                      labelText: 'Mỗi trang'),
                                  items: [10, 20, 50]
                                      .map((n) => DropdownMenuItem(
                                          value: n, child: Text('$n mục')))
                                      .toList(),
                                  onChanged: (v) => setState(() {
                                        pageSize = v!;
                                        page = 0;
                                      }))),
                          if ([
                            'courses',
                            'templates',
                            'shifts',
                            'skills',
                            'reminder-rules'
                          ].contains(spec.key))
                            FilterChip(
                                label: const Text('Hiện cả mục ngừng sử dụng'),
                                selected: showArchived,
                                onSelected: (v) => setState(() {
                                      showArchived = v;
                                      page = 0;
                                    })),
                          if (spec.key == 'accounts')
                            SizedBox(
                                width: 190,
                                child: DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    initialValue: role,
                                    decoration: const InputDecoration(
                                        labelText: 'Vai trò'),
                                    items: [
                                      '',
                                      'EMPLOYEE',
                                      'STORE_MANAGER',
                                      'SYSTEM_ADMIN'
                                    ]
                                        .map((r) => DropdownMenuItem(
                                            value: r,
                                            child: Text(r.isEmpty
                                                ? 'Tất cả vai trò'
                                                : roleName(r))))
                                        .toList(),
                                    onChanged: (v) => setState(() {
                                          role = v!;
                                          page = 0;
                                        }))),
                        ])),
                if (spec.filters.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    children: ['', ...spec.filters]
                        .map(
                          (s) => ChoiceChip(
                            label: Text(s.isEmpty ? 'Tất cả' : statusLabel(s)),
                            selected: status == s,
                            onSelected: (_) => setState(() {
                              status = s;
                              page = 0;
                            }),
                          ),
                        )
                        .toList(),
                  ),
              ])),
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
                    icon: const Icon(Icons.chevron_left),
                  ),
                OutlinedButton.icon(
                  onPressed: pickRange,
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    from == null
                        ? 'Chọn khoảng ngày'
                        : '${dateText(from!.toIso8601String().substring(0, 10))} → ${dateText(to!.toIso8601String().substring(0, 10))}',
                  ),
                ),
                if (spec.kind == 'schedule')
                  IconButton(
                    tooltip: 'Tuần sau',
                    onPressed: () => shiftWeek(7),
                    icon: const Icon(Icons.chevron_right),
                  ),
                if (from != null && spec.kind != 'schedule')
                  TextButton(
                    onPressed: () => setState(() {
                      from = null;
                      to = null;
                      page = 0;
                    }),
                    child: const Text('Xóa bộ lọc'),
                  ),
              ],
            ),
          ),
        if (spec.key == 'devices')
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'Lọc theo trạng thái hoặc tìm thiết bị, tên/mã nhân viên. Mở thiết bị để duyệt, thu hồi hoặc xem lịch sử thiết bị của nhân viên.',
            ),
          ),
        if (spec.key.contains('adjustments'))
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'Mỗi giờ vào hoặc giờ ra đề nghị là một trường điều chỉnh riêng. Quản lý duyệt trước, nhân sự duyệt và áp dụng sau.',
            ),
          ),
        if (spec.key == 'audit') ...[
          TextField(
            decoration: const InputDecoration(
              labelText: 'Lọc theo đối tượng',
              hintText: 'Attendance, Employee, …',
            ),
            onSubmitted: (v) => setState(() {
              entityType = v.trim();
              page = 0;
            }),
          ),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Lọc theo mã hành động',
              hintText: 'ATTENDANCE_CHECK_IN, …',
            ),
            onSubmitted: (v) => setState(() {
              actionCode = v.trim();
              page = 0;
            }),
          ),
          AuditExportButton({
            if (from != null) 'from': from!.toIso8601String().substring(0, 10),
            if (to != null) 'to': to!.toIso8601String().substring(0, 10),
          }),
        ],
        if (spec.kind == 'notifications' &&
            ref.watch(operationProvider).errors['read-all'] != null)
          ErrorPanel(ref.watch(operationProvider).errors['read-all']!),
        ResourceView(
          q,
          builder: (data) {
            final raw = ResourcePage.parse(data);
            final local = data is List;
            final rows = raw.items
                .where((r) =>
                    (!local || (showArchived || r['isActive'] != false)) &&
                    (!local ||
                        search.isEmpty ||
                        r.values.any((v) =>
                            v is String &&
                            v.toLowerCase().contains(search.toLowerCase()))))
                .toList();
            int compareId(Json a, Json b) {
              final first = num.tryParse(recordId(spec, a)),
                  second = num.tryParse(recordId(spec, b));
              return first != null && second != null
                  ? first.compareTo(second)
                  : recordId(spec, a).compareTo(recordId(spec, b));
            }

            if (local && ordering == 'desc') {
              rows.sort((a, b) => compareId(b, a));
            }
            if (local && ordering == 'asc') {
              rows.sort(compareId);
            }
            final pages = (rows.length / pageSize).ceil().clamp(1, 100000);
            final localPage = page.clamp(0, pages - 1);
            final result = local
                ? ResourcePage(
                    rows.skip(localPage * pageSize).take(pageSize).toList(),
                    page: localPage,
                    totalPages: pages,
                    total: rows.length)
                : raw;
            if (spec.kind == 'report' && data is Map) {
              return InfoCard(json(data));
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (result.items.isEmpty) const EmptyPanel(),
                if (spec.kind == 'schedule')
                  ScheduleBoard(result.items,
                      onOpen: openRow, descending: ordering == 'desc')
                else
                  ...result.items.map(
                    (row) => spec.kind == 'report'
                        ? InfoCard(row)
                        : Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                                child: Icon(spec.icon, size: 21),
                              ),
                              title: Text(
                                rowTitle(spec, row),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Text(rowSubtitle(spec, row),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              trailing: spec.kind == 'report'
                                  ? null
                                  : const Icon(Icons.chevron_right),
                              onTap: spec.kind == 'report'
                                  ? null
                                  : () => openRow(row),
                            ),
                          ),
                  ),
                const SizedBox(height: 12),
                Text('${result.total} kết quả',
                    style: Theme.of(context).textTheme.labelLarge),
                if (result.totalPages > 1)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        tooltip: 'Trang trước',
                        onPressed: result.page > 0
                            ? () => setState(() => page = result.page - 1)
                            : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Text(
                        'Trang ${result.page + 1}/${result.totalPages}',
                      ),
                      IconButton(
                        tooltip: 'Trang sau',
                        onPressed: result.page + 1 < result.totalPages
                            ? () => setState(() => page = result.page + 1)
                            : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> openRow(Json row) async {
    final spec = widget.spec;
    if (spec.kind == 'notifications') {
      final ok = await ref.read(operationProvider.notifier).run(
        'notification-${row['notificationId']}',
        () async {
          await ref
              .read(resourceRepositoryProvider)
              .write('POST', '/notifications/${row['notificationId']}/read');
        },
      );
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ref
                  .read(operationProvider)
                  .errors['notification-${row['notificationId']}']
                  .toString(),
            ),
          ),
        );
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
              '${row['message'] ?? 'Thông báo không có hồ sơ liên quan.'}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
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
          from == null ? null : DateTimeRange(start: from!, end: to!),
    );
    if (range != null) {
      setState(() {
        from = range.start;
        to = range.end;
        page = 0;
      });
    }
  }
}
