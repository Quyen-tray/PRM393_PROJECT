import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/repositories/employee_providers.dart';
import '../../../data/repositories/employee_repository.dart';
import '../../home/presentation/widgets/manager_bottom_navigation.dart';
import '../../documents/presentation/employee_documents_tab.dart';

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
  List<Map<String, dynamic>> _documents = [];
  Map<String, dynamic> _progress = {};
  Map<String, dynamic> _attendanceSummary = {};
  bool _canManage = false;
  bool _canAssess = false;
  bool _canReviewDocuments = false;
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
      final today = DateTime.now();
      final monthStart = DateTime(today.year, today.month, 1);
      String iso(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final results = await Future.wait<Object>([
        repo.getEmployeeById(id),
        repo.getEmployeeTrainings(id),
        repo.getEmployeeSkillHistory(id),
        repo.getEmployeeTrainingProgress(id),
        repo.getEmployeeAttendanceSummary(
          id,
          from: iso(monthStart),
          to: iso(today),
        ),
        repo.getEmployeeDocuments(id),
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
        _attendanceSummary = results[4] as Map<String, dynamic>;
        _documents = results[5] as List<Map<String, dynamic>>;
        _canManage = (results[6] as CurrentAccess).canManageEmployees;
        _canAssess = (results[6] as CurrentAccess).canManageTraining;
        _canReviewDocuments = (results[6] as CurrentAccess).canReviewDocuments;
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
              length: 5,
              child: Column(
                children: [
                  _header(),
                  const TabBar(
                    tabs: [
                      Tab(text: 'Thông tin'),
                      Tab(text: 'Chấm công'),
                      Tab(text: 'Đào tạo'),
                      Tab(text: 'Kỹ năng'),
                      Tab(text: 'Hồ sơ'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _infoTab(),
                        _attendanceTab(),
                        _trainingTab(),
                        _skillsTab(),
                        _documentsTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: const ManagerBottomNavigation(selectedIndex: 1),
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

  Widget _attendanceTab() {
    if (_attendanceSummary.isEmpty) {
      return const Center(child: Text('Chưa có dữ liệu tổng hợp chấm công.'));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text(
          'Tổng hợp từ đầu tháng đến hiện tại',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Card(
          color: AppColors.surface,
          child: Column(
            children: [
              for (final entry in _attendanceSummary.entries)
                ListTile(
                  dense: true,
                  title: Text(entry.key),
                  trailing: Text(
                    '${entry.value ?? '—'}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _documentsTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_canReviewDocuments)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FilledButton.icon(
              onPressed: _submitDocumentForEmployee,
              icon: const Icon(Icons.upload_file),
              label: const Text('Nộp hồ sơ thay nhân viên'),
            ),
          ),
        if (_documents.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('Nhân viên chưa nộp hồ sơ.')),
          ),
        for (final item in _documents)
          Card(
            color: AppColors.surface,
            child: ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(
                '${item['documentName'] ?? item['documentTypeName'] ?? 'Hồ sơ'}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${item['status'] ?? ''} · ${formatDate(item['submittedAt'] ?? item['createdAt'])}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showDocumentDetail(item),
            ),
          ),
      ],
    );
  }

  Future<void> _submitDocumentForEmployee() async {
    final employeeId = int.tryParse(widget.employeeCode);
    if (employeeId == null) return;
    final controller = TextEditingController(
      text: _documents.isEmpty
          ? ''
          : '${_documents.first['documentTypeId'] ?? ''}',
    );
    final formKey = GlobalKey<FormState>();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nộp hồ sơ thay nhân viên'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Mã loại hồ sơ',
              helperText: 'Chọn mã loại hồ sơ từ danh mục do Admin thiết lập.',
            ),
            validator: (value) => int.tryParse(value?.trim() ?? '') == null
                ? 'Nhập mã loại hồ sơ hợp lệ.'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Chọn tệp'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) {
      controller.dispose();
      return;
    }
    try {
      final file = await const PlatformDocumentPicker().pickDocument();
      if (file == null || !mounted) return;
      final repo = ref.read(employeeRepositoryProvider);
      final storageKey = await repo.uploadDocument(
        bytes: file.bytes,
        contentType: file.contentType,
        targetEmployeeId: employeeId,
      );
      await repo.submitDocumentForEmployee(
        employeeId: employeeId,
        documentTypeId: int.parse(controller.text.trim()),
        storageKey: storageKey,
      );
      await _load();
      _snack('Đã nộp hồ sơ thay nhân viên.');
    } catch (error) {
      _snack(error is ApiException ? error.message : 'Không nộp được hồ sơ.');
    } finally {
      controller.dispose();
    }
  }

  Future<void> _showDocumentDetail(Map<String, dynamic> item) async {
    final id = (item['documentId'] ?? item['employeeDocumentId']) as num?;
    if (id == null) return;
    try {
      final document = await ref
          .read(employeeRepositoryProvider)
          .getDocument(id.toInt());
      if (!mounted) return;
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text(
                'Hồ sơ #${id.toInt()}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              for (final entry in document.entries)
                ListTile(
                  dense: true,
                  title: Text(entry.key),
                  subtitle: SelectableText('${entry.value ?? '—'}'),
                ),
            ],
          ),
        ),
      );
    } catch (error) {
      _snack(
        error is ApiException
            ? error.message
            : 'Không tải được chi tiết hồ sơ.',
      );
    }
  }

  Widget _trainingTab() {
    final requiredCount = (_progress['requiredCourses'] as num?)?.toInt() ?? 0;
    final completed = (_progress['completedCourses'] as num?)?.toInt() ?? 0;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          color: AppColors.surface,
          child: ListTile(
            leading: Icon(Icons.school_outlined, color: AppColors.primary),
            title: Text(
              'Tiến độ khóa theo chức vụ: $completed/$requiredCount đạt',
            ),
            subtitle: const Text(
              'Đào tạo được theo dõi riêng và không ảnh hưởng nhận ca.',
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
                  '${item['isMandatory'] == true ? ' · Theo dõi theo chức vụ' : ''}',
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
