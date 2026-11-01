import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/repositories/employee_providers.dart';
import 'admin_position_requirements_page.dart';
import 'widgets/admin_bottom_navigation.dart';
import 'widgets/admin_more_menu.dart';

class AdminPositionManagementPage extends ConsumerStatefulWidget {
  const AdminPositionManagementPage({super.key});
  @override
  ConsumerState<AdminPositionManagementPage> createState() => _AdminPositionManagementPageState();
}

class _AdminPositionManagementPageState extends ConsumerState<AdminPositionManagementPage> {
  List<Map<String, dynamic>> _positions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rows = await ref.read(employeeRepositoryProvider).getAdminJobPositions(includeInactive: true);
      if (!mounted) return;
      setState(() { _positions = rows; _loading = false; });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Không thể tải danh sách chức vụ.'; _loading = false; });
    }
  }

  Future<void> _showPositionForm({Map<String, dynamic>? position}) async {
    final formKey = GlobalKey<FormState>();
    final code = TextEditingController(text: (position?['positionCode'] ?? '').toString());
    final name = TextEditingController(text: (position?['positionName'] ?? '').toString());
    final description = TextEditingController(text: (position?['description'] ?? '').toString());
    var active = position?['isActive'] != false;
    final draft = await showDialog<Map<String, dynamic>>(context: context, builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(position == null ? 'Thêm chức vụ' : 'Cập nhật chức vụ'),
        content: Form(key: formKey, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: code, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Mã chức vụ'),
            validator: (v) => v == null || v.trim().isEmpty ? 'Nhập mã chức vụ.' : null),
          const SizedBox(height: 10),
          TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Tên chức vụ'),
            validator: (v) => v == null || v.trim().isEmpty ? 'Nhập tên chức vụ.' : null),
          const SizedBox(height: 10),
          TextFormField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Mô tả')),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Đang hoạt động'), value: active,
            onChanged: (v) => setDialogState(() => active = v)),
        ]))),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Hủy')),
          FilledButton(onPressed: () { if (!formKey.currentState!.validate()) return; Navigator.pop(dialogContext, {
            'positionCode': code.text.trim().toUpperCase(), 'positionName': name.text.trim(),
            'description': description.text.trim().isEmpty ? null : description.text.trim(), 'isActive': active,
          }); }, child: const Text('Lưu'))],
      ),
    ));
    code.dispose(); name.dispose(); description.dispose();
    if (!mounted || draft == null) return;
    try {
      final repo = ref.read(employeeRepositoryProvider);
      final id = position?['positionId'];
      if (id is num) {
        await repo.updateAdminJobPosition(positionId: id.toInt(), positionCode: draft['positionCode'],
          positionName: draft['positionName'], description: draft['description'], isActive: draft['isActive']);
      } else {
        await repo.createAdminJobPosition(positionCode: draft['positionCode'], positionName: draft['positionName'],
          description: draft['description'], isActive: draft['isActive']);
      }
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu chức vụ.')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không thể lưu chức vụ.')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Quản lý chức vụ'), leading: IconButton(
      onPressed: () => context.go(RouteNames.adminHome), icon: const Icon(Icons.arrow_back)),
      actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
    body: _loading ? const Center(child: CircularProgressIndicator())
      : _error != null ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton(onPressed: _load, child: const Text('Thử lại')),
        ])))
      : _positions.isEmpty ? const Center(child: Text('Chưa có chức vụ nào.'))
      : RefreshIndicator(onRefresh: _load, child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20), itemCount: _positions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) { final p = _positions[i]; final active = p['isActive'] != false;
            return Card(color: AppColors.surface, child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.badge_outlined)),
              title: Text((p['positionName'] ?? 'Chưa có tên').toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${p['positionCode'] ?? ''} · ${active ? 'Đang hoạt động' : 'Ngừng hoạt động'}\n${p['description'] ?? ''}'),
              isThreeLine: (p['description'] ?? '').toString().isNotEmpty,
              trailing: IconButton(tooltip: 'Sửa thông tin chức vụ', icon: const Icon(Icons.edit_outlined), onPressed: () => _showPositionForm(position: p)),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminPositionRequirementsPage(position: p))),
            ));
          },
        )),
    floatingActionButton: FloatingActionButton(onPressed: () => _showPositionForm(), backgroundColor: AppColors.primary,
      foregroundColor: Colors.white, child: const Icon(Icons.add)),
    bottomNavigationBar: AdminBottomNavigation(selectedIndex: 2, onDestinationSelected: (index) {
      if (index == 0) context.go(RouteNames.adminHome);
      if (index == 1) context.go(RouteNames.adminAccounts);
      if (index == 2) return;
      if (index == 3) context.go(RouteNames.adminTraining);
      if (index == 4) showAdminMoreMenu(context);
    }),
  );
}
