import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../data/mock/admin_demo_data.dart';
import '../../../shared/widgets/app_widgets.dart';
import 'widgets/admin_scaffold.dart';

class AdminAccountListPage extends StatefulWidget {
  const AdminAccountListPage({super.key});

  @override
  State<AdminAccountListPage> createState() => _AdminAccountListPageState();
}

class _AdminAccountListPageState extends State<AdminAccountListPage> {
  static const _filters = ['Tất cả', 'Admin', 'Manager', 'Employee'];

  final _accounts = AdminDemoData.accounts;
  String _filter = 'Tất cả';
  String _query = '';

  List<AdminAccount> get _visible {
    final query = _query.trim().toLowerCase();
    return [
      for (final a in _accounts)
        if ((_filter == 'Tất cả' || a.role.label == _filter) &&
            (query.isEmpty ||
                a.name.toLowerCase().contains(query) ||
                a.code.toLowerCase().contains(query)))
          a,
    ];
  }

  Future<void> _addAccount() async {
    var name = '';
    var role = AdminRole.employee;

    final created = await showDialog<AdminAccount>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialog) => AlertDialog(
          title: const Text('Thêm tài khoản'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Họ và tên'),
                onChanged: (v) => name = v,
              ),
              const SizedBox(height: 16),
              DropdownButton<AdminRole>(
                value: role,
                isExpanded: true,
                items: [
                  for (final r in AdminRole.values)
                    DropdownMenuItem(value: r, child: Text(r.label)),
                ],
                onChanged: (r) => setDialog(() => role = r!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                if (name.trim().isEmpty) return;
                Navigator.pop(
                  dialogContext,
                  AdminAccount(
                    name: name.trim(),
                    code: 'NV${(_accounts.length + 10).toString().padLeft(4, '0')}',
                    role: role,
                    position: 'Nhân viên phục vụ',
                  ),
                );
              },
              child: const Text('Tạo tài khoản'),
            ),
          ],
        ),
      ),
    );

    if (created != null && mounted) {
      setState(() => _accounts.insert(0, created));
      showAppSnack(context, 'Đã tạo tài khoản ${created.name}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _visible;

    return AdminScaffold(
      title: 'Quản lý tài khoản',
      selectedIndex: 1,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addAccount,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Thêm tài khoản'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'Tìm theo tên hoặc mã nhân viên',
              prefixIcon: Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final f in _filters)
                ChoiceChip(
                  label: Text(f),
                  selected: _filter == f,
                  onSelected: (_) => setState(() => _filter = f),
                ),
            ],
          ),
          const SizedBox(height: 12),
          AppPanel(
            child: list.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Không tìm thấy tài khoản phù hợp.'),
                  )
                : Column(
                    children: divided([
                      for (final a in list)
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFEAD9CC),
                            child: Text(
                              a.initials,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          title: Text(a.name),
                          subtitle: Text('${a.code} · ${a.position}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              StatusTag(a.role.label),
                              const SizedBox(width: 4),
                              Switch(
                                value: a.active,
                                onChanged: (v) => setState(() => a.active = v),
                              ),
                            ],
                          ),
                        ),
                    ]),
                  ),
          ),
        ],
      ),
    );
  }
}
