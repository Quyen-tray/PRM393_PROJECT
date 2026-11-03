import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/presentation/sign_out_flow.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/repositories/employee_providers.dart';
import 'widgets/admin_bottom_navigation.dart';
import 'widgets/admin_more_menu.dart';

class AdminAccountManagementPage extends ConsumerStatefulWidget {
  const AdminAccountManagementPage({super.key});
  @override
  ConsumerState<AdminAccountManagementPage> createState() =>
      _AdminAccountManagementPageState();
}

class _AdminAccountManagementPageState
    extends ConsumerState<AdminAccountManagementPage> {
  static const _roles = <String, String>{
    'SYSTEM_ADMIN': 'System Admin',
    'STORE_MANAGER': 'Quản lý cửa hàng',
    'OPERATIONS_DIRECTOR': 'Giám đốc vận hành',
    'EMPLOYEE': 'Nhân viên',
  };
  static const _roleFilterLabels = <String, String>{
    'ALL': 'Tất cả',
    'ADMIN': 'Admin',
    'MANAGER': 'Manager',
    'EMPLOYEE': 'Employee',
  };
  List<Map<String, dynamic>> _accounts = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  String _roleFilter = 'ALL';

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
      final rows = await ref
          .read(employeeRepositoryProvider)
          .getAllAdminUsers();
      if (!mounted) return;
      setState(() {
        _accounts = rows;
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
        _error = 'Không thể tải danh sách tài khoản.';
        _loading = false;
      });
    }
  }

  bool _matchesRoleFilter(List<String> roles) => switch (_roleFilter) {
    'ADMIN' => roles.contains('SYSTEM_ADMIN'),
    'MANAGER' =>
      roles.contains('STORE_MANAGER') || roles.contains('OPERATIONS_DIRECTOR'),
    'EMPLOYEE' => roles.contains('EMPLOYEE'),
    _ => true,
  };

  List<Map<String, dynamic>> get _visible => _accounts.where((u) {
    final q = _query.trim().toLowerCase();
    final roles =
        (u['roles'] as List?)?.whereType<String>().toList() ?? <String>[];
    final matchesQuery =
        q.isEmpty ||
        (u['displayName'] ?? '').toString().toLowerCase().contains(q) ||
        (u['email'] ?? '').toString().toLowerCase().contains(q);
    return matchesQuery && _matchesRoleFilter(roles);
  }).toList();

  Future<void> _createAccount() async {
    final form = GlobalKey<FormState>();
    final name = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    var role = 'EMPLOYEE';
    final draft = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => _CreateAccountDialogControllers(
        controllers: [name, email, phone],
        child: StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Tạo tài khoản'),
            content: Form(
              key: form,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Họ và tên'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Nhập họ tên.' : null,
                    ),
                    TextFormField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) =>
                          v == null ||
                              !RegExp(
                                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                              ).hasMatch(v.trim())
                          ? 'Email không hợp lệ.'
                          : null,
                    ),
                    TextFormField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Số điện thoại (không bắt buộc)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: role,
                      decoration: const InputDecoration(labelText: 'Vai trò'),
                      items: _roles.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => role = v);
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () {
                  if (!form.currentState!.validate()) return;
                  Navigator.pop(dialogContext, {
                    'name': name.text.trim(),
                    'email': email.text.trim(),
                    'phone': phone.text.trim(),
                    'role': role,
                  });
                },
                child: const Text('Tạo'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || draft == null) return;
    try {
      await ref
          .read(employeeRepositoryProvider)
          .createAdminUser(
            email: draft['email']!,
            displayName: draft['name']!,
            phoneNumber: draft['phone']!.isEmpty ? null : draft['phone'],
            roles: [draft['role']!],
          );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã tạo tài khoản.')));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  /// Mở form tạo hồ sơ nhân viên cho tài khoản chưa có hồ sơ (POST /api/v1/employees).
  Future<void> _createProfile(Map<String, dynamic> account) async {
    final userId = account['userId'];
    if (userId is! num) return;
    final saved = await context.push<bool>(
      RouteNames.adminAccountEmployeeCreateFor(userId.toInt()),
      extra: {'displayName': account['displayName'], 'email': account['email']},
    );
    if (saved == true && mounted) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã tạo hồ sơ nhân viên.')),
        );
      }
    }
  }

  /// Mở màn phân quyền (HR là tập quyền gán trực tiếp, GET/PUT /admin/users/{id}/permissions).
  Future<void> _openPermissions(Map<String, dynamic> account) async {
    final userId = account['userId'];
    if (userId is! num) return;
    await context.push(
      RouteNames.adminAccountPermissionsFor(userId.toInt()),
      extra: {'displayName': account['displayName'], 'email': account['email']},
    );
  }

  Future<void> _changeRole(Map<String, dynamic> account) async {
    final id = account['userId'];
    final roles =
        (account['roles'] as List?)?.whereType<String>().toList() ?? <String>[];
    if (id is! num) return;
    var selected = roles.isEmpty ? 'EMPLOYEE' : roles.first;
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Thay đổi vai trò'),
          content: DropdownButtonFormField<String>(
            initialValue: _roles.containsKey(selected) ? selected : 'EMPLOYEE',
            items: _roles.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) setDialogState(() => selected = v);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, selected),
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || value == null) return;
    try {
      await ref.read(employeeRepositoryProvider).setAdminUserRoles(id.toInt(), [
        value,
      ]);
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _toggleStatus(Map<String, dynamic> account, bool enabled) async {
    final id = account['userId'];
    if (id is! num) return;
    try {
      await ref
          .read(employeeRepositoryProvider)
          .setAdminUserStatus(id.toInt(), enabled ? 'ACTIVE' : 'LOCKED');
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('Quản lý tài khoản'),
      leading: IconButton(
        onPressed: () => context.go(RouteNames.adminHome),
        icon: const Icon(Icons.arrow_back),
      ),
      actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Tìm theo tên hoặc email...',
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
              for (final entry in _roleFilterLabels.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(entry.value),
                    selected: _roleFilter == entry.key,
                    onSelected: (_) => setState(() => _roleFilter = entry.key),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
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
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                )
              : _visible.isEmpty
              ? const Center(child: Text('Không tìm thấy tài khoản.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _visible.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final u = _visible[i];
                      final roles =
                          (u['roles'] as List?)?.whereType<String>().toList() ??
                          [];
                      final roleText = roles
                          .map((r) => _roles[r] ?? r)
                          .join(', ');
                      final active = (u['status'] ?? '').toString() == 'ACTIVE';
                      final name = (u['displayName'] ?? 'Chưa có tên')
                          .toString();
                      return Card(
                        color: AppColors.surface,
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              name.trim().isEmpty
                                  ? '?'
                                  : name.trim().substring(0, 1).toUpperCase(),
                            ),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${u['email'] ?? ''}\n$roleText · ${u['status'] ?? 'UNKNOWN'}',
                          ),
                          isThreeLine: true,
                          onTap: () => _changeRole(u),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (u['employeeId'] == null)
                                IconButton(
                                  tooltip: 'Tạo hồ sơ nhân viên',
                                  icon: const Icon(Icons.badge_outlined),
                                  onPressed: () => _createProfile(u),
                                ),
                              IconButton(
                                tooltip: 'Phân quyền',
                                icon: const Icon(
                                  Icons.admin_panel_settings_outlined,
                                ),
                                onPressed: () => _openPermissions(u),
                              ),
                              Switch(
                                value: active,
                                onChanged: (v) => _toggleStatus(u, v),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: _createAccount,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      child: const Icon(Icons.add),
    ),
    bottomNavigationBar: AdminBottomNavigation(
      selectedIndex: 1,
      onDestinationSelected: (index) {
        if (index == 0) context.go(RouteNames.adminHome);
        if (index == 1) return;
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

class _CreateAccountDialogControllers extends StatefulWidget {
  const _CreateAccountDialogControllers({
    required this.controllers,
    required this.child,
  });

  final List<TextEditingController> controllers;
  final Widget child;

  @override
  State<_CreateAccountDialogControllers> createState() =>
      _CreateAccountDialogControllersState();
}

class _CreateAccountDialogControllersState
    extends State<_CreateAccountDialogControllers> {
  @override
  Widget build(BuildContext context) => widget.child;

  @override
  void dispose() {
    for (final controller in widget.controllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
