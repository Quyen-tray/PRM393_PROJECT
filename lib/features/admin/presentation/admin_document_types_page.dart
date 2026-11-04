import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/repositories/employee_providers.dart';
import '../../auth/presentation/sign_out_flow.dart';
import 'widgets/admin_bottom_navigation.dart';
import 'widgets/admin_more_menu.dart';

class AdminDocumentTypesPage extends ConsumerStatefulWidget {
  const AdminDocumentTypesPage({super.key});

  @override
  ConsumerState<AdminDocumentTypesPage> createState() =>
      _AdminDocumentTypesPageState();
}

class _AdminDocumentTypesPageState
    extends ConsumerState<AdminDocumentTypesPage> {
  List<Map<String, dynamic>> _types = [];
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
      final values = await ref
          .read(employeeRepositoryProvider)
          .getAdminDocumentTypes();
      if (mounted) setState(() => _types = values);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Không tải được danh mục loại hồ sơ.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit({Map<String, dynamic>? item}) async {
    final code = TextEditingController(text: '${item?['documentCode'] ?? ''}');
    final name = TextEditingController(text: '${item?['documentName'] ?? ''}');
    final form = GlobalKey<FormState>();
    var active = item?['isActive'] != false;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(item == null ? 'Thêm loại hồ sơ' : 'Sửa loại hồ sơ'),
          content: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: code,
                  decoration: const InputDecoration(labelText: 'Mã loại hồ sơ'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Nhập mã loại hồ sơ.'
                      : null,
                ),
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(
                    labelText: 'Tên loại hồ sơ',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Nhập tên loại hồ sơ.'
                      : null,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Đang sử dụng'),
                  value: active,
                  onChanged: (value) => setDialogState(() => active = value),
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
              onPressed: () {
                if (form.currentState!.validate()) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !mounted) return;
    try {
      final repo = ref.read(employeeRepositoryProvider);
      final id = (item?['documentTypeId'] ?? item?['typeId']) as num?;
      if (id == null) {
        await repo.createAdminDocumentType(
          documentCode: code.text.trim(),
          documentName: name.text.trim(),
          isActive: active,
        );
      } else {
        await repo.updateAdminDocumentType(
          typeId: id.toInt(),
          documentCode: code.text.trim(),
          documentName: name.text.trim(),
          isActive: active,
        );
      }
      await _load();
      if (mounted) _message('Đã lưu loại hồ sơ.');
    } catch (error) {
      _message(
        error is ApiException ? error.message : 'Không lưu được loại hồ sơ.',
      );
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('Loại hồ sơ'),
      leading: IconButton(
        onPressed: () => context.go(RouteNames.adminPositions),
        icon: const Icon(Icons.arrow_back),
      ),
      actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!),
                const SizedBox(height: 12),
                FilledButton(onPressed: _load, child: const Text('Thử lại')),
              ],
            ),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Danh mục này xuất hiện khi nhân viên nộp hồ sơ. Loại không còn dùng có thể chuyển sang ngừng hoạt động.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                if (_types.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('Chưa có loại hồ sơ.')),
                  ),
                for (final type in _types)
                  Card(
                    color: AppColors.surface,
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.description_outlined),
                      ),
                      title: Text(
                        '${type['documentName'] ?? 'Chưa đặt tên'}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${type['documentCode'] ?? '—'} · ${type['isActive'] == false ? 'Đã ngừng' : 'Đang dùng'}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _edit(item: type),
                      ),
                    ),
                  ),
              ],
            ),
          ),
    floatingActionButton: FloatingActionButton(
      onPressed: () => _edit(),
      child: const Icon(Icons.add),
    ),
    bottomNavigationBar: AdminBottomNavigation(
      selectedIndex: 4,
      onDestinationSelected: (index) {
        if (index == 0) context.go(RouteNames.adminHome);
        if (index == 1) context.go(RouteNames.adminAccounts);
        if (index == 2) context.go(RouteNames.adminPositions);
        if (index == 3) context.go(RouteNames.adminTraining);
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
