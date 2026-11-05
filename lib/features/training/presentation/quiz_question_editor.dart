import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_coffee_shop_flutter/core/presentation/resource_widgets.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/presentation/record_form.dart';
import '../domain/training_fields.dart';

class QuizQuestionEditor extends ConsumerStatefulWidget {
  const QuizQuestionEditor(this.id, {super.key});
  final String id;
  @override
  ConsumerState<QuizQuestionEditor> createState() => _QuestionState();
}

class _QuestionState extends ConsumerState<QuizQuestionEditor> {
  String search = '';
  int page = 0;
  String get path => '/admin/training/courses/${widget.id}/questions';
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Ngân hàng câu hỏi')),
        body: PageBody(children: [
          const Text(
              'Quản lý từng câu hỏi. Lịch sử và kết quả bài làm đã nộp được giữ nguyên.'),
          const SizedBox(height: 16),
          TextField(
              decoration: const InputDecoration(
                  labelText: 'Tìm câu hỏi', prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() {
                    search = v.toLowerCase();
                    page = 0;
                  })),
          ResourceView(ResourceQuery(path), builder: (data) {
            final all = ResourcePage.parse(data).items;
            final rows = all
                .where((q) =>
                    '${q['questionText']}'.toLowerCase().contains(search))
                .toList();
            final totalPages = (rows.length / 10).ceil().clamp(1, 100000);
            final selectedPage = page.clamp(0, totalPages - 1);
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                        child: Text('${rows.length} câu hỏi',
                            style: Theme.of(context).textTheme.titleMedium)),
                    FilledButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Thêm câu hỏi'),
                        onPressed: () => editRecord(context, ref,
                            title: 'Thêm câu hỏi',
                            fields: quizQuestionFields,
                            initial: {
                              'sortOrder': all.fold<int>(
                                      0,
                                      (v, q) =>
                                          (q['sortOrder'] as num).toInt() > v
                                              ? (q['sortOrder'] as num).toInt()
                                              : v) +
                                  1
                            },
                            path: path)),
                  ]),
                  if (rows.isEmpty)
                    const EmptyPanel(
                        message:
                            'Chưa có câu hỏi phù hợp. Thêm câu hỏi để chuẩn bị bài kiểm tra.'),
                  for (final q in rows.skip(selectedPage * 10).take(10))
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text('Câu ${q['sortOrder']}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge),
                                  const SizedBox(height: 8),
                                  Text('${q['questionText']}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  ExpansionTile(
                                      tilePadding: EdgeInsets.zero,
                                      title: Text(
                                          'Đáp án đúng: ${q['correctOption']}'),
                                      children: [
                                        for (final option in [
                                          'A',
                                          'B',
                                          'C',
                                          'D'
                                        ])
                                          ListTile(
                                              dense: true,
                                              leading: Icon(option ==
                                                      q['correctOption']
                                                  ? Icons.check_circle_outline
                                                  : Icons.circle_outlined),
                                              title: Text(
                                                  '$option. ${q['option$option']}'))
                                      ]),
                                  Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                            icon:
                                                const Icon(Icons.edit_outlined),
                                            label: const Text('Sửa'),
                                            onPressed: () => editRecord(
                                                context, ref,
                                                title: 'Sửa câu hỏi',
                                                fields: quizQuestionFields,
                                                initial: q,
                                                path:
                                                    '$path/${q['questionId']}',
                                                method: 'PUT')),
                                        TextButton.icon(
                                            icon: const Icon(
                                                Icons.delete_outline),
                                            label: const Text('Xóa'),
                                            onPressed: () async {
                                              final confirm = await showDialog<
                                                      bool>(
                                                  context: context,
                                                  builder: (dialog) =>
                                                      AlertDialog(
                                                          title: const Text(
                                                              'Xóa câu hỏi?'),
                                                          content: const Text(
                                                              'Câu hỏi được gỡ khỏi bài kiểm tra mới. Lịch sử bài làm vẫn giữ lại.'),
                                                          actions: [
                                                            TextButton(
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                        dialog,
                                                                        false),
                                                                child:
                                                                    const Text(
                                                                        'Hủy')),
                                                            FilledButton(
                                                                onPressed: () =>
                                                                    Navigator.pop(
                                                                        dialog,
                                                                        true),
                                                                child: const Text(
                                                                    'Xóa câu hỏi'))
                                                          ]));
                                              if (confirm != true) return;
                                              final ok = await ref
                                                  .read(operationProvider
                                                      .notifier)
                                                  .run('delete-question',
                                                      () async {
                                                await ref
                                                    .read(
                                                        resourceRepositoryProvider)
                                                    .write('DELETE',
                                                        '$path/${q['questionId']}');
                                              });
                                              if (!ok && context.mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(const SnackBar(
                                                        content: Text(
                                                            'Chưa xóa được câu hỏi. Hãy tải lại và thử lại.')));
                                              }
                                            }),
                                      ]),
                                ]))),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    IconButton(
                        onPressed: selectedPage > 0
                            ? () => setState(() => page = selectedPage - 1)
                            : null,
                        icon: const Icon(Icons.chevron_left)),
                    Text('Trang ${selectedPage + 1}/$totalPages'),
                    IconButton(
                        onPressed: selectedPage + 1 < totalPages
                            ? () => setState(() => page = selectedPage + 1)
                            : null,
                        icon: const Icon(Icons.chevron_right))
                  ]),
                ]);
          }),
        ]),
      );
}
