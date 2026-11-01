import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../data/mock/demo_data.dart';

class EmployeeTrainingPage extends StatefulWidget {
  const EmployeeTrainingPage({super.key});

  @override
  State<EmployeeTrainingPage> createState() => _EmployeeTrainingPageState();
}

class _EmployeeTrainingPageState extends State<EmployeeTrainingPage> {
  _TrainingTab _selectedTab = _TrainingTab.courses;
  _CourseFilter _courseFilter = _CourseFilter.all;
  final Map<String, int> _progressOverrides = {};

  int _progressFor(DemoTrainingCourse course) =>
      _progressOverrides[course.title] ?? course.progressPercent;

  bool _isComplete(DemoTrainingCourse course) =>
      course.status == DemoTrainingStatus.complete ||
      _progressFor(course) >= 100;

  String _courseStatus(DemoTrainingCourse course) {
    if (course.status == DemoTrainingStatus.expired) return 'Hết hạn';
    return _isComplete(course) ? 'Đã hoàn thành' : 'Đang học';
  }

  List<DemoTrainingCourse> get _filteredCourses =>
      DemoData.trainingCourses.where((course) {
        return switch (_courseFilter) {
          _CourseFilter.all => true,
          _CourseFilter.mandatory => course.isMandatory,
          _CourseFilter.inProgress =>
            !_isComplete(course) &&
                course.status != DemoTrainingStatus.expired,
          _CourseFilter.complete => _isComplete(course),
        };
      }).toList();

  int get _completedMandatoryCount => DemoData.trainingCourses
      .where((course) => course.isMandatory && _isComplete(course))
      .length;

  int get _mandatoryCount =>
      DemoData.trainingCourses.where((course) => course.isMandatory).length;

  void _showCourseDetails(DemoTrainingCourse course) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _CourseDetailsSheet(
          course: course,
          progress: _progressFor(course),
          status: _courseStatus(course),
          onContinue: () {
            Navigator.of(sheetContext).pop();
            _advanceCourse(course);
          },
        );
      },
    );
  }

  void _advanceCourse(DemoTrainingCourse course) {
    final currentProgress = _progressFor(course);
    if (course.status == DemoTrainingStatus.expired || currentProgress >= 100) {
      return;
    }

    final nextProgress = (currentProgress + 20).clamp(0, 100).toInt();
    setState(() => _progressOverrides[course.title] = nextProgress);
    _showMessage(
      nextProgress >= 100
          ? 'Đã hoàn thành khóa học mẫu.'
          : 'Đã cập nhật tiến độ học.',
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Đào tạo & kỹ năng'),
        leading: IconButton(
          tooltip: 'Quay lại trang chủ',
          onPressed: () => context.go(RouteNames.employeeHome),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              children: [
                _TrainingTabSelector(
                  selectedTab: _selectedTab,
                  onChanged: (tab) => setState(() => _selectedTab = tab),
                ),
                const SizedBox(height: 14),
                if (_selectedTab == _TrainingTab.courses) ...[
                  _RequiredTrainingSummary(
                    completedCount: _completedMandatoryCount,
                    courseCount: _mandatoryCount,
                  ),
                  const SizedBox(height: 16),
                  _CourseFilterSelector(
                    selectedFilter: _courseFilter,
                    onChanged: (filter) =>
                        setState(() => _courseFilter = filter),
                  ),
                  const SizedBox(height: 12),
                  if (_filteredCourses.isEmpty)
                    const _EmptyTrainingState(
                      message: 'Không có khóa học trong mục này.',
                    )
                  else
                    for (final course in _filteredCourses) ...[
                      _CourseCard(
                        course: course,
                        progress: _progressFor(course),
                        status: _courseStatus(course),
                        onTap: () => _showCourseDetails(course),
                      ),
                      const SizedBox(height: 10),
                    ],
                ] else if (_selectedTab == _TrainingTab.skills) ...[
                  const _SectionIntro(
                    title: 'Kỹ năng của tôi',
                    subtitle: 'Kết quả đánh giá kỹ năng hiện tại.',
                  ),
                  const SizedBox(height: 12),
                  for (final skill in DemoData.managerEmployeeSkills) ...[
                    _SkillCard(skill: skill),
                    const SizedBox(height: 10),
                  ],
                ] else ...[
                  const _SectionIntro(
                    title: 'Chứng chỉ của tôi',
                    subtitle: 'Chứng chỉ hoàn thành khóa học.',
                  ),
                  const SizedBox(height: 12),
                  for (final certificate in DemoData.employeeCertificates) ...[
                    _CertificateCard(certificate: certificate),
                    const SizedBox(height: 10),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Lịch',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'Checklist',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Cá nhân',
          ),
        ],
        onDestinationSelected: (index) {
          if (index == 0) {
            context.go(RouteNames.employeeHome);
          } else if (index == 1) {
            context.go(RouteNames.employeeSchedule);
          } else if (index == 2) {
            context.go(RouteNames.employeeChecklist);
          } else if (index == 3) {
            _showMessage('Hồ sơ cá nhân sẽ được hoàn thiện sau.');
          }
        },
      ),
    );
  }
}

enum _TrainingTab { courses, skills, certificates }

enum _CourseFilter { all, mandatory, inProgress, complete }

class _TrainingTabSelector extends StatelessWidget {
  const _TrainingTabSelector({
    required this.selectedTab,
    required this.onChanged,
  });

  final _TrainingTab selectedTab;
  final ValueChanged<_TrainingTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_TrainingTab>(
      segments: const [
        ButtonSegment(
          value: _TrainingTab.courses,
          label: Text('Khóa học'),
        ),
        ButtonSegment(
          value: _TrainingTab.skills,
          label: Text('Kỹ năng'),
        ),
        ButtonSegment(
          value: _TrainingTab.certificates,
          label: Text('Chứng chỉ'),
        ),
      ],
      selected: {selectedTab},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class _RequiredTrainingSummary extends StatelessWidget {
  const _RequiredTrainingSummary({
    required this.completedCount,
    required this.courseCount,
  });

  final int completedCount;
  final int courseCount;

  @override
  Widget build(BuildContext context) {
    final progress = courseCount == 0 ? 0.0 : completedCount / courseCount;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDE8E3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school_outlined, color: AppColors.primary),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'Đào tạo bắt buộc',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$completedCount/$courseCount',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              color: const Color(0xFF31A779),
              backgroundColor: const Color(0xFFECE8E3),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseFilterSelector extends StatelessWidget {
  const _CourseFilterSelector({
    required this.selectedFilter,
    required this.onChanged,
  });

  final _CourseFilter selectedFilter;
  final ValueChanged<_CourseFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    const filters = [
      (value: _CourseFilter.all, label: 'Tất cả'),
      (value: _CourseFilter.mandatory, label: 'Bắt buộc'),
      (value: _CourseFilter.inProgress, label: 'Đang học'),
      (value: _CourseFilter.complete, label: 'Đã hoàn thành'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in filters) ...[
            Padding(
              padding: const EdgeInsets.only(right: 7),
              child: ChoiceChip(
                label: Text(filter.label),
                selected: selectedFilter == filter.value,
                onSelected: (_) => onChanged(filter.value),
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: selectedFilter == filter.value
                      ? Colors.white
                      : AppColors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide(
                  color: selectedFilter == filter.value
                      ? AppColors.primary
                      : const Color(0xFFE5E1DA),
                ),
                backgroundColor: AppColors.surface,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.course,
    required this.progress,
    required this.status,
    required this.onTap,
  });

  final DemoTrainingCourse course;
  final int progress;
  final String status;
  final VoidCallback onTap;

  Color get _statusColor {
    if (course.status == DemoTrainingStatus.expired) return AppColors.error;
    return progress >= 100
        ? const Color(0xFF25804B)
        : const Color(0xFFD39A36);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFEDE8E3)),
          ),
          child: Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1E6D8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  course.isMandatory
                      ? Icons.restaurant_outlined
                      : Icons.chat_bubble_outline,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            course.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.chevron_right,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        _SmallTag(
                          label: course.isMandatory ? 'Bắt buộc' : 'Tùy chọn',
                          color: course.isMandatory
                              ? AppColors.primary
                              : const Color(0xFF4E86A8),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          status,
                          style: TextStyle(
                            color: _statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: progress / 100,
                              minHeight: 5,
                              color: const Color(0xFF31A779),
                              backgroundColor: const Color(0xFFECE8E3),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$progress%',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (course.blocksShiftAssignment) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'Yêu cầu để được phân ca',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallTag extends StatelessWidget {
  const _SmallTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SkillCard extends StatelessWidget {
  const _SkillCard({required this.skill});

  final DemoManagerSkill skill;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDE8E3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F2EC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome_outlined,
                  color: Color(0xFF3B8C67),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  skill.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                skill.levelLabel,
                style: const TextStyle(
                  color: Color(0xFF25804B),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: skill.scorePercent / 100,
                    minHeight: 6,
                    color: const Color(0xFF31A779),
                    backgroundColor: const Color(0xFFECE8E3),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Text(
                '${skill.scorePercent}%',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            'Đánh giá ngày ${skill.evaluatedAt}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _CertificateCard extends StatelessWidget {
  const _CertificateCard({required this.certificate});

  final DemoEmployeeCertificate certificate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDE8E3)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1D9),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.workspace_premium_outlined,
              color: Color(0xFFBA821E),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  certificate.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cấp bởi ${certificate.issuer}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Cấp ${certificate.issuedAt} · Hết hạn ${certificate.expiresAt}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.verified, color: Color(0xFF31A779), size: 20),
        ],
      ),
    );
  }
}

class _SectionIntro extends StatelessWidget {
  const _SectionIntro({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _EmptyTrainingState extends StatelessWidget {
  const _EmptyTrainingState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDE8E3)),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _CourseDetailsSheet extends StatelessWidget {
  const _CourseDetailsSheet({
    required this.course,
    required this.progress,
    required this.status,
    required this.onContinue,
  });

  final DemoTrainingCourse course;
  final int progress;
  final String status;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final isComplete = progress >= 100;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCDC5BC),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              course.title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              course.isMandatory ? 'Khóa học bắt buộc' : 'Khóa học tự chọn',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(child: Text('Trạng thái')),
                Text(
                  status,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                const Expanded(child: Text('Hạn hoàn thành')),
                Text(
                  course.dueDate,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                const Expanded(child: Text('Tiến độ')),
                Text(
                  '$progress%',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isComplete ? null : onContinue,
                child: Text(isComplete ? 'Đã hoàn thành' : 'Tiếp tục học'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
