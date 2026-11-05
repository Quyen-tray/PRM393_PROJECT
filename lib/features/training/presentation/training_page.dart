import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hrm_coffee_shop_flutter/core/presentation/business_labels.dart';
import 'package:hrm_coffee_shop_flutter/core/presentation/resource_widgets.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/presentation/action_command.dart';

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
            'Đăng ký khóa học để bắt đầu. Khóa có kiểm tra được chấm tại máy chủ; khóa không có kiểm tra được người có quyền xác nhận hoàn thành.',
          ),
          ResourceView(
            const ResourceQuery('/training/me/requirements'),
            builder: (data) => Column(
              children: ResourcePage.parse(data)
                  .items
                  .map(
                    (r) => ListTile(
                      leading: Icon(
                        r['satisfied'] == true
                            ? Icons.check_circle_outline
                            : Icons.school_outlined,
                      ),
                      title: Text('${r['courseName']}'),
                      subtitle: Text('Bắt buộc · ${statusLabel(r['status'])}'),
                    ),
                  )
                  .toList(),
            ),
          ),
          ResourceView(
            const ResourceQuery('/training/me'),
            builder: (mine) => ResourceView(
              const ResourceQuery('/training/courses'),
              builder: (data) {
                final enrollments = ResourcePage.parse(mine).items;
                return Column(
                  children: ResourcePage.parse(data).items.map((course) {
                    final own = enrollments
                        .where((r) => r['courseId'] == course['courseId'])
                        .firstOrNull;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${course['courseName']}',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                                StatusChip(own?['status'] ?? 'NOT_ENROLLED'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${course['description'] ?? 'Chưa có nội dung hướng dẫn.'}',
                            ),
                            const SizedBox(height: 10),
                            Text(
                              course['isMandatoryTest'] == true
                                  ? 'Trắc nghiệm · Điểm đạt ${course['passScore']}%'
                                  : 'Người quản lý xác nhận hoàn thành',
                            ),
                            if (own?['testScore'] != null)
                              Text('Điểm gần nhất: ${own!['testScore']}'),
                            if (own?['dueAt'] != null)
                              Text('Hạn: ${dateText(own!['dueAt'])}'),
                            if (own?['completionReviewNote'] != null)
                              Text('Ý kiến: ${own!['completionReviewNote']}'),
                            const SizedBox(height: 10),
                            if (own == null)
                              ActionCommand(
                                'enroll-${course['courseId']}',
                                'Đăng ký học',
                                '/training/courses/${course['courseId']}/enroll',
                                body: const {},
                              )
                            else if (course['isMandatoryTest'] == true &&
                                own['status'] != 'PASSED')
                              FilledButton.icon(
                                onPressed: () =>
                                    context.push('/quiz/${course['courseId']}'),
                                icon: const Icon(Icons.quiz_outlined),
                                label: const Text('Làm bài kiểm tra'),
                              ),
                            if (own != null)
                              TextButton.icon(
                                onPressed: () => context.push(
                                  '/record/enrollments/${own['employeeTrainingId']}',
                                ),
                                icon: const Icon(Icons.history),
                                label: const Text('Tiến độ và kết quả'),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      );
}
