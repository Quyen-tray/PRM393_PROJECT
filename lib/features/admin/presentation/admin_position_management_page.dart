import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../data/mock/demo_data.dart';
import 'widgets/admin_bottom_navigation.dart';
import 'widgets/admin_more_menu.dart';

class AdminPositionManagementPage extends StatefulWidget {
  const AdminPositionManagementPage({super.key});

  @override
  State<AdminPositionManagementPage> createState() =>
      _AdminPositionManagementPageState();
}

class _AdminPositionManagementPageState
    extends State<AdminPositionManagementPage> {
  late List<DemoAdminPosition> _positions;

  @override
  void initState() {
    super.initState();
    _positions = List.of(DemoData.adminPositions);
  }

  Future<void> _showPositionForm({DemoAdminPosition? position}) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: position?.name ?? '');

    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(position == null ? 'Thêm chức vụ' : 'Sửa chức vụ'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Tên chức vụ',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Vui lòng nhập tên chức vụ.';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(dialogContext, nameController.text.trim());
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    nameController.dispose();

    if (!mounted || name == null) return;

    setState(() {
      if (position == null) {
        _positions.add(
          DemoAdminPosition(
            name: name,
            employeeCount: 0,
          ),
        );
        return;
      }

      final index = _positions.indexOf(position);
      if (index != -1) {
        _positions[index] = position.copyWith(name: name);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Quản lý chức vụ'),
        leading: IconButton(
          tooltip: 'Quay lại Dashboard Admin',
          onPressed: () => context.go(RouteNames.adminHome),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Danh sách chức vụ',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${_positions.length} chức vụ',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              itemCount: _positions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 9),
              itemBuilder: (context, index) {
                final position = _positions[index];

                return _PositionCard(
                  position: position,
                  onTap: () => _showPositionForm(position: position),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showPositionForm,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: AdminBottomNavigation(
        selectedIndex: 2,
        onDestinationSelected: (index) {
          if (index == 0) {
            context.go(RouteNames.adminHome);
            return;
          }
          if (index == 1) {
            context.go(RouteNames.adminAccounts);
            return;
          }
          if (index == 2) return;
          if (index == 3) {
            context.go(RouteNames.adminTraining);
            return;
          }

          showAdminMoreMenu(context);
        },
      ),
    );
  }
}

class _PositionCard extends StatelessWidget {
  const _PositionCard({
    required this.position,
    required this.onTap,
  });

  final DemoAdminPosition position;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDE8E3)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 6,
        ),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFF5E8DF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.badge_outlined,
            color: AppColors.primary,
          ),
        ),
        title: Text(
          position.name,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '${position.employeeCount} nhân viên',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
