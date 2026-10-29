import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../data/mock/demo_data.dart';
import 'widgets/admin_bottom_navigation.dart';
import 'widgets/admin_more_menu.dart';

enum _AccountFilter { all, admin, manager, employee }

class AdminAccountManagementPage extends StatefulWidget {
  const AdminAccountManagementPage({super.key});

  @override
  State<AdminAccountManagementPage> createState() =>
      _AdminAccountManagementPageState();
}

class _AdminAccountManagementPageState
    extends State<AdminAccountManagementPage> {
  static const _filters = <(_AccountFilter, String)>[
    (_AccountFilter.all, 'Tất cả'),
    (_AccountFilter.admin, 'Admin'),
    (_AccountFilter.manager, 'Manager'),
    (_AccountFilter.employee, 'Employee'),
  ];

  late List<DemoAdminAccount> _accounts;
  _AccountFilter _selectedFilter = _AccountFilter.all;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _accounts = List.of(DemoData.adminAccounts);
  }

  int _countFor(_AccountFilter filter) {
    if (filter == _AccountFilter.all) return _accounts.length;

    return _accounts.where((account) {
      return switch (filter) {
        _AccountFilter.all => true,
        _AccountFilter.admin => account.role == DemoAdminAccountRole.admin,
        _AccountFilter.manager => account.role == DemoAdminAccountRole.manager,
        _AccountFilter.employee =>
          account.role == DemoAdminAccountRole.employee,
      };
    }).length;
  }

  List<DemoAdminAccount> get _visibleAccounts {
    final query = _searchQuery.trim().toLowerCase();

    return _accounts.where((account) {
      final matchesRole = switch (_selectedFilter) {
        _AccountFilter.all => true,
        _AccountFilter.admin => account.role == DemoAdminAccountRole.admin,
        _AccountFilter.manager => account.role == DemoAdminAccountRole.manager,
        _AccountFilter.employee =>
          account.role == DemoAdminAccountRole.employee,
      };
      final matchesSearch = query.isEmpty ||
          account.name.toLowerCase().contains(query) ||
          account.accountId.toLowerCase().contains(query);

      return matchesRole && matchesSearch;
    }).toList();
  }

  void _setAccountEnabled(DemoAdminAccount account, bool enabled) {
    final index = _accounts.indexWhere(
      (item) => item.accountId == account.accountId,
    );

    if (index == -1) return;

    setState(() {
      _accounts[index] = account.copyWith(isEnabled: enabled);
    });
  }

  Future<void> _showAddAccountDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    var selectedRole = DemoAdminAccountRole.employee;

    final draft = await showDialog<_NewAccountDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Thêm tài khoản'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Họ và tên',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập họ tên.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<DemoAdminAccountRole>(
                  initialValue: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Vai trò',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final role in DemoAdminAccountRole.values)
                      DropdownMenuItem(
                        value: role,
                        child: Text(_roleLabel(role)),
                      ),
                  ],
                  onChanged: (role) {
                    if (role != null) {
                      setDialogState(() => selectedRole = role);
                    }
                  },
                ),
              ],
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

                Navigator.pop(
                  dialogContext,
                  _NewAccountDraft(
                    name: nameController.text.trim(),
                    role: selectedRole,
                  ),
                );
              },
              child: const Text('Thêm'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();

    if (!mounted || draft == null) return;

    final number = (_accounts.length + 1).toString().padLeft(3, '0');
    final prefix = switch (draft.role) {
      DemoAdminAccountRole.admin => 'AD',
      DemoAdminAccountRole.manager => 'QL',
      DemoAdminAccountRole.employee => 'NV',
    };

    setState(() {
      _accounts.insert(
        0,
        DemoAdminAccount(
          name: draft.name,
          accountId: '$prefix$number',
          role: draft.role,
          initials: _initials(draft.name),
          isEnabled: true,
          avatarColorValue: 0xFFEAD9CC,
        ),
      );
    });
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first[0].toUpperCase();

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final visibleAccounts = _visibleAccounts;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Quản lý tài khoản'),
        leading: IconButton(
          tooltip: 'Quay lại Dashboard Admin',
          onPressed: () => context.go(RouteNames.adminHome),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Tìm theo tên hoặc mã tài khoản...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFEDE8E3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFEDE8E3)),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final (filter, label) = _filters[index];
                final selected = _selectedFilter == filter;

                return ChoiceChip(
                  label: Text('$label (${_countFor(filter)})'),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedFilter = filter),
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(
                    color: selected
                        ? AppColors.primary
                        : const Color(0xFFEDE8E3),
                  ),
                  showCheckmark: false,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: visibleAccounts.isEmpty
                ? const Center(
                    child: Text(
                      'Không tìm thấy tài khoản phù hợp.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: visibleAccounts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 9),
                    itemBuilder: (context, index) {
                      final account = visibleAccounts[index];

                      return _AccountCard(
                        account: account,
                        onEnabledChanged: (enabled) {
                          _setAccountEnabled(account, enabled);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddAccountDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: AdminBottomNavigation(
        selectedIndex: 1,
        onDestinationSelected: (index) {
          if (index == 0) {
            context.go(RouteNames.adminHome);
            return;
          }
          if (index == 1) return;
          if (index == 2) {
            context.go(RouteNames.adminPositions);
            return;
          }
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

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.onEnabledChanged,
  });

  final DemoAdminAccount account;
  final ValueChanged<bool> onEnabledChanged;

  @override
  Widget build(BuildContext context) {
    final roleColor = switch (account.role) {
      DemoAdminAccountRole.admin => const Color(0xFF8E63B0),
      DemoAdminAccountRole.manager => const Color(0xFF3998D8),
      DemoAdminAccountRole.employee => const Color(0xFF37966F),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDE8E3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Color(account.avatarColorValue),
            child: Text(
              account.initials,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      account.accountId,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _roleLabel(account.role),
                        style: TextStyle(
                          color: roleColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: account.isEnabled,
            onChanged: onEnabledChanged,
          ),
        ],
      ),
    );
  }
}

String _roleLabel(DemoAdminAccountRole role) {
  return switch (role) {
    DemoAdminAccountRole.admin => 'Admin',
    DemoAdminAccountRole.manager => 'Manager',
    DemoAdminAccountRole.employee => 'Employee',
  };
}

class _NewAccountDraft {
  const _NewAccountDraft({
    required this.name,
    required this.role,
  });

  final String name;
  final DemoAdminAccountRole role;
}
