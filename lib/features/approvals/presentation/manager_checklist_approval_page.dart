import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/repositories/employee_providers.dart';
import '../../home/presentation/widgets/manager_bottom_navigation.dart';
import '../data/manager_review_items.dart';
import 'widgets/manager_review_list.dart';

/// Duyệt checklist: các checklist nhân viên đã nộp, chờ quản lý duyệt, lấy từ API.
class ManagerChecklistApprovalPage extends ConsumerStatefulWidget {
  const ManagerChecklistApprovalPage({super.key});

  @override
  ConsumerState<ManagerChecklistApprovalPage> createState() =>
      _ManagerChecklistApprovalPageState();
}

class _ManagerChecklistApprovalPageState
    extends ConsumerState<ManagerChecklistApprovalPage> {
  static const _kinds = {ManagerReviewKind.checklist};

  List<ManagerReviewItem> _pending = [];
  List<ManagerReviewItem> _processed = [];
  bool _loading = true;
  bool _acting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final buckets = await loadManagerReviewBuckets(
        ref.read(employeeRepositoryProvider),
        kinds: _kinds,
      );
      if (!mounted) return;
      setState(() {
        _pending = buckets.pending;
        _processed = [...buckets.approved, ...buckets.rejected];
      });
    } catch (error) {
      if (mounted) setState(() => _error = _messageOf(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(ManagerReviewItem item) => _run(
    () => approveManagerReviewItem(ref.read(employeeRepositoryProvider), item),
    'Đã duyệt checklist.',
  );

  Future<void> _reject(ManagerReviewItem item, String reason) => _run(
    () => rejectManagerReviewItem(
      ref.read(employeeRepositoryProvider),
      item,
      reason: reason,
    ),
    'Đã từ chối checklist.',
  );

  Future<void> _openChecklist(ManagerReviewItem item) async {
    try {
      final detail = await ref
          .read(employeeRepositoryProvider)
          .getChecklistTask(item.id);
      if (!mounted) return;
      final reassign = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text(
                'Checklist #${item.id}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              for (final entry in detail.entries)
                ListTile(
                  dense: true,
                  title: Text(entry.key),
                  subtitle: SelectableText('${entry.value ?? '—'}'),
                ),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(sheetContext, true),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Chuyển người thực hiện'),
              ),
            ],
          ),
        ),
      );
      if (reassign == true && mounted) await _reassign(item);
    } catch (error) {
      _message(_messageOf(error));
    }
  }

  Future<void> _reassign(ManagerReviewItem item) async {
    try {
      final employees = await ref
          .read(employeeRepositoryProvider)
          .getEmployees(status: 'ACTIVE');
      if (!mounted) {
        return _message(
          'Không có nhân viên đang làm việc để chuyển checklist.',
        );
      }
      int? selected = employees.isEmpty
          ? null
          : (employees.first['employeeId'] as num?)?.toInt();
      if (selected == null) {
        return _message(
          'Không có nhân viên đang làm việc để chuyển checklist.',
        );
      }
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Chuyển người thực hiện'),
            content: DropdownButtonFormField<int>(
              initialValue: selected,
              decoration: const InputDecoration(
                labelText: 'Nhân viên nhận việc',
              ),
              items: [
                for (final employee in employees)
                  if (employee['employeeId'] is num)
                    DropdownMenuItem(
                      value: (employee['employeeId'] as num).toInt(),
                      child: Text(
                        '${employee['fullName'] ?? employee['employeeCode'] ?? 'Nhân viên'}',
                      ),
                    ),
              ],
              onChanged: (value) => setDialogState(() => selected = value),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: selected == null
                    ? null
                    : () => Navigator.pop(dialogContext, true),
                child: const Text('Chuyển'),
              ),
            ],
          ),
        ),
      );
      if (accepted != true || selected == null) return;
      await ref
          .read(employeeRepositoryProvider)
          .reassignChecklistTask(taskId: item.id, employeeId: selected!);
      _message('Đã chuyển checklist.');
      await _load();
    } catch (error) {
      _message(_messageOf(error));
    }
  }

  Future<void> _generateChecklist() async {
    try {
      final repo = ref.read(employeeRepositoryProvider);
      final today = DateTime.now();
      String iso(DateTime value) =>
          '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
      final results = await Future.wait<Object>([
        repo.getAdminChecklistTemplates(),
        repo.getShiftAssignments(
          from: iso(today),
          to: iso(today.add(const Duration(days: 7))),
        ),
      ]);
      if (!mounted) return;
      final templates = (results[0] as List<Map<String, dynamic>>)
          .where((row) => row['isActive'] == true)
          .toList();
      final assignments = results[1] as List<Map<String, dynamic>>;
      int? idOf(Object? value) => value is num ? value.toInt() : null;
      int? templateIdOf(Map<String, dynamic> row) =>
          idOf(row['templateId'] ?? row['checklistTemplateId']);
      if (templates.isEmpty || assignments.isEmpty) {
        return _message(
          'Cần có mẫu checklist đang hoạt động và lịch ca trong 7 ngày tới.',
        );
      }
      int? templateId = templateIdOf(templates.first);
      int? assignmentId = idOf(assignments.first['assignmentId']);
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Tạo checklist cho ca'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: templateId,
                  decoration: const InputDecoration(labelText: 'Mẫu checklist'),
                  items: [
                    for (final row in templates)
                      if (templateIdOf(row) != null)
                        DropdownMenuItem(
                          value: templateIdOf(row),
                          child: Text(
                            '${row['checklistName'] ?? row['checklistCode'] ?? 'Checklist'}',
                          ),
                        ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => templateId = value),
                ),
                DropdownButtonFormField<int>(
                  initialValue: assignmentId,
                  decoration: const InputDecoration(
                    labelText: 'Ca và nhân viên',
                  ),
                  items: [
                    for (final row in assignments)
                      if (idOf(row['assignmentId']) != null)
                        DropdownMenuItem(
                          value: idOf(row['assignmentId']),
                          child: Text(
                            '${row['employeeName'] ?? 'NV ${row['employeeId'] ?? ''}'} · ${row['workDate'] ?? ''}',
                          ),
                        ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => assignmentId = value),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: templateId == null || assignmentId == null
                    ? null
                    : () => Navigator.pop(dialogContext, true),
                child: const Text('Tạo checklist'),
              ),
            ],
          ),
        ),
      );
      if (accepted != true || templateId == null || assignmentId == null) {
        return;
      }
      final assignment = assignments.firstWhere(
        (row) => idOf(row['assignmentId']) == assignmentId,
      );
      final employeeId = idOf(assignment['employeeId']);
      if (employeeId == null) return _message('Lịch ca thiếu mã nhân viên.');
      await repo.generateChecklist(
        templateId: templateId!,
        scheduleId: assignmentId!,
        employeeId: employeeId,
        workDate: '${assignment['workDate']}',
      );
      _message('Đã tạo checklist.');
      await _load();
    } catch (error) {
      _message(_messageOf(error));
    }
  }

  Future<void> _run(
    Future<void> Function() action,
    String successMessage,
  ) async {
    setState(() => _acting = true);
    try {
      await action();
      _message(successMessage);
      await _load();
    } catch (error) {
      _message(_messageOf(error));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  String _messageOf(Object error) => error is ApiException
      ? error.message
      : 'Không tải được checklist. Vui lòng thử lại.';

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final busy = _loading || _acting;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Quay lại',
            onPressed: () => context.go(RouteNames.managerApprovals),
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Text('Duyệt checklist'),
          actions: [
            IconButton(
              tooltip: 'Tạo checklist cho ca',
              onPressed: busy ? null : _generateChecklist,
              icon: const Icon(Icons.add_task),
            ),
            IconButton(
              tooltip: 'Tải lại',
              onPressed: busy ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'Duyệt yêu cầu',
              onPressed: () => context.go(RouteNames.managerApprovals),
              icon: const Icon(Icons.inbox_outlined),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: 'Chờ duyệt (${_pending.length})'),
              const Tab(text: 'Đã xử lý'),
            ],
          ),
        ),
        body:
            _loading && _pending.isEmpty && _processed.isEmpty && _error == null
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _pending.isEmpty && _processed.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _load,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              )
            : TabBarView(
                children: [
                  ManagerReviewList(
                    items: _pending,
                    emptyMessage: 'Không có checklist đang chờ duyệt.',
                    busy: busy,
                    onApprove: _approve,
                    onReject: _reject,
                    onRefresh: _load,
                    onSelect: _openChecklist,
                  ),
                  ManagerReviewList(
                    items: _processed,
                    emptyMessage: 'Chưa có checklist đã xử lý.',
                    busy: busy,
                    onApprove: _approve,
                    onReject: _reject,
                    onRefresh: _load,
                    onSelect: _openChecklist,
                  ),
                ],
              ),
        bottomNavigationBar: const ManagerBottomNavigation(selectedIndex: 3),
      ),
    );
  }
}
