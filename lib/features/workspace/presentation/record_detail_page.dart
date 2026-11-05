import 'package:flutter/material.dart';
import '../../../shared/resources/presentation/archive_button.dart';
import '../../training/presentation/quiz_question_editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_exception.dart';
import 'package:hrm_coffee_shop_flutter/core/presentation/business_labels.dart';
import 'package:hrm_coffee_shop_flutter/core/presentation/resource_widgets.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/data/session_controller.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';
import 'package:hrm_coffee_shop_flutter/app/router/module_registry.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/presentation/record_summary.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/presentation/record_form.dart';
import 'package:hrm_coffee_shop_flutter/features/workspace/presentation/record_actions.dart';

final detailProvider = FutureProvider.autoDispose.family<Json, ResourceQuery>((
  ref,
  q,
) async {
  ref.watch(dataRevisionProvider);
  ref.watch(sessionProvider.select((s) => s.user));
  final spec = module(q.path);
  final id = q.query['id'].toString();
  final repo = ref.watch(resourceRepositoryProvider);
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
        'includeInactive': ref.read(sessionProvider).user!.admin,
      if (spec.key == 'skills' && ref.read(sessionProvider).user!.admin)
        'includeInactive': true,
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
    statusCode: 404,
  );
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
          error: (e, _) => PageBody(
            children: [
              ErrorPanel(e, retry: () => ref.invalidate(detailProvider(q))),
            ],
          ),
          data: (row) => PageBody(
            onRefresh: () async {
              ref.invalidate(detailProvider(q));
              await ref.read(detailProvider(q).future);
            },
            children: [
              Text(
                rowTitle(spec, row),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              if ((row['status'] ?? row['reviewStatus']) != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: StatusChip(row['status'] ?? row['reviewStatus']),
                ),
              if (spec.key == 'courses' &&
                  ref.watch(sessionProvider).user!.admin &&
                  row['isMandatoryTest'] == true)
                FilledButton.icon(
                    icon: const Icon(Icons.quiz_outlined),
                    label: const Text('Quản lý câu hỏi'),
                    onPressed: () => Navigator.of(context, rootNavigator: true)
                        .push(MaterialPageRoute<void>(
                            builder: (_) => QuizQuestionEditor(id)))),
              if (spec.key == 'employees') ...[
                InfoCard({
                  for (final key in [
                    'employeeCode',
                    'jobTitle',
                    'employmentType',
                    'employmentStatus'
                  ])
                    if (row.containsKey(key)) key: row[key]
                }, title: 'Thông tin công việc'),
                ExpansionTile(
                    title: const Text('Thông tin cá nhân và liên hệ'),
                    children: [
                      InfoCard(row, omit: const {'items', 'store'})
                    ]),
              ] else
                InfoCard(row, omit: const {'items', 'store'}),
              if (spec.key == 'templates')
                ExpansionTile(
                    title: Text(
                        'Nội dung mẫu · ${(row['items'] as List? ?? []).length} công việc'),
                    children: [
                      for (final item in ResourcePage.parse(row['items']).items)
                        ListTile(
                            title: Text('${item['itemName']}'),
                            subtitle: Text('${item['instructions'] ?? ''}'),
                            trailing: item['requiresEvidence'] == true
                                ? const Icon(Icons.photo_camera_outlined)
                                : null)
                    ]),
              if (spec.editPath != null &&
                  (spec.editAccess?.call(ref.watch(sessionProvider).user!) ??
                      false) &&
                  !(spec.key == 'employees' &&
                      ref.watch(sessionProvider).workspace ==
                          Workspace.manager))
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => editRecord(
                      context,
                      ref,
                      title: 'Sửa ${spec.title.toLowerCase()}',
                      fields: spec.key == 'reminder-rules'
                          ? spec.fields
                              .where((f) =>
                                  f.key == 'isActive' ||
                                  (row['ruleId'] == 'CHECKLIST_OVERDUE'
                                      ? f.key != 'leadMinutes'
                                      : f.key == 'leadMinutes'))
                              .toList()
                          : spec.editFields ?? spec.fields,
                      initial: row,
                      path: spec.editPath!.replaceAll('{id}', id),
                      method: spec.editMethod,
                    ),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Chỉnh sửa'),
                  ),
                ),
              RecordActions(spec: spec, row: row),
              ArchiveButton(spec, row),
            ],
          ),
        );
  }
}
