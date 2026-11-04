import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/presentation/sign_out_flow.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../data/repositories/employee_providers.dart';
import 'widgets/admin_bottom_navigation.dart';
import 'widgets/admin_more_menu.dart';

class AdminTrainingQuestionsPage extends ConsumerStatefulWidget {
  const AdminTrainingQuestionsPage({
    required this.courseId,
    required this.courseName,
    super.key,
  });

  final int courseId;
  final String courseName;

  @override
  ConsumerState<AdminTrainingQuestionsPage> createState() =>
      _AdminTrainingQuestionsPageState();
}

class _AdminTrainingQuestionsPageState
    extends ConsumerState<AdminTrainingQuestionsPage> {
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  String? _error;
  List<Map<String, dynamic>> _questions = [];

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
      final questions = await ref
          .read(employeeRepositoryProvider)
          .getAdminTrainingQuestions(widget.courseId);
      if (!mounted) return;
      setState(() {
        _questions = questions;
        _dirty = false;
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

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _editQuestion([Map<String, dynamic>? question]) async {
    final formKey = GlobalKey<FormState>();
    final controllers = <String, TextEditingController>{
      'questionText': TextEditingController(
        text: '${question?['questionText'] ?? ''}',
      ),
      'optionA': TextEditingController(text: '${question?['optionA'] ?? ''}'),
      'optionB': TextEditingController(text: '${question?['optionB'] ?? ''}'),
      'optionC': TextEditingController(text: '${question?['optionC'] ?? ''}'),
      'optionD': TextEditingController(text: '${question?['optionD'] ?? ''}'),
    };
    var correctOption = (question?['correctOption'] ?? 'A').toString();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(question == null ? 'Thêm câu hỏi' : 'Sửa câu hỏi'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _field(
                      controllers['questionText']!,
                      'Nội dung câu hỏi',
                      maxLines: 3,
                      maxLength: 1000,
                    ),
                    for (final key in const ['A', 'B', 'C', 'D'])
                      _field(
                        controllers['option$key']!,
                        'Đáp án $key',
                        maxLength: 300,
                      ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: correctOption,
                      decoration: const InputDecoration(
                        labelText: 'Đáp án đúng',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'A', child: Text('A')),
                        DropdownMenuItem(value: 'B', child: Text('B')),
                        DropdownMenuItem(value: 'C', child: Text('C')),
                        DropdownMenuItem(value: 'D', child: Text('D')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => correctOption = value);
                        }
                      },
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
              child: const Text('Lưu câu hỏi'),
            ),
          ],
        ),
      ),
    );

    if (saved == true && mounted) {
      final updated = <String, dynamic>{
        for (final entry in controllers.entries)
          entry.key: entry.value.text.trim(),
        'correctOption': correctOption,
      };
      setState(() {
        final index = question == null ? -1 : _questions.indexOf(question);
        if (index < 0) {
          _questions = [..._questions, updated];
        } else {
          _questions = [..._questions]..[index] = updated;
        }
        _dirty = true;
      });
    }
    for (final controller in controllers.values) {
      controller.dispose();
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    required int maxLength,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      decoration: InputDecoration(labelText: label),
      validator: (value) => value == null || value.trim().isEmpty
          ? 'Trường này không được để trống.'
          : null,
    ),
  );

  Future<void> _removeQuestion(Map<String, dynamic> question) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa câu hỏi?'),
        content: Text((question['questionText'] ?? '').toString()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Giữ lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() {
        _questions = [..._questions]..remove(question);
        _dirty = true;
      });
    }
  }

  Future<void> _leaveTo(String location) async {
    if (_dirty) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Bỏ thay đổi chưa lưu?'),
          content: const Text('Các chỉnh sửa câu hỏi chưa lưu sẽ bị mất.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Tiếp tục chỉnh sửa'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Bỏ thay đổi'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    if (mounted) context.go(location);
  }

  Future<void> _backToCourses() => _leaveTo(RouteNames.adminTraining);

  Future<void> _save() async {
    if (_questions.isEmpty) {
      _message('Bài kiểm tra cần ít nhất một câu hỏi.');
      return;
    }
    setState(() => _saving = true);
    try {
      final payload = <Map<String, dynamic>>[
        for (var i = 0; i < _questions.length; i++)
          <String, dynamic>{
            'questionText': _questions[i]['questionText'],
            'optionA': _questions[i]['optionA'],
            'optionB': _questions[i]['optionB'],
            'optionC': _questions[i]['optionC'],
            'optionD': _questions[i]['optionD'],
            'correctOption': _questions[i]['correctOption'],
            'sortOrder': i + 1,
          },
      ];
      final saved = await ref
          .read(employeeRepositoryProvider)
          .replaceAdminTrainingQuestions(widget.courseId, payload);
      if (!mounted) return;
      setState(() {
        _questions = saved;
        _dirty = false;
      });
      _message('Đã lưu ${saved.length} câu hỏi.');
    } catch (e) {
      _message(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _dirty) _backToCourses();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Câu hỏi trắc nghiệm'),
          leading: IconButton(
            tooltip: 'Quay lại danh sách khóa học',
            onPressed: _backToCourses,
            icon: const Icon(Icons.arrow_back),
          ),
          actions: [
            IconButton(
              tooltip: 'Lưu ngân hàng câu hỏi',
              onPressed: _saving || _loading ? null : _save,
              icon: _saving
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _loading || _saving ? null : () => _editQuestion(),
          icon: const Icon(Icons.add),
          label: const Text('Thêm câu hỏi'),
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
                            OutlinedButton.icon(
                              onPressed: _load,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Card(
                            color: AppColors.surface,
                            child: ListTile(
                              leading: const Icon(Icons.school_outlined),
                              title: Text(widget.courseName),
                              subtitle: Text(
                                '${_questions.length} câu hỏi · chỉnh sửa xong nhấn Lưu để áp dụng đáp án chấm tự động',
                              ),
                            ),
                          ),
                        ),
                        Expanded(child: _questionList()),
                      ],
                    ),
            ),
          ),
        ),
        bottomNavigationBar: AdminBottomNavigation(
          selectedIndex: 3,
          onDestinationSelected: (index) {
            if (index == 0) _leaveTo(RouteNames.adminHome);
            if (index == 1) _leaveTo(RouteNames.adminAccounts);
            if (index == 2) _leaveTo(RouteNames.adminPositions);
            if (index == 3) _backToCourses();
            if (index == 4) {
              showAdminMoreMenu(
                context,
                onSignOut: () => signOutAndReturnToLogin(context, ref),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _questionList() {
    if (_questions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Chưa có câu hỏi. Thêm ít nhất một câu rồi lưu bài kiểm tra.',
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
      itemCount: _questions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final question = _questions[index];
        return Card(
          color: AppColors.surface,
          child: ListTile(
            isThreeLine: true,
            leading: CircleAvatar(child: Text('${index + 1}')),
            title: Text(
              (question['questionText'] ?? '').toString(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              'A. ${question['optionA'] ?? ''}  ·  B. ${question['optionB'] ?? ''}\n'
              'C. ${question['optionC'] ?? ''}  ·  D. ${question['optionD'] ?? ''}\n'
              'Đáp án đúng: ${question['correctOption'] ?? '—'}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: PopupMenuButton<String>(
              tooltip: 'Tùy chọn câu hỏi',
              onSelected: _saving
                  ? null
                  : (value) {
                      if (value == 'edit') _editQuestion(question);
                      if (value == 'remove') _removeQuestion(question);
                    },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Sửa')),
                PopupMenuItem(value: 'remove', child: Text('Xóa')),
              ],
            ),
          ),
        );
      },
    );
  }
}
