import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/presentation/business_labels.dart';
import '../../../core/presentation/resource_widgets.dart';
import '../../../core/storage/evidence_service.dart';
import '../../auth/data/session_controller.dart';
import '../data/operations_repository.dart';
import '../domain/module_registry.dart';
import 'module_page.dart';
import 'record_form.dart';
import 'specialized_pages.dart';

final detailProvider =
    FutureProvider.autoDispose.family<Json, ResourceQuery>((ref, q) async {
  ref.watch(dataRevisionProvider);
  ref.watch(sessionProvider.select((s) => s.user));
  final spec = module(q.path);
  final id = q.query['id'].toString();
  final repo = ref.watch(operationsRepositoryProvider);
  if (spec.detail != null) {
    final numeric = spec.key.contains('reward') || spec.key == 'decisions'
        ? RegExp(r'\d+$').firstMatch(id)?.group(0) ?? id
        : id;
    return json(await repo.read(spec.itemPath(numeric)));
  }
  // Catalog endpoints have no GET-by-id: traverse pages so reload/deep links remain valid.
  var page = 0;
  while (true) {
    final result = await repo.list(spec.path, {
      'page': page,
      'size': 100,
      if (spec.key == 'positions') 'includeInactive': true,
      if (spec.key == 'courses')
        'includeInactive': ref.read(sessionProvider).user!.admin
    });
    final found =
        result.items.where((row) => recordId(spec, row) == id).firstOrNull;
    if (found != null) return found;
    if (page + 1 >= result.totalPages) break;
    page++;
  }
  throw const ApiException(
      message:
          'Không tìm thấy dữ liệu. Đối tượng có thể đã bị xóa hoặc không còn trong phạm vi truy cập.',
      statusCode: 404);
});

class RecordDetailPage extends ConsumerWidget {
  const RecordDetailPage(this.spec, this.id, {super.key});
  final ModuleSpec spec;
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ResourceQuery(spec.key, {'id': id});
    return ref.watch(detailProvider(q)).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => PageBody(children: [
              ErrorPanel(e, retry: () => ref.invalidate(detailProvider(q)))
            ]),
        data: (row) => PageBody(
                onRefresh: () async {
                  ref.invalidate(detailProvider(q));
                  await ref.read(detailProvider(q).future);
                },
                children: [
                  Text(rowTitle(spec, row),
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  if ((row['status'] ?? row['reviewStatus']) != null)
                    Align(
                        alignment: Alignment.centerLeft,
                        child:
                            StatusChip(row['status'] ?? row['reviewStatus'])),
                  InfoCard(row, omit: const {'items', 'store'}),
                  if (spec.editPath != null &&
                      (spec.editAccess
                              ?.call(ref.watch(sessionProvider).user!) ??
                          false))
                    Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                            onPressed: () => editRecord(context, ref,
                                title: 'Sửa ${spec.title.toLowerCase()}',
                                fields: spec.editFields ?? spec.fields,
                                initial: row,
                                path: spec.editPath!.replaceAll('{id}', id),
                                method: spec.editMethod),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Chỉnh sửa'))),
                  RecordActions(spec: spec, row: row),
                ]));
  }
}

class RecordActions extends ConsumerWidget {
  const RecordActions({required this.spec, required this.row, super.key});
  final ModuleSpec spec;
  final Json row;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).user!;
    final key = spec.key;
    final id = recordId(spec, row);
    final own = row['employeeId'] == user.employeeId;
    final status = row['status'] ?? row['reviewStatus'];
    Widget form(String label, String path, List<FieldSpec> fields,
            {Json initial = const {},
            Json fixed = const {},
            String method = 'POST'}) =>
        OutlinedButton(
            onPressed: () => editRecord(context, ref,
                title: label,
                fields: fields,
                initial: initial,
                path: path,
                fixed: fixed,
                method: method),
            child: Text(label));
    Widget approve(String label, String path) => form(
        label,
        path,
        path.startsWith('/attendance/devices/') ||
                ['/submit', '/activate', '/manager-confirm', '/hr-finalize']
                    .any(path.endsWith)
            ? const []
            : const [noteField]);
    Widget reject(String label, String path) => form(label, path, const [
          FieldSpec('reason', 'Lý do',
              kind: FieldKind.multiline, required: true)
        ]);
    final actions = <Widget>[];
    if (['my-schedule', 'assignments'].contains(key)) {
      if (own && status == 'PUBLISHED') {
        actions.add(FilledButton.icon(
            onPressed: () => context.push('/attendance/check-in'),
            icon: const Icon(Icons.fingerprint),
            label: const Text('Mở trang chấm công')));
      }
      if (own) {
        actions.add(form('Gửi giải trình ca này',
            '/attendance/explanation-requests', explanationFields,
            initial: {
              'requestedCheckInAt': row['plannedStartAt'],
              'requestedCheckOutAt': row['plannedEndAt']
            },
            fixed: {
              'scheduleId': row['assignmentId']
            }));
      }
      if (user.manager && status == 'PUBLISHED') {
        actions.add(approve('Hủy phân ca', '/shift-assignments/$id/cancel'));
      }
      actions.add(ResourceView(
          ResourceQuery('/shift-assignments/$id/eligibility'),
          builder: (data) => Card(
              child: ListTile(
                  leading: Icon(json(data)['eligible'] == true
                      ? Icons.check_circle_outline
                      : Icons.info_outline),
                  title: Text(json(data)['eligible'] == true
                      ? 'Đủ điều kiện nhận ca'
                      : 'Có điều kiện chưa đạt'),
                  subtitle: Text((json(data)['restrictions'] as List? ?? [])
                      .map((r) =>
                          json(r)['message'] ??
                          json(r)['code'] ??
                          'Điều kiện chưa đạt')
                      .join('\n'))))));
      if (row['attendanceId'] != null) {
        actions.add(OutlinedButton(
            onPressed: () => context.push(
                '/record/${user.has('ATTENDANCE_VIEW_ALL') ? 'attendance' : 'my-attendance'}/${row['attendanceId']}'),
            child: const Text('Mở bản ghi chấm công')));
      }
    }
    if (['my-attendance', 'attendance'].contains(key)) {
      if (own && row['payrollStatus'] != 'LOCKED') {
        actions.add(form('Giải trình sự cố chấm công',
            '/attendance/$id/explanation-requests', explanationFields,
            initial: {
              'requestedCheckInAt': row['checkInAt'],
              'requestedCheckOutAt': row['checkOutAt']
            }));
        actions.add(form('Đề nghị điều chỉnh giờ công',
            '/attendance/adjustment-requests', adjustmentFields, initial: {
          'requestedCheckInAt': row['checkInAt'],
          'requestedCheckOutAt': row['checkOutAt']
        }, fixed: {
          'attendanceId': row['attendanceId']
        }));
        actions.add(
            form('Đăng ký tăng ca', '/attendance/$id/overtime-requests', const [
          FieldSpec('requestedStartAt', 'Bắt đầu tăng ca (ngày và giờ)',
              kind: FieldKind.dateTime, required: true),
          FieldSpec('requestedEndAt', 'Kết thúc tăng ca (ngày và giờ)',
              kind: FieldKind.dateTime, required: true),
          FieldSpec('reason', 'Lý do tăng ca',
              kind: FieldKind.multiline, required: true)
        ]));
      }
      actions.add(const SectionTitle('Lịch sử xác minh'));
      actions.add(ResourceView(ResourceQuery('/attendance/$id/verifications'),
          builder: (data) => Column(
              children: ResourcePage.parse(data)
                  .items
                  .map((r) => Card(
                      child: ListTile(
                          title: Text(
                              '${r['verificationType']} · ${statusLabel(r['verificationStatus'])}'),
                          subtitle: Text(
                              '${dateText(r['verifiedAt'])}${r['distanceMeters'] == null ? '' : ' · ${r['distanceMeters']} m'}${r['failureReason'] == null ? '' : '\n${r['failureReason']}'}'),
                          trailing: r['evidenceViewUrl'] == null
                              ? null
                              : IconButton(
                                  tooltip: 'Xem ảnh',
                                  icon: const Icon(Icons.image_outlined),
                                  onPressed: () => openEvidence(context,
                                      r['evidenceViewUrl'] as String)))))
                  .toList())));
    }
    if (['my-devices', 'devices'].contains(key)) {
      if (user.has('DEVICE_APPROVE')) {
        if (status == 'PENDING' && !own) {
          actions.add(
              approve('Duyệt thiết bị', '/attendance/devices/$id/approve'));
          actions.add(
              reject('Từ chối thiết bị', '/attendance/devices/$id/reject'));
        }
        if (status == 'ACTIVE') {
          actions.add(
              reject('Thu hồi thiết bị', '/attendance/devices/$id/revoke'));
        }
      }
      if (user.has('DEVICE_APPROVE')) {
        actions.add(LinkedList(
            '/attendance/devices/employees/${row['employeeId']}',
            module('devices'),
            title: 'Tất cả thiết bị của nhân viên'));
      }
    }
    if (['my-explanations', 'explanations'].contains(key) &&
        user.manager &&
        !own &&
        status == 'PENDING_MANAGER') {
      actions.add(approve(
          'Duyệt giải trình', '/attendance/explanation-requests/$id/approve'));
      actions.add(reject(
          'Từ chối giải trình', '/attendance/explanation-requests/$id/reject'));
    }
    if (['my-overtime', 'overtime'].contains(key) &&
        user.manager &&
        !own &&
        status == 'PENDING') {
      actions.add(approve(
          'Duyệt tăng ca', '/attendance/overtime-requests/$id/approve'));
      actions.add(reject(
          'Từ chối tăng ca', '/attendance/overtime-requests/$id/reject'));
    }
    if (['my-adjustments', 'adjustments'].contains(key)) {
      if (user.manager && !own && row['managerStatus'] == 'PENDING') {
        actions.add(approve('Quản lý duyệt',
            '/attendance/adjustment-requests/$id/manager-approve'));
        actions.add(reject('Quản lý từ chối',
            '/attendance/adjustment-requests/$id/manager-reject'));
      }
      if (user.has('ATTENDANCE_ADJUST_HR') &&
          !own &&
          row['managerStatus'] == 'APPROVED' &&
          row['hrStatus'] == 'PENDING') {
        actions.add(approve('Nhân sự duyệt và áp dụng',
            '/attendance/adjustment-requests/$id/hr-approve'));
        actions.add(reject('Nhân sự từ chối',
            '/attendance/adjustment-requests/$id/hr-reject'));
      }
      actions.add(OutlinedButton(
          onPressed: () => context.push(
              '/record/${user.has('ATTENDANCE_VIEW_ALL') || user.has('ATTENDANCE_ADJUST_HR') ? 'attendance' : 'my-attendance'}/${row['attendanceId']}'),
          child: const Text('Xem bản ghi công liên quan')));
    }
    if (['checklists', 'checklist-reviews', 'my-checklists'].contains(key)) {
      if (own && ['PENDING', 'REJECTED', 'OVERDUE'].contains(status)) {
        actions.add(ActionCommand(
            'checklist-start-$id',
            status == 'REJECTED' ? 'Làm lại checklist' : 'Bắt đầu checklist',
            '/checklists/tasks/$id/start'));
      }
      actions.add(const SectionTitle('Các công việc'));
      for (final item in ResourcePage.parse(row['items']).items) {
        actions.add(Card(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(item['isCompleted'] == true
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked),
                          title: Text(
                              '${item['itemName']}${item['isRequired'] == true ? ' *' : ''}'),
                          subtitle: Text(
                              '${item['instructions'] ?? ''}${item['requiresEvidence'] == true ? '\nCần ảnh minh chứng' : ''}')),
                      if (item['note'] != null) Text('${item['note']}'),
                      if (item['hasEvidence'] == true)
                        const Text('Đã có minh chứng'),
                      if (own && ['IN_PROGRESS', 'OVERDUE'].contains(status))
                        OutlinedButton.icon(
                            onPressed: () =>
                                completeChecklistItem(context, ref, id, item),
                            icon: const Icon(Icons.check),
                            label: Text(item['requiresEvidence'] == true
                                ? 'Ảnh và hoàn thành mục'
                                : 'Hoàn thành mục')),
                    ]))));
      }
      if (own && ['IN_PROGRESS', 'OVERDUE'].contains(status)) {
        actions.add(
            approve('Gửi checklist để duyệt', '/checklists/tasks/$id/submit'));
      }
      if (user.manager && !own && status == 'SUBMITTED') {
        actions
            .add(approve('Duyệt checklist', '/checklists/tasks/$id/approve'));
        actions.add(reject('Yêu cầu làm lại', '/checklists/tasks/$id/reject'));
      }
      if (user.manager) {
        actions.add(form('Giao lại checklist', '/checklists/tasks/$id/reassign',
            const [employeeField]));
      }
    }
    if (key == 'training-reviews' &&
        trainingManager(user) &&
        !own &&
        status != 'PASSED') {
      actions.add(approve('Xác nhận đã hoàn thành',
          '/training/completion-reviews/$id/approve'));
      actions.add(reject(
          'Chưa hoàn thành', '/training/completion-reviews/$id/not-complete'));
    }
    if (key == 'enrollments') {
      if (user.employeeId != null) {
        actions.add(LinkedList(
            '/training/courses/${row['courseId']}/attempts/me',
            module('enrollments'),
            title: 'Các lần kiểm tra',
            navigable: false));
      }
    }
    if (['documents', 'my-document-records'].contains(key)) {
      if (row['viewUrl'] != null) {
        actions.add(FilledButton.icon(
            onPressed: () => openEvidence(context, row['viewUrl'] as String),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Xem giấy tờ')));
      }
      if (user.has('DOCUMENT_REVIEW') &&
          !own &&
          row['reviewStatus'] == 'PENDING') {
        actions.add(approve('Duyệt hồ sơ', '/documents/$id/approve'));
        actions.add(reject('Từ chối hồ sơ', '/documents/$id/reject'));
      }
    }
    if (['violations', 'my-violations'].contains(key)) {
      actions.add(LinkedList('/violations/$id/explanations', spec,
          title: 'Giải trình của nhân viên', navigable: false));
      if (own && status == 'OPEN') {
        actions.add(form(
            'Gửi giải trình vi phạm', '/violations/$id/explanations', const [
          FieldSpec('reason', 'Nội dung giải trình',
              kind: FieldKind.multiline, required: true),
          FieldSpec('evidenceStorageKey', 'Tài liệu minh chứng (tùy chọn)',
              kind: FieldKind.upload, source: 'DOCUMENT'),
        ]));
      }
      if (user.has('VIOLATION_REVIEW') && !own && status == 'OPEN') {
        actions.add(approve('Xác nhận vi phạm', '/violations/$id/confirm'));
        actions.add(reject('Bác bỏ vi phạm', '/violations/$id/dismiss'));
      }
      if (user.has('REWARD_PROPOSE') && status == 'CONFIRMED') {
        actions.add(form(
            'Đề xuất phạt từ vi phạm',
            '/rewards-penalties',
            module('decisions')
                .fields
                .where((f) => !['employeeId', 'reasonCode', 'decisionType']
                    .contains(f.key))
                .toList(),
            initial: {
              'description': row['details']
            },
            fixed: {
              'employeeId': row['employeeId'],
              'decisionType': 'PENALTY',
              'reasonCode': row['ruleCode'],
              'violationEventId': row['violationId']
            }));
      }
      if (row['attendanceId'] != null) {
        actions.add(OutlinedButton(
            onPressed: () => context.push(
                '/record/${own ? 'my-attendance' : 'attendance'}/${row['attendanceId']}'),
            child: const Text('Công liên quan')));
      }
    }
    if (['decisions', 'my-rewards'].contains(key) &&
        user.has('REWARD_APPROVE') &&
        !own) {
      if (status == 'PENDING_APPROVAL') {
        actions.add(
            approve('Phê duyệt quyết định', '/rewards-penalties/$id/approve'));
        actions
            .add(reject('Từ chối quyết định', '/rewards-penalties/$id/reject'));
      }
      if (['PENDING_APPROVAL', 'APPROVED'].contains(status)) {
        actions.add(reject('Hủy quyết định', '/rewards-penalties/$id/cancel'));
      }
    }
    if (row['violationEventId'] != null) {
      actions.add(OutlinedButton(
          onPressed: () => context.push(
              '/record/${user.has('VIOLATION_REVIEW') ? 'violations' : 'my-violations'}/${row['violationEventId']}'),
          child: const Text('Vi phạm nguồn')));
    }
    if (key == 'payroll') actions.add(PayrollDetail(row));
    if (key == 'accounts' && user.admin) {
      actions.add(form(
          'Cập nhật vai trò',
          '/admin/users/$id/roles',
          [
            FieldSpec('roles', 'Vai trò',
                kind: FieldKind.multiple,
                required: true,
                options: {
                  'EMPLOYEE',
                  'STORE_MANAGER',
                  'SYSTEM_ADMIN',
                  ...List<String>.from(row['roles'] as List? ?? [])
                }.toList())
          ],
          initial: row,
          method: 'PUT'));
      actions.add(form(
          'Cập nhật trạng thái tài khoản',
          '/admin/users/$id/status',
          const [
            FieldSpec('status', 'Trạng thái',
                kind: FieldKind.choice,
                required: true,
                options: ['ACTIVE', 'LOCKED', 'INACTIVE'])
          ],
          initial: row,
          method: 'PATCH'));
      actions.add(AccountPermissionsEditor(id));
    }
    if (key == 'employees') {
      if (user.has('EMPLOYEE_MANAGE')) {
        actions.add(form(
            'Thay đổi trạng thái làm việc',
            '/employees/$id/status',
            const [
              FieldSpec('status', 'Trạng thái',
                  kind: FieldKind.choice,
                  required: true,
                  options: ['ACTIVE', 'ON_LEAVE', 'SUSPENDED', 'RESIGNED']),
              FieldSpec('reason', 'Lý do', kind: FieldKind.multiline)
            ],
            initial: {'status': row['employmentStatus']},
            method: 'PATCH'));
      }
      actions.add(ResourceView(ResourceQuery('/employees/$id/overview'),
          builder: (data) =>
              InfoCard(json(data), title: 'Tổng hợp nhân viên')));
      actions.add(LinkedList('/employees/$id/training', module('enrollments'),
          title: 'Đào tạo'));
      if (user.has('DEVICE_APPROVE')) {
        actions.add(LinkedList(
            '/attendance/devices/employees/$id', module('devices'),
            title: 'Thiết bị chấm công'));
      }
      if (user.has('DOCUMENT_REVIEW')) {
        actions.add(LinkedList('/employees/$id/documents', module('documents'),
            title: 'Giấy tờ'));
        actions
            .add(ResourceView(ResourceQuery('/employees/$id/documents/catalog'),
                builder: (data) => Column(
                        children: ResourcePage.parse(data).items.map((r) {
                      final type = json(r['documentType']);
                      return ListTile(
                          title: Text('${type['documentName']}'),
                          subtitle: Text(statusLabel(r['status'])),
                          trailing: r['canSubmit'] == true
                              ? IconButton(
                                  tooltip: 'Nộp thay nhân viên',
                                  icon: const Icon(Icons.upload_file),
                                  onPressed: () => submitDocument(
                                      context, ref, type,
                                      employeeId: row['employeeId'] as int))
                              : null);
                    }).toList())));
      }
      actions.add(LinkedList('/employees/$id/skills', module('skills'),
          title: 'Đánh giá kỹ năng', navigable: false));
      if (user.has('TRAINING_MANAGE')) {
        actions.add(form(
            'Đánh giá kỹ năng', '/employees/$id/skills/assessments', const [
          FieldSpec('skillId', 'Kỹ năng',
              kind: FieldKind.lookup,
              required: true,
              source: '/skills',
              valueKey: 'skillId',
              labelKey: 'skillName'),
          FieldSpec('level', 'Mức đánh giá (1–5)',
              kind: FieldKind.integer, required: true, min: 1, max: 5),
          noteField
        ]));
      }
    }
    if (key == 'positions' && user.admin) actions.add(PositionRequirements(id));
    if (key == 'courses') {
      if (user.admin && row['isMandatoryTest'] == true) {
        actions.add(QuizQuestionEditor(id));
      }
      if (user.has('TRAINING_MANAGE')) {
        actions.add(form('Ghi nhận kết quả đào tạo thủ công',
            '/training/courses/$id/attempts', const [
          employeeField,
          FieldSpec('score', 'Điểm (khóa có bài kiểm tra)',
              kind: FieldKind.decimal, min: 0, max: 100),
          FieldSpec('note', 'Lý do ghi nhận thủ công',
              kind: FieldKind.multiline, required: true)
        ]));
      }
    }
    if (key == 'templates' && user.admin) {
      actions.add(approve('Kích hoạt mẫu checklist',
          '/admin/checklist-templates/$id/activate'));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (actions.isNotEmpty) const SectionTitle('Thao tác và hồ sơ liên quan'),
      ...actions.map(
          (a) => Padding(padding: const EdgeInsets.only(bottom: 10), child: a))
    ]);
  }
}

const explanationFields = [
  FieldSpec('reasonCode', 'Loại sự cố',
      kind: FieldKind.choice,
      required: true,
      options: [
        'GPS_UNAVAILABLE',
        'MISSED_CHECK_IN',
        'MISSED_CHECK_OUT',
        'DEVICE_ISSUE',
        'CAMERA_ISSUE',
        'BUSINESS_TRIP',
        'OTHER'
      ]),
  FieldSpec('reason', 'Nội dung giải trình',
      kind: FieldKind.multiline, required: true),
  FieldSpec('requestedCheckInAt', 'Giờ vào đề nghị (ngày và giờ)',
      kind: FieldKind.dateTime),
  FieldSpec('requestedCheckOutAt', 'Giờ ra đề nghị (ngày và giờ)',
      kind: FieldKind.dateTime),
  FieldSpec('evidenceStorageKey', 'Ảnh minh chứng (tùy chọn)',
      kind: FieldKind.upload, source: 'ATTENDANCE'),
];
const adjustmentFields = [
  FieldSpec('reasonCode', 'Lý do điều chỉnh',
      kind: FieldKind.choice,
      required: true,
      options: ['INCORRECT_TIME', 'DEVICE_ISSUE', 'OTHER']),
  FieldSpec('reason', 'Nội dung yêu cầu',
      kind: FieldKind.multiline, required: true),
  FieldSpec('requestedCheckInAt', 'Giờ vào đề nghị (ngày và giờ)',
      kind: FieldKind.dateTime),
  FieldSpec('requestedCheckOutAt', 'Giờ ra đề nghị (ngày và giờ)',
      kind: FieldKind.dateTime),
  FieldSpec('evidenceStorageKey', 'Ảnh minh chứng (tùy chọn)',
      kind: FieldKind.upload, source: 'ATTENDANCE'),
];

class LinkedList extends ConsumerWidget {
  const LinkedList(this.path, this.spec,
      {required this.title, this.navigable = true, super.key});
  final String path, title;
  final ModuleSpec spec;
  final bool navigable;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle(title),
        ResourceView(ResourceQuery(path), builder: (data) {
          final rows = ResourcePage.parse(data).items;
          return rows.isEmpty
              ? const EmptyPanel()
              : Column(
                  children: rows
                      .map((r) => navigable
                          ? Card(
                              child: ListTile(
                                  title: Text(rowTitle(spec, r)),
                                  subtitle: Text(rowSubtitle(spec, r)),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => context.push(
                                      spec.recordRoute(recordId(spec, r)))))
                          : InfoCard(r))
                      .toList());
        })
      ]);
}

Future<void> completeChecklistItem(
    BuildContext context, WidgetRef ref, String taskId, Json item) async {
  final repository = ref.read(operationsRepositoryProvider);
  final revision = ref.read(dataRevisionProvider.notifier);
  try {
    final service = ref.read(evidenceServiceProvider);
    final file =
        item['requiresEvidence'] == true && !(item['hasEvidence'] == true)
            ? await service.choose('CHECKLIST')
            : null;
    if (item['requiresEvidence'] == true &&
        item['hasEvidence'] != true &&
        file == null) {
      return;
    }
    if (!context.mounted) return;
    await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
        builder: (_) => RecordForm(
            title: 'Hoàn thành ${item['itemName']}',
            fields: const [noteField],
            onSubmit: (v) async {
              String? key;
              if (file != null) key = await service.upload(file, 'CHECKLIST');
              await repository.write(
                  'POST',
                  '/checklists/tasks/$taskId/items/${item['runItemId']}/complete',
                  {...v, if (key != null) 'evidenceStorageKey': key});
              revision.changed();
            })));
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

class AccountPermissionsEditor extends ConsumerWidget {
  const AccountPermissionsEditor(this.id, {super.key});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ResourceView(
      ResourceQuery('/admin/users/$id/permissions'),
      builder: (current) =>
          ResourceView(const ResourceQuery('/admin/users/permission-catalog'),
              builder: (data) {
            final grants = json(current);
            final catalog = json(data);
            final perms = ResourcePage.parse(catalog['permissions']).items;
            return Card(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                              'Quyền hiệu lực được máy chủ tổng hợp từ vai trò và quyền gán trực tiếp.'),
                          const SizedBox(height: 8),
                          Text(List<String>.from(
                                  grants['effective'] as List? ?? [])
                              .join(', ')),
                          const SizedBox(height: 8),
                          OutlinedButton(
                              onPressed: () => editRecord(context, ref,
                                  title: 'Cấp quyền trực tiếp',
                                  fields: [
                                    FieldSpec('permissions', 'Quyền trực tiếp',
                                        kind: FieldKind.multiple,
                                        options: perms
                                            .map((p) => '${p['code']}')
                                            .toList()),
                                    FieldSpec(
                                        'permissionSets', 'Bổ sung từ bộ quyền',
                                        kind: FieldKind.multiple,
                                        options: json(catalog['permissionSets'])
                                            .keys
                                            .toList())
                                  ],
                                  initial: {
                                    'permissions': grants['direct'],
                                    'permissionSets': <String>[]
                                  },
                                  path: '/admin/users/$id/permissions',
                                  method: 'PUT'),
                              child: const Text('Chỉnh sửa quyền'))
                        ])));
          }));
}

class PositionRequirements extends ConsumerWidget {
  const PositionRequirements(this.id, {super.key});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(children: [
        requirement(context, ref, 'document', 'Yêu cầu giấy tờ', [
          documentTypeField,
          requiredField,
          const FieldSpec('effectiveFrom', 'Hiệu lực từ', kind: FieldKind.date),
          const FieldSpec('effectiveTo', 'Hiệu lực đến', kind: FieldKind.date)
        ]),
        requirement(context, ref, 'training', 'Yêu cầu đào tạo', [
          courseField,
          requiredField,
          const FieldSpec('effectiveFrom', 'Hiệu lực từ', kind: FieldKind.date),
          const FieldSpec('effectiveTo', 'Hiệu lực đến', kind: FieldKind.date)
        ]),
      ]);
  Widget requirement(BuildContext context, WidgetRef ref, String type,
          String title, List<FieldSpec> fields) =>
      ResourceView(ResourceQuery('/admin/job-positions/$id/$type-requirements'),
          builder: (data) {
        final rows = ResourcePage.parse(data).items;
        final normalized = rows
            .map((r) => {
                  ...r,
                  if (type == 'document')
                    'documentTypeId': json(r['documentType'])['documentTypeId']
                })
            .toList();
        return Card(
            child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(title,
                          style: Theme.of(context).textTheme.titleMedium),
                      if (type == 'training')
                        const Text(
                            'Yêu cầu đào tạo được theo dõi nhưng không chặn phân ca hoặc chấm công.'),
                      ...rows.map((r) => InfoCard(r)),
                      OutlinedButton(
                          onPressed: () => editRecord(context, ref,
                              title: title,
                              fields: [
                                FieldSpec('requirements', title,
                                    kind: FieldKind.array, fields: fields)
                              ],
                              initial: {'requirements': normalized},
                              path:
                                  '/admin/job-positions/$id/$type-requirements',
                              method: 'PUT'),
                          child: const Text('Thay danh sách yêu cầu'))
                    ])));
      });
}

class QuizQuestionEditor extends ConsumerWidget {
  const QuizQuestionEditor(this.id, {super.key});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ResourceView(ResourceQuery('/admin/training/courses/$id/questions'),
          builder: (data) {
        final questions = ResourcePage.parse(data).items;
        return Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ngân hàng câu hỏi · ${questions.length} câu',
                          style: Theme.of(context).textTheme.titleMedium),
                      ...questions.map((r) => ListTile(
                          title: Text('${r['questionText']}'),
                          subtitle:
                              Text('Đáp án đúng: ${r['correctOption']}'))),
                      OutlinedButton(
                          onPressed: () => editRecord(context, ref,
                              title: 'Thiết lập câu hỏi trắc nghiệm',
                              fields: const [
                                FieldSpec('questions', 'Câu hỏi',
                                    kind: FieldKind.array,
                                    required: true,
                                    fields: quizQuestionFields)
                              ],
                              initial: {'questions': questions},
                              path: '/admin/training/courses/$id/questions',
                              method: 'PUT'),
                          child: const Text('Chỉnh sửa câu hỏi'))
                    ])));
      });
}

const blockerTitles = {
  'PENDING_ADJUSTMENT': 'Điều chỉnh công đang chờ',
  'PENDING_OVERTIME': 'Tăng ca chưa duyệt',
  'UNRESOLVED_EXCEPTION': 'Giải trình chưa xử lý',
  'MISSING_CHECK_OUT': 'Công thiếu giờ ra',
  'MISSING_ABSENCE_REQUEST': 'Ca vắng chưa có đơn',
  'PENDING_ABSENCE': 'Ca vắng chờ xác nhận',
  'REJECTED_ABSENCE': 'Ca vắng có đơn bị từ chối'
};

class PayrollDetail extends ConsumerWidget {
  const PayrollDetail(this.row, {super.key});
  final Json row;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = row['periodId'];
    final user = ref.watch(sessionProvider).user!;
    return ResourceView(ResourceQuery('/payroll-periods/$id/readiness'),
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
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Sẵn sàng chốt công'),
        InfoCard(ready, omit: const {'canFinalize'}),
        if (ready['canFinalize'] == true && stage != 'LOCKED')
          const Text(
              'Đã xử lý các vướng mắc. Quản lý cần xác nhận và kỳ công phải kết thúc trước khi chốt.'),
        for (final blocker in ResourcePage.parse(ready['blockers']).items)
          ExpansionTile(
              title: Text(
                  '${blockerTitles[blocker['type']] ?? blocker['type']} · ${blocker['count']}'),
              children: [
                Wrap(
                    spacing: 8,
                    children: (blocker['ids'] as List? ?? [])
                        .map((id) => OutlinedButton(
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
                                      _ => 'ShiftAssignment'
                                    },
                                'relatedEntityId': id
                              }, user);
                              if (route != null) context.push(route);
                            },
                            child: Text('Mở hồ sơ #$id')))
                        .toList())
              ]),
        if (user.manager && ['OPEN', 'MANAGER_REVIEW'].contains(stage))
          OutlinedButton(
              onPressed: () => editRecord(context, ref,
                  title: 'Quản lý xác nhận kỳ công',
                  fields: const [],
                  path: '/payroll-periods/$id/manager-confirm'),
              child: const Text('Quản lý xác nhận')),
        if (user.manager && row['status'] != 'FINALIZED')
          ActionCommand('absence-$id', 'Tạo yêu cầu xác nhận ca vắng',
              '/payroll-periods/$id/absence-requests'),
        if (user.has('PAYROLL_FINALIZE') &&
            ready['canFinalize'] == true &&
            stage == 'HR_REVIEW' &&
            ended)
          OutlinedButton(
              onPressed: () => editRecord(context, ref,
                  title: 'Nhân sự chốt kỳ công',
                  fields: const [],
                  path: '/payroll-periods/$id/hr-finalize'),
              child: const Text('Chốt và khóa kỳ công')),
        if (user.has('PAYROLL_REOPEN') && row['status'] == 'FINALIZED')
          OutlinedButton(
              onPressed: () => editRecord(context, ref,
                  title: 'Mở lại kỳ công',
                  fields: const [
                    FieldSpec('reason', 'Lý do mở lại',
                        kind: FieldKind.multiline, required: true)
                  ],
                  path: '/payroll-periods/$id/reopen'),
              child: const Text('Mở lại kỳ công')),
      ]);
    });
  }
}
