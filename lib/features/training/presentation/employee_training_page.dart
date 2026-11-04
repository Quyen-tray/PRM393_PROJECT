import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/repositories/employee_providers.dart';
import '../../../shared/widgets/employee_bottom_navigation.dart';
import 'employee_training_quiz_page.dart';

enum _TrainingTab { courses, skills, certificates }

enum _CourseFilter { all, mandatory, inProgress, completed }

class EmployeeTrainingPage extends ConsumerStatefulWidget {
  const EmployeeTrainingPage({super.key});

  @override
  ConsumerState<EmployeeTrainingPage> createState() =>
      _EmployeeTrainingPageState();
}
class _EmployeeTrainingPageState extends ConsumerState<EmployeeTrainingPage> {
  _TrainingTab _tab = _TrainingTab.courses;
  _CourseFilter _filter = _CourseFilter.all;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _mine = [];
  // Các khóa được theo dõi theo chức vụ, kể cả khóa chưa ghi danh.
  List<Map<String, dynamic>> _requirements = [];
  List<Map<String, dynamic>> _skills = [];
  List<Map<String, dynamic>> _skillHistory = [];
  int _requiredTotal = 0;
  int _requiredDone = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(employeeRepositoryProvider);
      final profile = await repo.getEmployeeProfile();
      final employeeId = (profile['employeeId'] as num?)?.toInt();
      if (employeeId == null) {
        throw const ApiException(
          message: 'Tài khoản chưa được liên kết hồ sơ nhân viên.',
        );
      }
      final results = await Future.wait<Object>([
        repo.getTrainingCourses(),
        repo.getMyTraining(),
        repo.getSkills(),
        repo.getEmployeeSkillHistory(employeeId),
        repo.getEmployeeOverviewById(employeeId),
        repo.getMyTrainingRequirements(),
      ]);
      if (!mounted) return;
      final overview = results[4] as Map<String, dynamic>;
      final training = overview['training'] is Map
          ? Map<String, dynamic>.from(overview['training'] as Map)
          : <String, dynamic>{};
      setState(() {
        _courses = results[0] as List<Map<String, dynamic>>;
        _mine = results[1] as List<Map<String, dynamic>>;
        _skills = results[2] as List<Map<String, dynamic>>;
        _skillHistory = results[3] as List<Map<String, dynamic>>;
        _requirements = results[5] as List<Map<String, dynamic>>;
        _requiredTotal = (training['requiredCourses'] as num?)?.toInt() ?? 0;
        _requiredDone = (training['completedCourses'] as num?)?.toInt() ?? 0;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Không tải được dữ liệu đào tạo.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _enroll(Map<String, dynamic> course) async {
    final id = courseIdOf(course);
    if (id < 0 || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(employeeRepositoryProvider).enrollTraining(id);
      if (!mounted) return;
      _message('Đã ghi danh khóa học.');
      await _load();
    } on ApiException catch (e) {
      _message(e.message);
    } catch (_) {
      _message('Không ghi danh được khóa học.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _launchQuiz(Map<String, dynamic> course) async {
    final id = courseIdOf(course);
    if (id < 0 || _busy) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final recorded = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EmployeeTrainingQuizPage(
          courseId: id,
          courseName: (course['courseName'] ?? 'Khóa học').toString(),
        ),
      ),
    );
    if (recorded == true && mounted) await _load();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Map<int, Map<String, dynamic>> get _mineByCourse => {
    for (final item in _mine)
      if (item['courseId'] is num) (item['courseId'] as num).toInt(): item,
  };

  Map<String, dynamic>? _requirementOf(Map<String, dynamic> course) {
    final id = courseIdOf(course);
    for (final requirement in _requirements) {
      if (courseIdOf(requirement) == id) return requirement;
    }
    return null;
  }

  bool _matchesFilter(Map<String, dynamic> course) {
    final mine = _mineByCourse[courseIdOf(course)];
    final status = mine?['status']?.toString();
    return switch (_filter) {
      _CourseFilter.all => true,
      _CourseFilter.mandatory => _requirementOf(course) != null,
      _CourseFilter.inProgress =>
        status == 'IN_PROGRESS' || status == 'NOT_STARTED',
      _CourseFilter.completed => status == 'PASSED',
    };
  }

  String _filterLabel(_CourseFilter filter) => switch (filter) {
    _CourseFilter.all => 'Tất cả',
    _CourseFilter.mandatory => 'Theo chức vụ',
    _CourseFilter.inProgress => 'Đang học',
    _CourseFilter.completed => 'Đã hoàn thành',
  };

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
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    children: [
                      SegmentedButton<_TrainingTab>(
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
                        selected: {_tab},
                        onSelectionChanged: (value) =>
                            setState(() => _tab = value.first),
                      ),
                      const SizedBox(height: 14),
                      ..._contentFor(_tab),
                    ],
                  ),
          ),
        ),
      ),
      bottomNavigationBar: const EmployeeBottomNavigation(selectedIndex: 0),
    );
  }

  List<Widget> _contentFor(_TrainingTab tab) => switch (tab) {
    _TrainingTab.courses => _coursesContent(),
    _TrainingTab.skills => _skillsContent(),
    _TrainingTab.certificates => _certificatesContent(),
  };

  List<Widget> _coursesContent() {
    final visible = _courses.where(_matchesFilter).toList();
    return [
      _progressSummary(),
      const SizedBox(height: 14),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final filter in _CourseFilter.values)
            ChoiceChip(
              label: Text(_filterLabel(filter)),
              selected: _filter == filter,
              onSelected: (_) => setState(() => _filter = filter),
            ),
        ],
      ),
      const SizedBox(height: 12),
      if (visible.isEmpty)
        const _EmptyState(message: 'Không có khóa học trong mục này.')
      else
        for (final course in visible) ...[
          _courseCard(course),
          const SizedBox(height: 10),
        ],
    ];
  }

  Widget _progressSummary() {
    final requiredTotal = _requiredTotal;
    final requiredDone = _requiredDone;
    final progress = requiredTotal == 0
        ? 0.0
        : (requiredDone / requiredTotal).clamp(0.0, 1.0).toDouble();
    return _Panel(
      title: 'Tiến độ khóa theo chức vụ',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            requiredTotal == 0
                ? 'Chưa có khóa nào được phân theo chức vụ.'
                : 'Đã đạt $requiredDone/$requiredTotal khóa được phân',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (requiredTotal > 0) ...[
            const SizedBox(height: 6),
            LinearProgressIndicator(value: progress, minHeight: 6),
          ],
          const SizedBox(height: 8),
          const Text(
            'Kết quả trắc nghiệm ghi nhận tiến độ đào tạo và không chặn nhận ca.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _courseStatusLabel(
    Map<String, dynamic> course,
    Map<String, dynamic>? mine,
  ) {
    final status = mine?['status']?.toString();
    if (mine != null &&
        course['isMandatoryTest'] != true &&
        status != 'PASSED') {
      return 'Chờ xác nhận';
    }
    return trainingStatusLabel(status);
  }

  Widget _courseCard(Map<String, dynamic> course) {
    final mine = _mineByCourse[courseIdOf(course)];
    final status = mine?['status']?.toString();
    final isActive = course['isActive'] != false;
    final requirement = _requirementOf(course);
    final hasTest = course['isMandatoryTest'] == true;
    final needsManagerReview =
        mine != null && !hasTest && status != 'PASSED';
    final color = needsManagerReview
        ? const Color(0xFFB7791F)
        : switch (status) {
      'PASSED' => AppColors.secondary,
      'EXPIRED' || 'FAILED' => AppColors.error,
      'PENDING_REVIEW' => const Color(0xFFB7791F),
      'IN_PROGRESS' || 'NOT_STARTED' => AppColors.primary,
      _ => AppColors.textSecondary,
    };
    return Card(
      color: AppColors.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showCourseDetails(course),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (course['courseName'] ?? 'Khóa học').toString(),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  _Tag(label: _courseStatusLabel(course, mine), color: color),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${course['courseCode'] ?? ''} · Điểm đạt ${formatScore(course['passScore'])} · '
                'Hiệu lực ${course['validityMonths'] ?? '—'} tháng',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              if (mine?['dueAt'] != null)
                Text(
                  'Hạn hoàn thành: ${formatDate(mine!['dueAt'])}',
                  style: const TextStyle(fontSize: 12),
                ),
              if (requirement != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Được phân theo chức vụ · không ảnh hưởng nhận ca',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (mine == null && isActive) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonal(
                    onPressed: _busy ? null : () => _enroll(course),
                    child: const Text('Ghi danh'),
                  ),
                ),
              ],
              if (mine != null && status != 'PASSED' && hasTest) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    onPressed: _busy ? null : () => _launchQuiz(course),
                    icon: const Icon(Icons.quiz_outlined),
                    label: Text(
                      status == 'FAILED' || status == 'EXPIRED'
                          ? 'Làm lại trắc nghiệm'
                          : 'Làm bài trắc nghiệm',
                    ),
                  ),
                ),
              ],
              if (mine != null && !hasTest && status != 'PASSED')
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Đã ghi danh. Admin hoặc quản lý sẽ xác nhận khóa học đã hoàn thành hay chưa.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (status == 'PENDING_REVIEW')
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Đăng ký cũ đang chờ quản lý xác nhận.',
                    style: TextStyle(color: Color(0xFF8A5A12), fontSize: 12),
                  ),
                ),
              if ((mine?['completionReviewNote'] ?? '').toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Quản lý ghi nhận: ${mine!['completionReviewNote']}',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCourseDetails(Map<String, dynamic> course) {
    final mine = _mineByCourse[courseIdOf(course)];
    final status = mine?['status']?.toString();
    final canEnroll = mine == null && course['isActive'] != false;
    final canTakeQuiz =
        mine != null && status != 'PASSED' && course['isMandatoryTest'] == true;
    final hasTest = course['isMandatoryTest'] == true;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (course['courseName'] ?? 'Khóa học').toString(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Mã khóa: ${course['courseCode'] ?? '—'}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              if ((course['description'] ?? '').toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(course['description'].toString()),
                ),
              _detailRow('Điểm đạt', formatScore(course['passScore'])),
              _detailRow(
                'Thời hạn hiệu lực',
                '${course['validityMonths'] ?? '—'} tháng',
              ),
              _detailRow(
                'Bài kiểm tra',
                course['isMandatoryTest'] == true ? 'Có' : 'Không',
              ),
              _detailRow(
                'Phân theo chức vụ',
                _requirementOf(course) != null
                    ? 'Có · không chặn nhận ca'
                    : 'Không',
              ),
              _detailRow(
                'Trạng thái của tôi',
                _courseStatusLabel(course, mine),
              ),
              if (mine != null) ...[
                _detailRow('Điểm bài kiểm tra', formatScore(mine['testScore'])),
                _detailRow('Hạn hoàn thành', formatDate(mine['dueAt'])),
                _detailRow('Ngày hoàn thành', formatDate(mine['completedAt'])),
                _detailRow('Hết hạn', formatDate(mine['expiresAt'])),
                if (!hasTest && status != 'PASSED')
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Admin hoặc quản lý sẽ xác nhận khóa học đã hoàn thành hay chưa.',
                    ),
                  ),
                if (status == 'PENDING_REVIEW')
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Đăng ký cũ đang chờ quản lý xác nhận.'),
                  ),
                if ((mine['completionReviewNote'] ?? '').toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Quản lý ghi nhận: ${mine['completionReviewNote']}',
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
              ],
              if (canEnroll) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy
                        ? null
                        : () {
                            Navigator.pop(sheetContext);
                            _enroll(course);
                          },
                    child: const Text('Ghi danh khóa học'),
                  ),
                ),
              ],
              if (canTakeQuiz) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () {
                            Navigator.pop(sheetContext);
                            _launchQuiz(course);
                          },
                    icon: const Icon(Icons.quiz_outlined),
                    label: Text(
                      status == 'FAILED' || status == 'EXPIRED'
                          ? 'Làm lại trắc nghiệm'
                          : 'Bắt đầu trắc nghiệm',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  List<Widget> _skillsContent() {
    final latest = <int, Map<String, dynamic>>{};
    for (final item in _skillHistory) {
      final skillId = (item['skillId'] as num?)?.toInt();
      if (skillId == null) continue;
      final current = latest[skillId];
      if (current == null ||
          (item['assessedAt'] ?? '').toString().compareTo(
                (current['assessedAt'] ?? '').toString(),
              ) >
              0) {
        latest[skillId] = item;
      }
    }
    return [
      const _SectionIntro(
        title: 'Kỹ năng của tôi',
        subtitle: 'Mức đánh giá gần nhất từ 1 (cơ bản) đến 5 (thành thạo).',
      ),
      const SizedBox(height: 12),
      if (_skills.isEmpty)
        const _EmptyState(message: 'Chưa có kỹ năng nào trong danh mục.')
      else
        for (final skill in _skills) ...[
          _skillCard(skill, latest[(skill['skillId'] as num?)?.toInt()]),
          const SizedBox(height: 10),
        ],
    ];
  }

  Widget _skillCard(
    Map<String, dynamic> skill,
    Map<String, dynamic>? assessment,
  ) {
    final level = (assessment?['level'] as num?)?.toInt();
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    (skill['skillName'] ?? 'Kỹ năng').toString(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  level == null ? 'Chưa đánh giá' : 'Mức $level/5',
                  style: TextStyle(
                    color: level == null
                        ? AppColors.textSecondary
                        : AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (level != null) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: level / 5, minHeight: 6),
            ],
            if (assessment != null) ...[
              const SizedBox(height: 6),
              Text(
                'Đánh giá ngày ${formatDate(assessment['assessedAt'])}'
                '${(assessment['note'] ?? '').toString().isEmpty ? '' : ' · ${assessment['note']}'}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _certificatesContent() {
    final certificates = _mine
        .where(
          (item) => item['status'] == 'PASSED' || item['status'] == 'EXPIRED',
        )
        .toList();
    return [
      const _SectionIntro(
        title: 'Chứng chỉ của tôi',
        subtitle: 'Khóa học đã hoàn thành và thời hạn hiệu lực.',
      ),
      const SizedBox(height: 12),
      if (certificates.isEmpty)
        const _EmptyState(message: 'Bạn chưa hoàn thành khóa học nào.')
      else
        for (final item in certificates) ...[
          _certificateCard(item),
          const SizedBox(height: 10),
        ],
    ];
  }

  Widget _certificateCard(Map<String, dynamic> item) {
    final expired = item['status'] == 'EXPIRED';
    return Card(
      color: AppColors.surface,
      child: ListTile(
        leading: Icon(
          expired
              ? Icons.warning_amber_outlined
              : Icons.workspace_premium_outlined,
          color: expired ? AppColors.error : AppColors.secondary,
        ),
        title: Text(
          (item['courseName'] ?? 'Khóa học').toString(),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          'Hoàn thành: ${formatDate(item['completedAt'])} · '
          'Hiệu lực đến: ${formatDate(item['expiresAt'])}',
        ),
        trailing: _Tag(
          label: trainingStatusLabel(item['status']?.toString()),
          color: expired ? AppColors.error : AppColors.secondary,
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E1DA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
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
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }
}
