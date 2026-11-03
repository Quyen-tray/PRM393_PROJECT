import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/repositories/employee_providers.dart';
import '../data/checklist_providers.dart';
import '../../../shared/widgets/employee_bottom_navigation.dart';
import '../../../shared/presentation/camera_capture_page.dart';

class EmployeeChecklistPage extends ConsumerStatefulWidget {
  const EmployeeChecklistPage({super.key});

  @override
  ConsumerState<EmployeeChecklistPage> createState() =>
      _EmployeeChecklistPageState();
}

class _EmployeeChecklistPageState extends ConsumerState<EmployeeChecklistPage> {
  final Map<int, Uint8List> _capturedEvidencePhotos = {};
  final Set<int> _completedTaskIndexes = {};
  final Set<int> _existingApprovedEvidenceIndexes = {};
  List<Map<String, dynamic>> _runs = [];
  Map<String, dynamic>? _activeRun;
  bool _isLoading = true;
  bool _isWorking = false;
  String? _loadError;
  bool _isSubmitted = false;

  List<Map<String, dynamic>> get _runItems =>
      (_activeRun?['items'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

  List<_ChecklistTaskView> get _tasks => _runItems.map((item) {
    final status = (_activeRun?['status'] ?? '').toString().toUpperCase();
    return _ChecklistTaskView(
      title: (item['itemName'] ?? 'Công việc').toString(),
      dueTime: _formatTime(_activeRun?['dueAt']),
      evidenceRequired: item['requiresEvidence'] == true,
      isRequired: item['isRequired'] != false,
      isApproved: status == 'APPROVED',
    );
  }).toList();

  int? get _taskId => (_activeRun?['taskId'] as num?)?.toInt();

  @override
  void initState() {
    super.initState();
    _loadChecklists();
  }

  Future<void> _loadChecklists() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final repository = ref.read(checklistRepositoryProvider);
      final summaries = await repository.getMyChecklists();
      if (!mounted) return;
      final previouslySelectedId = _taskId;
      final selected =
          summaries.where((run) {
            return (run['taskId'] as num?)?.toInt() == previouslySelectedId;
          }).firstOrNull ??
          summaries.where((run) {
            final status = (run['status'] ?? '').toString().toUpperCase();
            return status != 'APPROVED' && status != 'SUBMITTED';
          }).firstOrNull ??
          (summaries.isNotEmpty ? summaries.first : null);
      if (selected == null) {
        setState(() {
          _runs = summaries;
          _selectRun(null);
        });
        return;
      }
      final selectedId = (selected['taskId'] as num?)?.toInt();
      final details = selectedId == null
          ? <String, dynamic>{}
          : await repository.getChecklist(selectedId);
      if (!mounted) return;
      final selectedRun = {...selected, ...details};
      setState(() {
        _runs = summaries
            .map(
              (run) => (run['taskId'] as num?)?.toInt() == selectedId
                  ? selectedRun
                  : run,
            )
            .toList();
        _selectRun(selectedRun);
      });
    } catch (error) {
      if (mounted) setState(() => _loadError = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _selectRun(Map<String, dynamic>? run) {
    _activeRun = run;
    final status = (run?['status'] ?? '').toString().toUpperCase();
    _isSubmitted = run != null && ['SUBMITTED', 'APPROVED'].contains(status);
    _completedTaskIndexes.clear();
    _existingApprovedEvidenceIndexes.clear();
    _capturedEvidencePhotos.clear();
    for (
      var index = 0;
      index < ((run?['items'] as List?)?.length ?? 0);
      index++
    ) {
      final item = (run!['items'] as List)[index];
      if (item is Map && item['isCompleted'] == true) {
        _completedTaskIndexes.add(index);
      }
      if (item is Map && item['hasEvidence'] == true) {
        _existingApprovedEvidenceIndexes.add(index);
      }
    }
  }

  Future<void> _loadRun(Map<String, dynamic> summary) async {
    final taskId = (summary['taskId'] as num?)?.toInt();
    if (taskId == null || _isWorking) return;
    setState(() => _isWorking = true);
    try {
      final details = await ref
          .read(checklistRepositoryProvider)
          .getChecklist(taskId);
      if (!mounted) return;
      final selectedRun = {...summary, ...details};
      setState(() {
        _runs = _runs
            .map(
              (run) => (run['taskId'] as num?)?.toInt() == taskId
                  ? selectedRun
                  : run,
            )
            .toList();
        _selectRun(selectedRun);
      });
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  String _formatTime(dynamic value) => formatClockVn(value);

  bool _isCompleted(int index) =>
      _completedTaskIndexes.contains(index) ||
      (_runItems[index]['isCompleted'] == true);

  int get _completedCount =>
      List.generate(_tasks.length, _isCompleted).where((done) => done).length;

  bool _hasEvidence(int index) =>
      _existingApprovedEvidenceIndexes.contains(index) ||
      (_runItems[index]['hasEvidence'] == true) ||
      _capturedEvidencePhotos.containsKey(index);

  Future<void> _toggleTask(int index) async {
    if (_isSubmitted || _isWorking || _isCompleted(index)) return;
    final taskId = _taskId;
    final runItemId = (_runItems[index]['runItemId'] as num?)?.toInt();
    if (taskId == null || runItemId == null) return;
    setState(() => _isWorking = true);
    try {
      final repository = ref.read(checklistRepositoryProvider);
      final status = (_activeRun?['status'] ?? '').toString().toUpperCase();
      if (['PENDING', 'REJECTED', 'OVERDUE'].contains(status)) {
        await repository.startChecklist(taskId);
      }
      await repository.completeItem(taskId: taskId, runItemId: runItemId);
      await _loadChecklists();
      _showMessage('Đã cập nhật công việc.');
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _captureEvidence(int index) async {
    if (_isSubmitted || _isWorking) return;
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
      final taskId = _taskId;
      final runItemId = (_runItems[index]['runItemId'] as num?)?.toInt();
      if (taskId == null || runItemId == null) return;
      setState(() => _isWorking = true);
      final checklistRepository = ref.read(checklistRepositoryProvider);
      final status = (_activeRun?['status'] ?? '').toString().toUpperCase();
      if (['PENDING', 'REJECTED', 'OVERDUE'].contains(status)) {
        await checklistRepository.startChecklist(taskId);
      }
      final storageKey = await ref
          .read(employeeRepositoryProvider)
          .uploadImage(bytes: photo, purpose: 'CHECKLIST');
      await checklistRepository.addEvidence(
        taskId: taskId,
        runItemId: runItemId,
        storageKey: storageKey,
      );
      if (!mounted) return;
      setState(() => _capturedEvidencePhotos[index] = photo);
      await _loadChecklists();
      _showMessage('Đã tải ảnh minh chứng lên máy chủ.');
    } catch (error) {
      if (mounted) _showMessage('Không thể gửi ảnh minh chứng: $error');
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  Future<void> _submitChecklist() async {
    if (_isSubmitted || _isWorking) return;
    final incompleteCount = List.generate(
      _tasks.length,
      (index) => index,
    ).where((index) => _tasks[index].isRequired && !_isCompleted(index)).length;
    if (incompleteCount > 0) {
      _showMessage('Còn $incompleteCount việc chưa hoàn thành.');
      return;
    }
    final missingEvidenceCount = List.generate(_tasks.length, (index) => index)
        .where(
          (index) =>
              _tasks[index].evidenceRequired &&
              _isCompleted(index) &&
              !_hasEvidence(index),
        )
        .length;
    if (missingEvidenceCount > 0) {
      _showMessage('Còn $missingEvidenceCount việc cần ảnh minh chứng.');
      return;
    }
    final taskId = _taskId;
    if (taskId == null) return;
    setState(() => _isWorking = true);
    try {
      final repository = ref.read(checklistRepositoryProvider);
      final status = (_activeRun?['status'] ?? '').toString().toUpperCase();
      if (['PENDING', 'REJECTED'].contains(status)) {
        final startedRun = await repository.startChecklist(taskId);
        if (!mounted) return;
        final currentRun = _activeRun;
        if (currentRun != null) {
          final mergedRun = {...currentRun, ...startedRun};
          setState(() {
            _activeRun = mergedRun;
            _runs = _runs
                .map(
                  (run) => (run['taskId'] as num?)?.toInt() == taskId
                      ? mergedRun
                      : run,
                )
                .toList();
          });
        }
      }
      final updatedRun = await repository.submitChecklist(taskId);
      if (!mounted) return;
      final currentRun = _activeRun;
      if (currentRun != null) {
        final mergedRun = {...currentRun, ...updatedRun};
        setState(() {
          _activeRun = mergedRun;
          _runs = _runs
              .map(
                (run) => (run['taskId'] as num?)?.toInt() == taskId
                    ? mergedRun
                    : run,
              )
              .toList();
          _isSubmitted = [
            'SUBMITTED',
            'APPROVED',
          ].contains((mergedRun['status'] ?? '').toString().toUpperCase());
        });
      }
      _showMessage(
        (updatedRun['status'] ?? '').toString().toUpperCase() == 'APPROVED'
            ? 'Checklist đã hoàn tất.'
            : 'Checklist đã gửi cho quản lý.',
      );
    } catch (error) {
      _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _statusLabel(int index) {
    if (_isCompleted(index)) return 'Hoàn tất';
    final status = (_activeRun?['status'] ?? '').toString().toUpperCase();
    if (status == 'SUBMITTED') return 'Chờ duyệt';
    if (status == 'REJECTED') return 'Cần làm lại';
    if (status == 'OVERDUE') return 'Quá hạn';
    return 'Chưa làm';
  }

  Color _statusColor(int index) {
    if (_isCompleted(index)) return const Color(0xFF25804B);
    final status = (_activeRun?['status'] ?? '').toString().toUpperCase();
    if (status == 'REJECTED' || status == 'OVERDUE') return AppColors.error;
    return AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    final progress = _tasks.isEmpty ? 0.0 : _completedCount / _tasks.length;
    final checklistName =
        (_activeRun?['checklistName'] ?? 'Checklist công việc').toString();
    final dateLabel = formatDate(
      _activeRun?['dueAt'],
      fallback: 'Checklist được giao',
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Checklist công việc'),
        leading: IconButton(
          tooltip: 'Quay lại trang chủ',
          onPressed: () => context.go(RouteNames.employeeHome),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadChecklists,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_loadError!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _loadChecklists,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              )
            : _activeRun == null
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Hiện chưa có checklist nào được giao.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                    children: [
                      _ChecklistDateHeader(
                        dateLabel: dateLabel,
                        shiftLabel: checklistName,
                      ),
                      if (_runs.length > 1) ...[
                        const SizedBox(height: 14),
                        const Text(
                          'Checklist được giao',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final run in _runs)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(
                                      (run['checklistName'] ?? 'Checklist')
                                          .toString(),
                                    ),
                                    selected:
                                        (run['taskId'] as num?)?.toInt() ==
                                        _taskId,
                                    onSelected: _isWorking
                                        ? null
                                        : (_) => _loadRun(run),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      _ChecklistProgressCard(
                        completedCount: _completedCount,
                        taskCount: _tasks.length,
                        progress: progress,
                        isSubmitted: _isSubmitted,
                      ),
                      if ((_activeRun?['status'] ?? '')
                                  .toString()
                                  .toUpperCase() ==
                              'REJECTED' &&
                          (_activeRun?['reviewNote']?.toString().trim() ?? '')
                              .isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Card(
                          child: ListTile(
                            leading: const Icon(
                              Icons.info_outline,
                              color: AppColors.error,
                            ),
                            title: const Text(
                              'Lý do cần làm lại',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              _activeRun!['reviewNote'].toString(),
                            ),
                          ),
                        ),
                      ],
                      if (_isWorking) const LinearProgressIndicator(),
                      const SizedBox(height: 20),
                      const Text(
                        'Công việc cần hoàn thành',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (var index = 0; index < _tasks.length; index++) ...[
                        _ChecklistTaskCard(
                          task: _tasks[index],
                          isCompleted: _isCompleted(index),
                          isLocked:
                              _isSubmitted || _isWorking || _isCompleted(index),
                          isEvidenceLocked: _isSubmitted || _isWorking,
                          hasEvidence: _hasEvidence(index),
                          evidencePhoto: _capturedEvidencePhotos[index],
                          hasHistoricalEvidence:
                              _existingApprovedEvidenceIndexes.contains(
                                index,
                              ) &&
                              !_capturedEvidencePhotos.containsKey(index),
                          statusLabel: _statusLabel(index),
                          statusColor: _statusColor(index),
                          onToggle: () => _toggleTask(index),
                          onAddEvidence: () => _captureEvidence(index),
                        ),
                        if (index < _tasks.length - 1)
                          const SizedBox(height: 9),
                      ],
                      if (_isSubmitted)
                        _SubmittedNotice(
                          status: (_activeRun?['status'] ?? '')
                              .toString()
                              .toUpperCase(),
                        ),
                    ],
                  ),
                ),
              ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_activeRun != null)
            _ChecklistSubmitFooter(
              completedCount: _completedCount,
              taskCount: _tasks.length,
              isSubmitted: _isSubmitted || _isWorking,
              onSubmit: _submitChecklist,
            ),
          const EmployeeBottomNavigation(selectedIndex: 2),
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

class _ChecklistTaskView {
  const _ChecklistTaskView({
    required this.title,
    required this.dueTime,
    required this.evidenceRequired,
    required this.isRequired,
    required this.isApproved,
  });

  final String title;
  final String dueTime;
  final bool evidenceRequired;
  final bool isRequired;
  final bool isApproved;
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

  final _ChecklistTaskView task;
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
                        decoration: task.isApproved
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
  const _SubmittedNotice({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1D9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            status == 'APPROVED' ? Icons.check_circle_outline : Icons.schedule,
            color: Color(0xFFAA6500),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              status == 'APPROVED'
                  ? 'Checklist đã được hoàn tất.'
                  : 'Checklist đã gửi và đang chờ quản lý duyệt.',
              style: const TextStyle(
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
