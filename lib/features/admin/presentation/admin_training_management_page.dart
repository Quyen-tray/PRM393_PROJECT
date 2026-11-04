import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/presentation/sign_out_flow.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/repositories/employee_providers.dart';
import 'widgets/admin_bottom_navigation.dart';
import 'widgets/admin_more_menu.dart';

class AdminTrainingManagementPage extends ConsumerStatefulWidget {
  const AdminTrainingManagementPage({super.key});

  @override
  ConsumerState<AdminTrainingManagementPage> createState() =>
      _AdminTrainingManagementPageState();
}

class _AdminTrainingManagementPageState
    extends ConsumerState<AdminTrainingManagementPage> {
  static const _filterLabels = <String, String>{
    'ALL': 'Tất cả',
    'ACTIVE': 'Đang mở',
    'INACTIVE': 'Ngừng',
    'TEST': 'Có bài kiểm tra',
  };

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _query = '';
  String _filter = 'ALL';
  List<Map<String, dynamic>> _courses = [];

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
      final items = await ref
          .read(employeeRepositoryProvider)
          .getTrainingCourses();
      if (!mounted) return;
      setState(() {
        _courses = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  bool _matchesFilter(Map<String, dynamic> course) => switch (_filter) {
    'ACTIVE' => course['isActive'] != false,
    'INACTIVE' => course['isActive'] == false,
    'TEST' => course['isMandatoryTest'] == true,
    _ => true,
  };

  List<Map<String, dynamic>> get _visible {
    final q = _query.trim().toLowerCase();
    return _courses.where((course) {
      final matchesQuery =
          q.isEmpty ||
          (course['courseName'] ?? '').toString().toLowerCase().contains(q) ||
          (course['courseCode'] ?? '').toString().toLowerCase().contains(q);
      return matchesQuery && _matchesFilter(course);
    }).toList();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _editCourse([Map<String, dynamic>? course]) async {
    final formKey = GlobalKey<FormState>();
    final code = TextEditingController(text: '${course?['courseCode'] ?? ''}');
    final name = TextEditingController(text: '${course?['courseName'] ?? ''}');
    final description = TextEditingController(
      text: '${course?['description'] ?? ''}',
    );
    final score = TextEditingController(text: '${course?['passScore'] ?? 70}');
    final months = TextEditingController(
      text: '${course?['validityMonths'] ?? 12}',
    );
    var hasTest = course?['isMandatoryTest'] != false;
    var active = course?['isActive'] != false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(course == null ? 'Tạo khóa học' : 'Cập nhật khóa học'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: code,
                      decoration: const InputDecoration(
                        labelText: 'Mã khóa học',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Nhập mã khóa học.'
                          : null,
                    ),
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'Tên khóa học',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Nhập tên khóa học.'
                          : null,
                    ),
                    TextFormField(
                      controller: description,
                      decoration: const InputDecoration(labelText: 'Mô tả'),
                      maxLines: 3,
                    ),
                    TextFormField(
                      controller: score,
                      decoration: const InputDecoration(
                        labelText: 'Điểm đạt (0–100)',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final n = num.tryParse(v ?? '');
                        return n == null || n < 0 || n > 100
                            ? 'Điểm phải từ 0 đến 100.'
                            : null;
                      },
                    ),
                    TextFormField(
                      controller: months,
                      decoration: const InputDecoration(
                        labelText: 'Hiệu lực (tháng)',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        return n == null || n < 1 || n > 120
                            ? 'Nhập từ 1 đến 120 tháng.'
                            : null;
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Có bài kiểm tra'),
                      value: hasTest,
                      onChanged: (v) => setDialogState(() => hasTest = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Đang mở đăng ký'),
                      value: active,
                      onChanged: (v) => setDialogState(() => active = v),
                    ),
                  ],
                ),
              ),
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
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );

    if (saved == true && mounted) {
      final payload = <String, dynamic>{
        'courseCode': code.text.trim(),
        'courseName': name.text.trim(),
        'description': description.text.trim().isEmpty
            ? null
            : description.text.trim(),
        'passScore': double.parse(score.text),
        'validityMonths': int.parse(months.text),
        'isMandatoryTest': hasTest,
        'isActive': active,
      };
      setState(() => _saving = true);
      try {
        final repo = ref.read(employeeRepositoryProvider);
        final id = (course?['courseId'] as num?)?.toInt();
        if (id == null) {
          await repo.createTrainingCourse(payload);
        } else {
          await repo.updateTrainingCourse(id, payload);
        }
        _message('Đã lưu khóa học.');
        await _load();
      } catch (e) {
        _message(e.toString());
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }

    code.dispose();
    name.dispose();
    description.dispose();
    score.dispose();
    months.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Quản lý đào tạo'),
        leading: IconButton(
          tooltip: 'Quay lại trang quản trị',
          onPressed: () => context.go(RouteNames.adminHome),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            tooltip: 'Duyệt hoàn thành khóa học',
            onPressed: () => context.push(RouteNames.adminTrainingCompletions),
            icon: const Icon(Icons.fact_check_outlined),
          ),
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : () => _editCourse(),
        icon: const Icon(Icons.add),
        label: const Text('Thêm khóa học'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _load,
                            child: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: TextField(
                          onChanged: (v) => setState(() => _query = v),
                          decoration: InputDecoration(
                            hintText: 'Tìm theo mã hoặc tên khóa học...',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            for (final entry in _filterLabels.entries)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(entry.value),
                                  selected: _filter == entry.key,
                                  onSelected: (_) =>
                                      setState(() => _filter = entry.key),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(child: _listOrEmpty()),
                    ],
                  ),
          ),
        ),
      ),
      bottomNavigationBar: AdminBottomNavigation(
        selectedIndex: 3,
        onDestinationSelected: (index) {
          if (index == 0) context.go(RouteNames.adminHome);
          if (index == 1) context.go(RouteNames.adminAccounts);
          if (index == 2) context.go(RouteNames.adminPositions);
          if (index == 4) {
            showAdminMoreMenu(
              context,
              onSignOut: () => signOutAndReturnToLogin(context, ref),
            );
          }
        },
      ),
    );
  }

  Widget _listOrEmpty() {
    final visible = _visible;
    if (_courses.isEmpty) {
      return const Center(child: Text('Chưa có khóa học nào.'));
    }
    if (visible.isEmpty) {
      return const Center(child: Text('Không có khóa học phù hợp.'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
        itemCount: visible.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _courseTile(visible[index]),
      ),
    );
  }

  Widget _courseTile(Map<String, dynamic> course) {
    final active = course['isActive'] != false;
    final hasTest = course['isMandatoryTest'] == true;
    return Card(
      color: AppColors.surface,
      child: ListTile(
        isThreeLine: true,
        leading: CircleAvatar(
          child: Icon(
            active ? Icons.school_outlined : Icons.pause_circle_outline,
          ),
        ),
        title: Text(
          (course['courseName'] ?? 'Khóa học').toString(),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${course['courseCode'] ?? ''} · Điểm đạt ${formatScore(course['passScore'])} · '
          '${course['validityMonths'] ?? '—'} tháng hiệu lực\n'
          '${hasTest ? 'Có bài kiểm tra' : 'Không có bài kiểm tra'} · ${active ? 'Đang mở' : 'Ngừng'}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasTest)
              IconButton(
                tooltip: 'Quản lý câu hỏi trắc nghiệm',
                onPressed: _saving
                    ? null
                    : () {
                        final id = (course['courseId'] as num?)?.toInt();
                        if (id == null) return;
                        context.push(
                          RouteNames.adminTrainingQuestionsFor(id),
                          extra: (course['courseName'] ?? 'Khóa học')
                              .toString(),
                        );
                      },
                icon: const Icon(Icons.quiz_outlined),
              ),
            IconButton(
              tooltip: 'Sửa khóa học',
              onPressed: _saving ? null : () => _editCourse(course),
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
      ),
    );
  }
}
