import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_providers.dart';
import '../../../core/presentation/business_labels.dart';
import '../../../core/presentation/resource_widgets.dart';
import '../../../core/storage/evidence_service.dart';
import '../../attendance/data/attendance_controller.dart';
import '../data/operations_repository.dart';
import '../domain/module_registry.dart';
import 'record_form.dart';

class RegisterDeviceButton extends ConsumerWidget {
  const RegisterDeviceButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = 'register-device';
    final state = ref.watch(operationProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      FilledButton.icon(
          onPressed: state.busy.contains(key)
              ? null
              : () async {
                  String? platform;
                  String label = '';
                  if (!kIsWeb &&
                      defaultTargetPlatform == TargetPlatform.android) {
                    platform = 'ANDROID';
                    final info = await DeviceInfoPlugin().androidInfo;
                    label = '${info.manufacturer} ${info.model}';
                  }
                  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
                    platform = 'IOS';
                    label = (await DeviceInfoPlugin().iosInfo).name;
                  }
                  if (!context.mounted) return;
                  if (platform == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'Đăng ký thiết bị chấm công hỗ trợ Android và iOS. Dùng ứng dụng trên điện thoại hoặc Android Emulator.')));
                    return;
                  }
                  final credential =
                      ref.read(authenticatedApiProvider).vault.deviceCredential;
                  await editRecord(context, ref,
                      title: 'Đăng ký thiết bị chấm công',
                      fields: const [
                        FieldSpec('deviceLabel', 'Tên thiết bị', required: true)
                      ],
                      initial: {'deviceLabel': label},
                      path: '/attendance/devices/register',
                      fixed: {
                        'deviceFingerprint': credential,
                        'platform': platform
                      });
                },
          icon: const Icon(Icons.add_to_home_screen),
          label: const Text('Đăng ký máy đang dùng')),
      if (state.errors[key] != null) ErrorPanel(state.errors[key]!)
    ]);
  }
}

class TrainingPage extends ConsumerWidget {
  const TrainingPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => PageBody(
          onRefresh: () async {
            ref.read(dataRevisionProvider.notifier).changed();
          },
          children: [
            const SectionTitle('Lộ trình đào tạo'),
            const Text(
                'Đăng ký khóa học để bắt đầu. Khóa có kiểm tra được chấm tại máy chủ; khóa không có kiểm tra được người có quyền xác nhận hoàn thành.'),
            ResourceView(const ResourceQuery('/training/me/requirements'),
                builder: (data) => Column(
                    children: ResourcePage.parse(data)
                        .items
                        .map((r) => ListTile(
                            leading: Icon(r['satisfied'] == true
                                ? Icons.check_circle_outline
                                : Icons.school_outlined),
                            title: Text('${r['courseName']}'),
                            subtitle:
                                Text('Bắt buộc · ${statusLabel(r['status'])}')))
                        .toList())),
            ResourceView(const ResourceQuery('/training/me'),
                builder: (mine) =>
                    ResourceView(const ResourceQuery('/training/courses'),
                        builder: (data) {
                      final enrollments = ResourcePage.parse(mine).items;
                      return Column(
                          children:
                              ResourcePage.parse(data).items.map((course) {
                        final own = enrollments
                            .where((r) => r['courseId'] == course['courseId'])
                            .firstOrNull;
                        return Card(
                            child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Expanded(
                                            child: Text(
                                                '${course['courseName']}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium)),
                                        StatusChip(
                                            own?['status'] ?? 'NOT_ENROLLED')
                                      ]),
                                      const SizedBox(height: 8),
                                      Text(
                                          '${course['description'] ?? 'Chưa có nội dung hướng dẫn.'}'),
                                      const SizedBox(height: 10),
                                      Text(course['isMandatoryTest'] == true
                                          ? 'Trắc nghiệm · Điểm đạt ${course['passScore']}%'
                                          : 'Người quản lý xác nhận hoàn thành'),
                                      if (own?['testScore'] != null)
                                        Text(
                                            'Điểm gần nhất: ${own!['testScore']}'),
                                      if (own?['dueAt'] != null)
                                        Text('Hạn: ${dateText(own!['dueAt'])}'),
                                      if (own?['completionReviewNote'] != null)
                                        Text(
                                            'Ý kiến: ${own!['completionReviewNote']}'),
                                      const SizedBox(height: 10),
                                      if (own == null)
                                        ActionCommand(
                                            'enroll-${course['courseId']}',
                                            'Đăng ký học',
                                            '/training/courses/${course['courseId']}/enroll',
                                            body: const {})
                                      else if (course['isMandatoryTest'] ==
                                              true &&
                                          own['status'] != 'PASSED')
                                        FilledButton.icon(
                                            onPressed: () => context.push(
                                                '/quiz/${course['courseId']}'),
                                            icon:
                                                const Icon(Icons.quiz_outlined),
                                            label:
                                                const Text('Làm bài kiểm tra')),
                                      if (own != null)
                                        TextButton.icon(
                                            onPressed: () => context.push(
                                                '/record/enrollments/${own['employeeTrainingId']}'),
                                            icon: const Icon(Icons.history),
                                            label: const Text(
                                                'Tiến độ và kết quả')),
                                    ])));
                      }).toList());
                    })),
          ]);
}

class QuizPage extends ConsumerStatefulWidget {
  const QuizPage(this.courseId, {super.key});
  final String courseId;
  @override
  ConsumerState<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends ConsumerState<QuizPage> {
  final answers = <int, String>{};
  bool busy = false;
  Object? error;
  Json? result;
  @override
  Widget build(BuildContext context) => PageBody(children: [
        if (result != null) ...[
          Text(
              result!['passed'] == true
                  ? 'Bạn đã đạt bài kiểm tra'
                  : 'Bài kiểm tra chưa đạt',
              style: Theme.of(context).textTheme.headlineSmall),
          InfoCard(result!),
          ...ResourcePage.parse(result!['answers']).items.map((r) => Card(
              child: ListTile(
                  leading: Icon(r['correct'] == true
                      ? Icons.check_circle
                      : Icons.cancel_outlined),
                  title: Text('${r['questionText']}'),
                  subtitle: Text(
                      'Đã chọn ${r['selectedOption']} · Đáp án đúng ${r['correctOption']}')))),
          FilledButton(
              onPressed: () => context.go('/module/training'),
              child: const Text('Về danh sách đào tạo')),
        ] else
          ResourceView(
              ResourceQuery('/training/courses/${widget.courseId}/quiz'),
              builder: (data) {
            final questions = ResourcePage.parse(data).items;
            final currentQuestionIds =
                questions.map((q) => q['questionId']).toSet();
            answers.removeWhere((id, _) => !currentQuestionIds.contains(id));
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionTitle('Bài kiểm tra trắc nghiệm'),
                  const Text(
                      'Chọn một đáp án cho mỗi câu hỏi. Điểm và điều kiện đạt do máy chủ quyết định.'),
                  for (final q in questions)
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${q['questionText']}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  RadioGroup<String>(
                                      groupValue: answers[q['questionId']],
                                      onChanged: (value) {
                                        if (!busy && value != null) {
                                          setState(() =>
                                              answers[q['questionId'] as int] =
                                                  value);
                                        }
                                      },
                                      child: Column(
                                          children: ResourcePage.parse(
                                                  q['options'])
                                              .items
                                              .map((option) => RadioListTile<
                                                      String>(
                                                  enabled: !busy,
                                                  title: Text(
                                                      '${option['key']}. ${option['text']}'),
                                                  value: '${option['key']}'))
                                              .toList())),
                                ]))),
                  if (error != null) ErrorPanel(error!),
                  const SizedBox(height: 16),
                  FilledButton(
                      onPressed: busy || answers.length != questions.length
                          ? null
                          : () async {
                              setState(() {
                                busy = true;
                                error = null;
                              });
                              try {
                                final response = await ref
                                    .read(operationsRepositoryProvider)
                                    .write(
                                        'POST',
                                        '/training/courses/${widget.courseId}/quiz-attempts',
                                        {
                                      'answers': answers.entries
                                          .map((e) => {
                                                'questionId': e.key,
                                                'selectedOption': e.value
                                              })
                                          .toList()
                                    });
                                if (mounted) {
                                  setState(() => result = json(response));
                                }
                                ref
                                    .read(dataRevisionProvider.notifier)
                                    .changed();
                              } catch (e) {
                                if (mounted) setState(() => error = e);
                              } finally {
                                if (mounted) setState(() => busy = false);
                              }
                            },
                      child:
                          Text(busy ? 'Đang chấm bài…' : 'Nộp bài kiểm tra')),
                ]);
          }),
      ]);
}

class MyDocumentsPage extends ConsumerWidget {
  const MyDocumentsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => PageBody(
          onRefresh: () async {
            ref.read(dataRevisionProvider.notifier).changed();
          },
          children: [
            const SectionTitle('Giấy tờ cần nộp'),
            ResourceView(const ResourceQuery('/employees/me/documents/catalog'),
                builder: (data) => Column(
                        children: ResourcePage.parse(data).items.map((r) {
                      final type = json(r['documentType']);
                      return Card(
                          child: ListTile(
                              title: Text('${type['documentName']}'),
                              subtitle: Text(
                                  '${r['mandatory'] == true ? 'Bắt buộc' : 'Tùy chọn'} · ${statusLabel(r['status'])}${r['rejectionReason'] == null ? '' : '\n${r['rejectionReason']}'}'),
                              trailing: r['canSubmit'] == true
                                  ? IconButton(
                                      tooltip: 'Nộp giấy tờ',
                                      icon: const Icon(Icons.upload_file),
                                      onPressed: () =>
                                          submitDocument(context, ref, type))
                                  : const Icon(Icons.hourglass_empty)));
                    }).toList())),
            const SectionTitle('Lịch sử nộp hồ sơ'),
            ResourceView(const ResourceQuery('/employees/me/documents'),
                builder: (data) => Column(
                    children: ResourcePage.parse(data)
                        .items
                        .map((r) => Card(
                            child: ListTile(
                                title: Text(
                                    '${json(r['documentType'])['documentName']}'),
                                subtitle: Text(
                                    '${statusLabel(r['reviewStatus'])} · ${dateText(r['uploadedAt'])}'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => context.push(
                                    '/record/my-document-records/${r['documentId']}'))))
                        .toList())),
          ]);
}

Future<void> submitDocument(BuildContext context, WidgetRef ref, Json type,
    {int? employeeId}) async {
  final service = ref.read(evidenceServiceProvider);
  final repository = ref.read(operationsRepositoryProvider);
  final revision = ref.read(dataRevisionProvider.notifier);
  Object? error;
  try {
    final file = await service.choose('DOCUMENT');
    if (file == null || !context.mounted) return;
    await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
        builder: (_) => RecordForm(
            title: 'Nộp ${type['documentName']}',
            fields: const [
              FieldSpec('issuedAt', 'Ngày cấp', kind: FieldKind.date),
              FieldSpec('expiresAt', 'Ngày hết hạn', kind: FieldKind.date)
            ],
            onSubmit: (value) async {
              final key = await service.upload(file, 'DOCUMENT',
                  employeeId: employeeId);
              await repository.write(
                  'POST',
                  employeeId == null
                      ? '/employees/me/documents'
                      : '/employees/$employeeId/documents',
                  {
                    'documentTypeId': type['documentTypeId'],
                    'storageKey': key,
                    ...value
                  });
              revision.changed();
            })));
  } catch (e) {
    error = e;
  }
  if (error != null && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(error.toString())));
  }
}

const storeFields = [
  FieldSpec('name', 'Tên cửa hàng', required: true),
  FieldSpec('address', 'Địa chỉ'),
  FieldSpec('latitude', 'Vĩ độ',
      kind: FieldKind.decimal, min: -90, max: 90, required: true),
  FieldSpec('longitude', 'Kinh độ',
      kind: FieldKind.decimal, min: -180, max: 180, required: true),
  FieldSpec('attendanceRadiusMeters', 'Bán kính chấm công (m)',
      kind: FieldKind.integer, min: 1, required: true),
  FieldSpec('checkInEarlyMinutes', 'Vào sớm (phút)',
      kind: FieldKind.integer, min: 15, max: 30),
  FieldSpec('graceMinutes', 'Ân hạn (phút)',
      kind: FieldKind.integer, min: 3, max: 5),
  FieldSpec('monthlyGraceLimit', 'Số lần ân hạn mỗi tháng',
      kind: FieldKind.integer, min: 0),
  FieldSpec('photoRetentionMonths', 'Lưu ảnh (tháng)',
      kind: FieldKind.integer, min: 1),
  FieldSpec('gpsMaxAccuracyMeters', 'Sai số GPS tối đa (m)',
      kind: FieldKind.integer, min: 1),
  FieldSpec('shiftReminderMinutes', 'Nhắc trước ca (phút)',
      kind: FieldKind.integer, min: 0),
  FieldSpec('checklistDueSoonMinutes', 'Nhắc trước hạn checklist (phút)',
      kind: FieldKind.integer, min: 0),
  FieldSpec('lateReminderIntervalMinutes', 'Chu kỳ nhắc đi muộn (phút)',
      kind: FieldKind.integer, min: 1),
  FieldSpec('maxLateReminders', 'Số lần nhắc đi muộn',
      kind: FieldKind.integer, min: 0)
];

class StoreSettingsPage extends ConsumerStatefulWidget {
  const StoreSettingsPage({super.key});
  @override
  ConsumerState<StoreSettingsPage> createState() => _StoreSettingsPageState();
}

class _StoreSettingsPageState extends ConsumerState<StoreSettingsPage> {
  bool locating = false;
  Object? error;
  @override
  Widget build(BuildContext context) => PageBody(children: [
        const SectionTitle('Vị trí quán và chính sách chấm công'),
        const Text(
            'Tọa độ đã lưu sẽ được dùng để kiểm tra GPS của nhân viên. Có thể lấy GPS ngay tại quán, xem lại vị trí và lưu trước khi đổi tài khoản để chấm công.'),
        ResourceView(const ResourceQuery('/admin/store-settings'),
            builder: (data) {
          final row = {...json(data), ...json(json(data)['store'])};
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(spacing: 12, runSpacing: 12, children: [
                  OutlinedButton.icon(
                      onPressed: () => editRecord(context, ref,
                          title: 'Cấu hình cửa hàng',
                          fields: storeFields,
                          initial: row,
                          path: '/admin/store-settings',
                          method: 'PATCH'),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Chỉnh sửa cấu hình')),
                  FilledButton.icon(
                      onPressed: locating
                          ? null
                          : () async {
                              setState(() {
                                locating = true;
                                error = null;
                              });
                              try {
                                final p = await actualLocation();
                                if (context.mounted) {
                                  await editRecord(context, ref,
                                      title: 'Xác nhận vị trí quán từ GPS',
                                      fields: const [
                                        FieldSpec('latitude', 'Vĩ độ',
                                            kind: FieldKind.decimal,
                                            required: true,
                                            min: -90,
                                            max: 90),
                                        FieldSpec('longitude', 'Kinh độ',
                                            kind: FieldKind.decimal,
                                            required: true,
                                            min: -180,
                                            max: 180),
                                        FieldSpec('attendanceRadiusMeters',
                                            'Bán kính chấm công (m)',
                                            kind: FieldKind.integer,
                                            required: true,
                                            min: 1)
                                      ],
                                      initial: {
                                        ...row,
                                        'latitude': p.latitude,
                                        'longitude': p.longitude
                                      },
                                      path: '/admin/store-settings',
                                      method: 'PATCH');
                                }
                              } catch (e) {
                                if (mounted) setState(() => error = e);
                              } finally {
                                if (mounted) setState(() => locating = false);
                              }
                            },
                      icon: locating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.my_location),
                      label: const Text('Dùng GPS tại quán')),
                ]),
                InfoCard(row),
              ]);
        }),
        if (error != null) ErrorPanel(error!),
      ]);
}

class ActionCommand extends ConsumerWidget {
  const ActionCommand(this.keyName, this.label, this.path,
      {this.body, this.method = 'POST', super.key});
  final String keyName, label, path, method;
  final Object? body;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(operationProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      OutlinedButton(
          onPressed: state.busy.contains(keyName)
              ? null
              : () =>
                  ref.read(operationProvider.notifier).run(keyName, () async {
                    await ref
                        .read(operationsRepositoryProvider)
                        .write(method, path, body);
                  }),
          child: Text(state.busy.contains(keyName) ? 'Đang xử lý…' : label)),
      if (state.errors[keyName] != null) ErrorPanel(state.errors[keyName]!)
    ]);
  }
}

class AuditExportButton extends ConsumerWidget {
  const AuditExportButton(this.query, {super.key});
  final Json query;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(operationProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextButton.icon(
          icon: const Icon(Icons.download),
          label: const Text('Xuất CSV · tối đa 5.000 dòng'),
          onPressed: state.busy.contains('export-audit')
              ? null
              : () => ref.read(operationProvider.notifier).run('export-audit',
                      () async {
                    final csv = await ref
                        .read(operationsRepositoryProvider)
                        .exportAudit(query);
                    await FilePicker.saveFile(
                        fileName:
                            'hrm-audit-${DateTime.now().toIso8601String().substring(0, 10)}.csv',
                        bytes: Uint8List.fromList(utf8.encode('\uFEFF$csv')),
                        mimeType: 'text/csv');
                  })),
      if (state.errors['export-audit'] != null)
        ErrorPanel(state.errors['export-audit']!)
    ]);
  }
}

Future<void> openEvidence(BuildContext context, String url) async {
  final uri = Uri.parse(ApiEndpoints.baseUrl).resolve(url);
  if (!['http', 'https'].contains(uri.scheme)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('URL bằng chứng không hợp lệ.')));
    }
    return;
  }
  if (!await launchUrl(uri, mode: LaunchMode.platformDefault) &&
      context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('Không mở được tệp. Tải lại chi tiết để lấy liên kết mới.')));
  }
}
