import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/repositories/employee_providers.dart';

/// Danh mục kỹ năng (Admin). Máy chủ chỉ có thêm và xem: không có endpoint sửa hay ngưng kỹ năng.
class AdminSkillManagementPage extends ConsumerStatefulWidget {
  const AdminSkillManagementPage({super.key});

  @override
  ConsumerState<AdminSkillManagementPage> createState() => _AdminSkillManagementPageState();
}

class _AdminSkillManagementPageState extends ConsumerState<AdminSkillManagementPage> {
  List<Map<String, dynamic>> _skills = [];
  bool _loading = true;
  String? _error;

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
      final skills = await ref.read(employeeRepositoryProvider).getSkills();
      if (!mounted) return;
      setState(() {
        _skills = skills;
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
        _error = 'Không tải được danh mục kỹ năng.';
        _loading = false;
      });
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RouteNames.adminHome);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Thêm kỹ năng mới. Mã bị đổi thành chữ hoa và không đổi được sau khi tạo.
  Future<void> _addSkill() async {
    final form = GlobalKey<FormState>();
    final code = TextEditingController();
    final name = TextEditingController();
    final description = TextEditingController();

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Thêm kỹ năng'),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: code,
                  maxLength: 40,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Mã kỹ năng *',
                    hintText: 'Ví dụ: LATTE_ART',
                    helperText: 'Không đổi được sau khi tạo.',
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Không được để trống.'
                      : null,
                ),
                TextFormField(
                  controller: name,
                  maxLength: 150,
                  decoration: const InputDecoration(labelText: 'Tên kỹ năng *'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Không được để trống.'
                      : null,
                ),
                TextFormField(
                  controller: description,
                  maxLength: 500,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Mô tả (không bắt buộc)'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Hủy')),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(dialogContext, true);
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );

    final codeText = code.text.trim();
    final nameText = name.text.trim();
    final descriptionText = description.text.trim();
    code.dispose();
    name.dispose();
    description.dispose();
    if (accepted != true || !mounted) return;

    try {
      await ref.read(employeeRepositoryProvider).createSkill(
            skillCode: codeText,
            skillName: nameText,
            description: descriptionText.isEmpty ? null : descriptionText,
          );
      _snack('Đã thêm kỹ năng.');
      await _load();
    } on ApiException catch (e) {
      // Mã trùng hoặc dữ liệu sai: máy chủ trả thông báo cụ thể, hiển thị nguyên văn.
      _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Danh mục kỹ năng'),
        leading: IconButton(
          tooltip: 'Quay lại',
          onPressed: _back,
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
      body: _body(),
      floatingActionButton: FloatingActionButton(
        onPressed: _loading ? null : _addSkill,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        tooltip: 'Thêm kỹ năng',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }
    if (_skills.isEmpty) {
      return const Center(child: Text('Chưa có kỹ năng nào trong danh mục.'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        itemCount: _skills.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final skill = _skills[index];
          final description = (skill['description'] ?? '').toString().trim();
          return Card(
            color: AppColors.surface,
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.psychology_outlined, size: 20)),
              title: Text(
                (skill['skillName'] ?? '').toString(),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                description.isEmpty
                    ? (skill['skillCode'] ?? '').toString()
                    : '${skill['skillCode'] ?? ''}\n$description',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              isThreeLine: description.isNotEmpty,
            ),
          );
        },
      ),
    );
  }
}
