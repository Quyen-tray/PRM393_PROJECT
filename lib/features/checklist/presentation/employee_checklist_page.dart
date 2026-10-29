import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../data/mock/demo_data.dart';
import '../../../shared/presentation/camera_capture_page.dart';

class EmployeeChecklistPage extends StatefulWidget {
  const EmployeeChecklistPage({super.key});

  @override
  State<EmployeeChecklistPage> createState() => _EmployeeChecklistPageState();
}

class _EmployeeChecklistPageState extends State<EmployeeChecklistPage> {
  final Set<int> _completedTaskIndexes = {0, 1};
  final Set<int> _existingApprovedEvidenceIndexes = {0, 1};
  final Map<int, Uint8List> _capturedEvidencePhotos = {};
  bool _isSubmitted = false;

  List<DemoChecklistTask> get _tasks => DemoData.checklistTasks;

  bool _isCompleted(int index) =>
      _tasks[index].status == DemoChecklistStatus.approved ||
      _completedTaskIndexes.contains(index);

  int get _completedCount =>
      List.generate(_tasks.length, _isCompleted).where((done) => done).length;

  bool _hasEvidence(int index) =>
      _existingApprovedEvidenceIndexes.contains(index) ||
      _capturedEvidencePhotos.containsKey(index);

  void _toggleTask(int index) {
    if (_isSubmitted ||
        _tasks[index].status == DemoChecklistStatus.approved) {
      return;
    }
    setState(() {
      if (_completedTaskIndexes.contains(index)) {
        _completedTaskIndexes.remove(index);
      } else {
        _completedTaskIndexes.add(index);
      }
    });
  }

  Future<void> _captureEvidence(int index) async {
    if (_isSubmitted) return;

    try {
      final photo = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(
          builder: (_) => const CameraCapturePage(
            preferredDirection: CameraLensDirection.back,
            title: 'Ảnh minh chứng',
            instruction: 'Chụp trực tiếp hình ảnh công việc đã hoàn thành.',
          ),
        ),
      );
      if (!mounted || photo == null) return;
      setState(() => _capturedEvidencePhotos[index] = photo);
      _showMessage('Đã chụp ảnh minh chứng trực tiếp.');
    } catch (_) {
      if (mounted) _showMessage('Không thể mở camera để chụp minh chứng.');
    }
  }

  void _submitChecklist() {
    if (_isSubmitted) return;

    final incompleteCount = List.generate(_tasks.length, (index) => index)
        .where((index) => !_isCompleted(index))
        .length;
    if (incompleteCount > 0) {
      _showMessage('Còn $incompleteCount việc chưa hoàn thành.');
      return;
    }

    final missingEvidenceCount = List.generate(_tasks.length, (index) => index)
        .where(
          (index) =>
              _tasks[index].evidenceRequired &&
              !_hasEvidence(index),
        )
        .length;
    if (missingEvidenceCount > 0) {
      _showMessage('Còn $missingEvidenceCount việc cần ảnh minh chứng.');
      return;
    }

    setState(() => _isSubmitted = true);
    _showMessage('Checklist đã gửi, đang chờ quản lý duyệt.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _statusLabel(DemoChecklistTask task, int index) {
    if (task.status == DemoChecklistStatus.approved) return 'Đã duyệt';
    if (_isCompleted(index)) {
      if (task.managerApprovalRequired && _isSubmitted) return 'Chờ duyệt';
      return task.managerApprovalRequired ? 'Đã hoàn thành' : 'Hoàn tất';
    }
    return switch (task.status) {
      DemoChecklistStatus.pending => 'Chưa làm',
      DemoChecklistStatus.inProgress => 'Đang làm',
      DemoChecklistStatus.submitted => 'Chờ duyệt',
      DemoChecklistStatus.approved => 'Đã duyệt',
      DemoChecklistStatus.rejected => 'Cần làm lại',
      DemoChecklistStatus.overdue => 'Quá hạn',
    };
  }

  Color _statusColor(DemoChecklistTask task, int index) {
    if (task.status == DemoChecklistStatus.approved) {
      return const Color(0xFF25804B);
    }
    if (_isCompleted(index)) {
      return task.managerApprovalRequired && _isSubmitted
          ? const Color(0xFFAA6500)
          : const Color(0xFF25804B);
    }
    return switch (task.status) {
      DemoChecklistStatus.pending => AppColors.textSecondary,
      DemoChecklistStatus.inProgress => const Color(0xFFD39A36),
      DemoChecklistStatus.submitted => AppColors.primary,
      DemoChecklistStatus.approved => const Color(0xFF25804B),
      DemoChecklistStatus.rejected ||
      DemoChecklistStatus.overdue => AppColors.error,
    };
  }

  @override
  Widget build(BuildContext context) {
    final progress = _tasks.isEmpty ? 0.0 : _completedCount / _tasks.length;
    final shiftLabel =
        '${DemoData.currentShift.startTime} - ${DemoData.currentShift.endTime}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Checklist đầu ca'),
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              children: [
                _ChecklistDateHeader(
                  dateLabel: DemoData.currentShift.dayLabel,
                  shiftLabel: shiftLabel,
                ),
                const SizedBox(height: 14),
                _ChecklistProgressCard(
                  completedCount: _completedCount,
                  taskCount: _tasks.length,
                  progress: progress,
                  isSubmitted: _isSubmitted,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Công việc cần hoàn thành',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      'Hạn ${DemoData.currentShift.startTime}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (var index = 0; index < _tasks.length; index++) ...[
                  _ChecklistTaskCard(
                    task: _tasks[index],
                    isCompleted: _isCompleted(index),
                    isLocked: _isSubmitted ||
                        _tasks[index].status == DemoChecklistStatus.approved,
                    isEvidenceLocked: _isSubmitted,
                    hasEvidence: _hasEvidence(index),
                    evidencePhoto: _capturedEvidencePhotos[index],
                    hasHistoricalEvidence:
                        _existingApprovedEvidenceIndexes.contains(index) &&
                            !_capturedEvidencePhotos.containsKey(index),
                    statusLabel: _statusLabel(_tasks[index], index),
                    statusColor: _statusColor(_tasks[index], index),
                    onToggle: () => _toggleTask(index),
                    onAddEvidence: () => _captureEvidence(index),
                  ),
                  if (index < _tasks.length - 1) const SizedBox(height: 9),
                ],
                if (_isSubmitted) ...[
                  const SizedBox(height: 12),
                  const _SubmittedNotice(),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ChecklistSubmitFooter(
            completedCount: _completedCount,
            taskCount: _tasks.length,
            isSubmitted: _isSubmitted,
            onSubmit: _submitChecklist,
          ),
          NavigationBar(
            selectedIndex: 2,
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
              } else if (index == 3) {
                _showMessage('Hồ sơ cá nhân sẽ được hoàn thiện sau.');
              }
            },
          ),
        ],
      ),
    );
  }
}

class _ChecklistDateHeader extends StatelessWidget {
  const _ChecklistDateHeader({
    required this.dateLabel,
    required this.shiftLabel,
  });

  final String dateLabel;
  final String shiftLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.calendar_today_outlined,
          color: AppColors.primary,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateLabel,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Ca sáng · $shiftLabel',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFE4F5E9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Đầu ca',
            style: TextStyle(
              color: Color(0xFF25804B),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChecklistProgressCard extends StatelessWidget {
  const _ChecklistProgressCard({
    required this.completedCount,
    required this.taskCount,
    required this.progress,
    required this.isSubmitted,
  });

  final int completedCount;
  final int taskCount;
  final double progress;
  final bool isSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
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
              const Expanded(
                child: Text(
                  'Tiến độ checklist',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$completedCount/$taskCount hoàn tất',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFFECE8E3),
              color: const Color(0xFF31A779),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSubmitted
                ? 'Đã gửi checklist cho quản lý.'
                : 'Hoàn tất công việc và ảnh minh chứng trước giờ vào ca.',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistTaskCard extends StatelessWidget {
  const _ChecklistTaskCard({
    required this.task,
    required this.isCompleted,
    required this.isLocked,
    required this.isEvidenceLocked,
    required this.hasEvidence,
    required this.evidencePhoto,
    required this.hasHistoricalEvidence,
    required this.statusLabel,
    required this.statusColor,
    required this.onToggle,
    required this.onAddEvidence,
  });

  final DemoChecklistTask task;
  final bool isCompleted;
  final bool isLocked;
  final bool isEvidenceLocked;
  final bool hasEvidence;
  final Uint8List? evidencePhoto;
  final bool hasHistoricalEvidence;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback onToggle;
  final VoidCallback onAddEvidence;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 9),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFEDE8E3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Checkbox(
                value: isCompleted,
                activeColor: const Color(0xFF179447),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: isLocked ? null : (_) => onToggle(),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        decoration:
                            task.status == DemoChecklistStatus.approved
                                ? TextDecoration.lineThrough
                                : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hạn ${task.dueTime}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              _StatusChip(label: statusLabel, color: statusColor),
            ],
          ),
          if (task.evidenceRequired) ...[
            const Divider(height: 12, indent: 42),
            Padding(
              padding: const EdgeInsets.only(left: 42),
              child: Row(
                children: [
                  if (hasEvidence) ...[
                    _EvidenceThumbnail(photoBytes: evidencePhoto),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        evidencePhoto != null
                            ? 'Ảnh đã chụp trực tiếp'
                            : hasHistoricalEvidence
                                ? 'Minh chứng mẫu đã duyệt'
                                : 'Ảnh đã chụp trực tiếp',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ] else
                    const Expanded(
                      child: Text(
                        'Cần ảnh minh chứng',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  IconButton(
                    tooltip: hasEvidence
                        ? 'Chụp lại ảnh minh chứng'
                        : 'Chụp ảnh minh chứng',
                    visualDensity: VisualDensity.compact,
                    onPressed: isEvidenceLocked ? null : onAddEvidence,
                    icon: const Icon(
                      Icons.add_a_photo_outlined,
                      size: 18,
                      color: AppColors.primary,
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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

class _EvidenceThumbnail extends StatelessWidget {
  const _EvidenceThumbnail({this.photoBytes});

  final Uint8List? photoBytes;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFFECE3D8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: photoBytes == null
          ? const Icon(
              Icons.verified_outlined,
              color: Color(0xFF8B6B53),
              size: 18,
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.memory(photoBytes!, fit: BoxFit.cover),
            ),
    );
  }
}

class _SubmittedNotice extends StatelessWidget {
  const _SubmittedNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1D9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Icon(Icons.schedule, color: Color(0xFFAA6500), size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Checklist đã gửi và đang chờ quản lý duyệt.',
              style: TextStyle(
                color: Color(0xFF80520E),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistSubmitFooter extends StatelessWidget {
  const _ChecklistSubmitFooter({
    required this.completedCount,
    required this.taskCount,
    required this.isSubmitted,
    required this.onSubmit,
  });

  final int completedCount;
  final int taskCount;
  final bool isSubmitted;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: Color(0xFFE9E6E1))),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: isSubmitted ? null : onSubmit,
                icon: Icon(
                  isSubmitted
                      ? Icons.check_circle_outline
                      : Icons.send_outlined,
                  size: 18,
                ),
                label: Text(
                  isSubmitted
                      ? 'Đã gửi checklist'
                      : 'Gửi checklist ($completedCount/$taskCount)',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
