import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../data/mock/demo_data.dart';
import '../../home/presentation/widgets/manager_more_menu.dart';

class ManagerEmployeeDetailPage extends StatelessWidget {
  const ManagerEmployeeDetailPage({
    required this.employeeCode,
    super.key,
  });

  final String employeeCode;

  @override
  Widget build(BuildContext context) {
    DemoManagerEmployee? employee;
    for (final item in DemoData.managerEmployees) {
      if (item.employeeCode == employeeCode) {
        employee = item;
        break;
      }
    }

    if (employee == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Hồ sơ nhân viên'),
          leading: IconButton(
            tooltip: 'Quay lại danh sách',
            onPressed: () => context.go(RouteNames.managerEmployees),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: const Center(child: Text('Không tìm thấy nhân viên.')),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Hồ sơ nhân viên'),
          leading: IconButton(
            tooltip: 'Quay lại danh sách',
            onPressed: () => context.go(RouteNames.managerEmployees),
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                child: _EmployeeHeader(employee: employee),
              ),
              const TabBar(
                tabs: [
                  Tab(text: 'Thông tin'),
                  Tab(text: 'Đào tạo'),
                  Tab(text: 'Kỹ năng'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _EmployeeInformationTab(employee: employee),
                    const _EmployeeTrainingTab(),
                    const _EmployeeSkillsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: 1,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Tổng quan',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Nhân viên',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Lịch',
            ),
            NavigationDestination(
              icon: Icon(Icons.fact_check_outlined),
              selectedIcon: Icon(Icons.fact_check),
              label: 'Duyệt',
            ),
            NavigationDestination(
              icon: Icon(Icons.more_horiz),
              selectedIcon: Icon(Icons.more_horiz),
              label: 'Khác',
            ),
          ],
          onDestinationSelected: (index) {
            if (index == 0) context.go(RouteNames.home);
            if (index == 1) context.go(RouteNames.managerEmployees);
            if (index == 2) context.go(RouteNames.managerSchedule);
            if (index == 3) context.go(RouteNames.managerApprovals);
            if (index == 4) showManagerMoreMenu(context);
          },
        ),
      ),
    );
  }
}

class _EmployeeHeader extends StatelessWidget {
  const _EmployeeHeader({required this.employee});

  final DemoManagerEmployee employee;

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = switch (employee.status) {
      DemoManagerEmployeeStatus.working => (
          'Đang làm',
          const Color(0xFF25804B),
        ),
      DemoManagerEmployeeStatus.paused => (
          'Tạm nghỉ',
          const Color(0xFFB96D17),
        ),
      DemoManagerEmployeeStatus.onLeave => (
          'Nghỉ phép',
          const Color(0xFF487DA3),
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDE8E3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Color(employee.avatarColorValue),
            child: Text(
              employee.initials,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${employee.employeeCode} · ${employee.position}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeInformationTab extends StatelessWidget {
  const _EmployeeInformationTab({required this.employee});

  final DemoManagerEmployee employee;

  @override
  Widget build(BuildContext context) {
    final statusLabel = switch (employee.status) {
      DemoManagerEmployeeStatus.working => 'Đang làm',
      DemoManagerEmployeeStatus.paused => 'Tạm nghỉ',
      DemoManagerEmployeeStatus.onLeave => 'Nghỉ phép',
    };

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _InformationCard(
          title: 'Thông tin công việc',
          rows: [
            ('Mã nhân viên', employee.employeeCode),
            ('Chức vụ', employee.position),
            ('Trạng thái', statusLabel),
            ('Chi nhánh', DemoData.storeBranch),
          ],
        ),
        const SizedBox(height: 12),
        const _InformationCard(
          title: 'Ghi chú',
          rows: [
            ('Nguồn dữ liệu', 'Hồ sơ demo cố định'),
            ('Quản lý trực tiếp', 'Trần Thị Bích Ngọc'),
          ],
        ),
      ],
    );
  }
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

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
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          for (final (label, value) in rows) ...[
            const Divider(height: 1, color: Color(0xFFEDE8E3)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      value,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmployeeTrainingTab extends StatelessWidget {
  const _EmployeeTrainingTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Tiến độ khóa học demo của nhân viên',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),
        for (final course in DemoData.trainingCourses) ...[
          _TrainingCourseCard(course: course),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _TrainingCourseCard extends StatelessWidget {
  const _TrainingCourseCard({required this.course});

  final DemoTrainingCourse course;

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor) = switch (course.status) {
      DemoTrainingStatus.complete => ('Hoàn thành', const Color(0xFF25804B)),
      DemoTrainingStatus.inProgress => ('Đang học', const Color(0xFFB96D17)),
      DemoTrainingStatus.expired => ('Hết hạn', AppColors.error),
    };

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
              Expanded(
                child: Text(
                  course.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$statusLabel · ${course.progressPercent}%',
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: course.progressPercent / 100,
              minHeight: 7,
              backgroundColor: const Color(0xFFEDE8E3),
              color: statusColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${course.category} · Hạn ${course.dueDate}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
          if (course.blocksShiftAssignment) ...[
            const SizedBox(height: 4),
            const Text(
              'Khóa học bắt buộc trước khi phân ca.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmployeeSkillsTab extends StatelessWidget {
  const _EmployeeSkillsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Kết quả đánh giá kỹ năng mẫu',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),
        for (final skill in DemoData.managerEmployeeSkills) ...[
          _SkillAssessmentCard(skill: skill),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _SkillAssessmentCard extends StatelessWidget {
  const _SkillAssessmentCard({required this.skill});

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
              Expanded(
                child: Text(
                  skill.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${skill.levelLabel} · ${skill.scorePercent}%',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: skill.scorePercent / 100,
              minHeight: 7,
              backgroundColor: const Color(0xFFEDE8E3),
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Đánh giá gần nhất: ${skill.evaluatedAt}',
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
