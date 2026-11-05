import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hrm_coffee_shop_flutter/core/presentation/resource_widgets.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';

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
  Widget build(BuildContext context) => PageBody(
        children: [
          if (result != null) ...[
            Text(
              result!['passed'] == true
                  ? 'Bạn đã đạt bài kiểm tra'
                  : 'Bài kiểm tra chưa đạt',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            InfoCard(result!),
            ...ResourcePage.parse(result!['answers']).items.map(
                  (r) => Card(
                    child: ListTile(
                      leading: Icon(
                        r['correct'] == true
                            ? Icons.check_circle
                            : Icons.cancel_outlined,
                      ),
                      title: Text('${r['questionText']}'),
                      subtitle: Text(
                        'Đã chọn ${r['selectedOption']} · Đáp án đúng ${r['correctOption']}',
                      ),
                    ),
                  ),
                ),
            FilledButton(
              onPressed: () => context.go('/module/training'),
              child: const Text('Về danh sách đào tạo'),
            ),
          ] else
            ResourceView(
              ResourceQuery('/training/courses/${widget.courseId}/quiz'),
              builder: (data) {
                final questions = ResourcePage.parse(data).items;
                final currentQuestionIds =
                    questions.map((q) => q['questionId']).toSet();
                answers
                    .removeWhere((id, _) => !currentQuestionIds.contains(id));
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionTitle('Bài kiểm tra trắc nghiệm'),
                    const Text(
                      'Chọn một đáp án cho mỗi câu hỏi. Điểm và điều kiện đạt do máy chủ quyết định.',
                    ),
                    for (final q in questions)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${q['questionText']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              RadioGroup<String>(
                                groupValue: answers[q['questionId']],
                                onChanged: (value) {
                                  if (!busy && value != null) {
                                    setState(
                                      () => answers[q['questionId'] as int] =
                                          value,
                                    );
                                  }
                                },
                                child: Column(
                                  children: ResourcePage.parse(q['options'])
                                      .items
                                      .map(
                                        (option) => RadioListTile<String>(
                                          enabled: !busy,
                                          title: Text(
                                            '${option['key']}. ${option['text']}',
                                          ),
                                          value: '${option['key']}',
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
                                    .read(resourceRepositoryProvider)
                                    .write(
                                  'POST',
                                  '/training/courses/${widget.courseId}/quiz-attempts',
                                  {
                                    'answers': answers.entries
                                        .map(
                                          (e) => {
                                            'questionId': e.key,
                                            'selectedOption': e.value,
                                          },
                                        )
                                        .toList(),
                                  },
                                );
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
                      child: Text(busy ? 'Đang chấm bài…' : 'Nộp bài kiểm tra'),
                    ),
                  ],
                );
              },
            ),
        ],
      );
}
