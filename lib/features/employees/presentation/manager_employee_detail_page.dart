import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/presentation/sign_out_flow.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/repositories/employee_providers.dart';
import '../../../data/repositories/employee_repository.dart';
import '../../home/presentation/widgets/manager_more_menu.dart';

class ManagerEmployeeDetailPage extends ConsumerStatefulWidget {
  const ManagerEmployeeDetailPage({required this.employeeCode, super.key});

  /// Giá trị trên đường dẫn là mã định danh (employeeId) của nhân viên.
  final String employeeCode;

  @override
  ConsumerState<ManagerEmployeeDetailPage> createState() =>
      _ManagerEmployeeDetailPageState();
}

class _ManagerEmployeeDetailPageState
    extends ConsumerState<ManagerEmployeeDetailPage> {
  Map<String, dynamic>? _employee;
  List<Map<String, dynamic>> _training = [];
  List<Map<String, dynamic>> _skills = [];
  Map<String, dynamic> _progress = {};
  bool _canManage = false;
  bool _canAssess = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = int.tryParse(widget.employeeCode);
    if (id == null) {
      setState(() {
        _loading = false;
        _error = 'Mã nhân viên không hợp lệ.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(employeeRepositoryProvider);
      final results = await Future.wait<Object>([
        repo.getEmployeeById(id),
        repo.getEmployeeTrainings(id),
        repo.getEmployeeSkillHistory(id),
        repo.getEmployeeTrainingProgress(id),
        repo.getCurrentAccess().catchError(
          (Object _) => const CurrentAccess(roles: {}, permissions: {}),
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _employee = results[0] as Map<String, dynamic>;
        _training = results[1] as List<Map<String, dynamic>>;
        _skills = results[2] as List<Map<String, dynamic>>;
        _progress = results[3] as Map<String, dynamic>;
        _canManage = (results[4] as CurrentAccess).canManageEmployees;
        _canAssess = (results[4] as CurrentAccess).canManageTraining;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Không thể tải hồ sơ nhân viên.';
        _loading = false;
      });
    }
  }

  Future<void> _openEdit() async {
    final id = int.tryParse(widget.employeeCode);
    if (id == null) return;
    final saved = await context.push<bool>(
      RouteNames.managerEmployeeEditFor(id.toString()),
    );
    if (saved == true && mounted) await _load();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Đánh giá kỹ năng (mức 1–5, lưu thành một dòng lịch sử). Máy chủ chặn tự đánh giá chính mình.
  Future<void> _openAssessDialog() async {
    final id = int.tryParse(widget.employeeCode);
    if (id == null) return;
    final repo = ref.read(employeeRepositoryProvider);
    var skills = <Map<String, dynamic>>[];
    try {
      skills = await repo.getSkills();
    } on ApiException catch (e) {
      _snack(e.message);
      return;
    }
    if (!mounted) return;
    if (skills.isEmpty) {
      _snack('Danh mục chưa có kỹ năng. Admin cần thêm kỹ năng trước.');
      return;
    }

    int? skillId = (skills.first['skillId'] as num?)?.toInt();
    var level = 3;
    final note = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Đánh giá kỹ năng'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: skillId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Kỹ năng'),
                  items: [
                    for (final skill in skills)
                      DropdownMenuItem<int>(
                        value: (skill['skillId'] as num?)?.toInt(),
                        child: Text((skill['skillName'] ?? '').toString()),
                      ),
                  ],
                  onChanged: (value) => setDialogState(() => skillId = value),
                ),
                const SizedBox(height: 14),
                const Text('Mức đánh giá (1 cơ bản – 5 thành thạo)'),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final value in const [1, 2, 3, 4, 5])
                      ChoiceChip(
                        label: Text('$value'),
                        selected: level == value,
                        onSelected: (_) => setDialogState(() => level = value),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: note,
                  maxLines: 2,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Ghi chú (không bắt buộc)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );

    final chosenSkill = skillId;
    final noteText = note.text.trim();
    note.dispose();
    if (accepted != true || chosenSkill == null) return;

    try {
      await repo.assessEmployeeSkill(
        employeeId: id,
        skillId: chosenSkill,
        level: level,
        note: noteText.isEmpty ? null : noteText,
      );
      _snack('Đã lưu đánh giá kỹ năng.');
      if (mounted) await _load();
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  String _value(String key, [String fallback = 'Chưa cập nhật']) {
    final value = _employee?[key];
    if (value == null || value.toString().trim().isEmpty) return fallback;
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Hồ sơ nhân viên'),
        leading: IconButton(
          tooltip: 'Quay lại danh sách',
          onPressed: () => context.go(RouteNames.managerEmployees),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          if (_canManage && _employee != null)
            IconButton(
              tooltip: 'Sửa hồ sơ',
              onPressed: _openEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorView(message: _error!, onRetry: _load)
          : DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  _header(),
                  const TabBar(
                    tabs: [
                      Tab(text: 'Thông tin'),
                      Tab(text: 'Đào tạo'),
                      Tab(text: 'Kỹ năng'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [_infoTab(), _trainingTab(), _skillsTab()],
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
          if (index == 4) {
            showManagerMoreMenu(
              context,
              onSignOut: () => signOutAndReturnToLogin(context, ref),
            );
          }
        },
      ),
    );
  }

  Widget _header() {
    final name = _value('fullName', '?');
    final initial = name.trim().isEmpty
        ? '?'
        : name.trim().substring(0, 1).toUpperCase();
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          CircleAvatar(radius: 28, child: Text(initial)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _value('fullName'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 4),
                Text('${_value('employeeCode')} · ${_value('jobTitle')}'),
                const SizedBox(height: 4),
                Text(
                  employmentStatusLabel(
                    _employee?['employmentStatus']?.toString(),
                  ),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          color: AppColors.surface,
          child: Column(
            children: [
              _info('Email', _value('email')),
              _info('Số điện thoại', _value('phone')),
              _info(
                'Loại hợp đồng',
                employmentTypeLabel(_employee?['employmentType']?.toString()),
              ),
              _info(
                'Ngày vào làm',
                formatDate(_employee?['hireDate'], fallback: 'Chưa cập nhật'),
              ),
              _info(
                'Ngày sinh',
                formatDate(
                  _employee?['dateOfBirth'],
                  fallback: 'Chưa cập nhật',
                ),
              ),
              _info('Địa chỉ', _value('address')),
              _info('Liên hệ khẩn cấp', _value('emergencyContact')),
              _info('Trạng thái hồ sơ', _value('profileStatus')),
              _info('Điều kiện nhận ca', _value('shiftEligibility')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _info(String title, String value) => ListTile(
    dense: true,
    title: Text(
      title,
      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
    ),
    subtitle: Text(
      value,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _trainingTab() {
    final requiredCount = (_progress['requiredCourses'] as num?)?.toInt() ?? 0;
    final completed = (_progress['completedCourses'] as num?)?.toInt() ?? 0;
    final restricted = _progress['shiftEligibility'] == 'RESTRICTED';
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          color: AppColors.surface,
          child: ListTile(
            leading: Icon(
              restricted ? Icons.block_outlined : Icons.verified_outlined,
              color: restricted ? AppColors.error : AppColors.secondary,
            ),
            title: Text('Khóa bắt buộc: $completed/$requiredCount hoàn thành'),
            subtitle: Text(
              restricted
                  ? 'Đang bị hạn chế phân ca do thiếu khóa bắt buộc.'
                  : 'Đủ điều kiện phân ca theo khóa bắt buộc.',
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_training.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('Chưa có dữ liệu đào tạo.')),
          )
        else
          for (final item in _training) ...[
            Card(
              color: AppColors.surface,
              child: ListTile(
                leading: const Icon(
                  Icons.school_outlined,
                  color: AppColors.primary,
                ),
                title: Text((item['courseName'] ?? 'Khóa học').toString()),
                subtitle: Text(
                  'Trạng thái: ${trainingStatusLabel(item['status']?.toString())}'
                  ' · Điểm: ${formatScore(item['testScore'])}'
                  '${item['isMandatory'] == true ? ' · Bắt buộc' : ''}',
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
      ],
    );
  }

  Widget _skillsTab() {
    final latest = <int, Map<String, dynamic>>{};
    for (final item in _skills) {
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
    final assessButton = _canAssess
        ? Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FilledButton.icon(
              onPressed: _openAssessDialog,
              icon: const Icon(Icons.add_chart),
              label: const Text('Đánh giá kỹ năng'),
            ),
          )
        : null;
    if (latest.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (assessButton != null) assessButton,
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('Chưa có đánh giá kỹ năng.')),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (assessButton != null) assessButton,
        const Text(
          'Mức đánh giá gần nhất (1 cơ bản – 5 thành thạo)',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 10),
        for (final item in latest.values) ...[
          Card(
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
                          (item['skillName'] ?? 'Kỹ năng').toString(),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        'Mức ${item['level'] ?? '—'}/5',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value:
                        ((((item['level'] as num?)?.toDouble() ?? 0.0) / 5)
                                .clamp(0.0, 1.0))
                            .toDouble(),
                    minHeight: 6,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Đánh giá ngày ${formatDate(item['assessedAt'])}'
                    '${(item['note'] ?? '').toString().isEmpty ? '' : ' · ${item['note']}'}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

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
