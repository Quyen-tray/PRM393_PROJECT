import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../data/mock/admin_demo_data.dart';
import '../../../shared/widgets/app_widgets.dart';
import 'widgets/admin_scaffold.dart';

class AdminTrainingPage extends StatefulWidget {
  const AdminTrainingPage({super.key});

  @override
  State<AdminTrainingPage> createState() => _AdminTrainingPageState();
}

class _AdminTrainingPageState extends State<AdminTrainingPage> {
  AdminCourseType _tab = AdminCourseType.course;

  @override
  Widget build(BuildContext context) {
    final items = AdminDemoData.courses.where((c) => c.type == _tab).toList();

    return AdminScaffold(
      title: 'Quản lý đào tạo',
      selectedIndex: 2,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAppSnack(context, 'Đã thêm khóa đào tạo mới'),
        icon: const Icon(Icons.add),
        label: const Text('Thêm khóa đào tạo'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<AdminCourseType>(
              segments: const [
                ButtonSegment(value: AdminCourseType.course, label: Text('Khóa học')),
                ButtonSegment(value: AdminCourseType.skill, label: Text('Kỹ năng')),
                ButtonSegment(value: AdminCourseType.certificate, label: Text('Chứng chỉ')),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
          ),
          const SizedBox(height: 12),
          AppPanel(
            child: Column(
              children: divided([
                for (final c in items)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.title,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                c.desc,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: c.done / c.total,
                                minHeight: 6,
                                color: AppColors.accent,
                                backgroundColor: const Color(0xFFEFE5D8),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            StatusTag(
                              c.mandatory ? 'Bắt buộc' : 'Tùy chọn',
                              color: c.mandatory ? AppColors.error : AppColors.primary,
                              background: c.mandatory
                                  ? const Color(0xFFF6E3DA)
                                  : const Color(0xFFF0E6DF),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${c.done}/${c.total} hoàn thành',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
