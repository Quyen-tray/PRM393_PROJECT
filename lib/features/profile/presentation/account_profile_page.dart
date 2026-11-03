import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/presentation/sign_out_flow.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/repositories/employee_providers.dart';
import '../../../shared/widgets/employee_bottom_navigation.dart';
import '../../auth/data/auth_providers.dart';
import '../../auth/domain/entities/user.dart';
import '../../documents/presentation/employee_documents_tab.dart';

/// Shared account profile. Employment information is an optional linked record.
class AccountProfilePage extends ConsumerStatefulWidget {
  const AccountProfilePage({
    super.key,
    this.initialTab = 0,
    this.documentPicker,
  });

  final int initialTab;
  final DocumentPicker? documentPicker;

  @override
  ConsumerState<AccountProfilePage> createState() => _AccountProfilePageState();
}

class _AccountProfilePageState extends ConsumerState<AccountProfilePage> {
  late int _selectedTab;
  late Future<_AccountProfileData> _profileFuture;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab.clamp(0, 2).toInt();
    _profileFuture = _loadProfile();
  }

  Future<_AccountProfileData> _loadProfile() async {
    final account = await ref.read(authRepositoryProvider).getCurrentUser();
    if (account.employeeId == null) {
      return _AccountProfileData(account: account);
    }

    try {
      final employee = await ref
          .read(employeeRepositoryProvider)
          .getEmployeeProfile();
      return _AccountProfileData(account: account, employee: employee);
    } catch (error) {
      // Account identity remains usable if the optional HR record is unavailable.
      return _AccountProfileData(account: account, employeeError: error);
    }
  }

  void _reload() {
    setState(() {
      _profileFuture = _loadProfile();
    });
  }

  Future<void> _goBack() async {
    final data = await _profileFuture;
    if (!mounted) return;
    context.go(_homeFor(data.account));
  }

  Future<void> _editProfile(User account) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _AccountProfileEditDialog(
        fullName: account.fullName,
        phone: account.phoneNumber ?? '',
      ),
    );
    if (!mounted || result == null) return;
    if (result['name']!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Họ và tên không được để trống.')),
      );
      return;
    }

    try {
      await ref
          .read(authRepositoryProvider)
          .updateCurrentUser(
            displayName: result['name'],
            phoneNumber: result['phone'],
          );
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã cập nhật hồ sơ.')));
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  String _homeFor(User account) => switch (account.primaryRole) {
    UserRole.systemAdmin => RouteNames.adminHome,
    UserRole.storeManager => RouteNames.home,
    UserRole.employee => RouteNames.employeeHome,
    _ => RouteNames.login,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Hồ sơ cá nhân'),
        leading: IconButton(
          tooltip: 'Quay lại',
          onPressed: _goBack,
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: () => signOutAndReturnToLogin(context, ref),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: FutureBuilder<_AccountProfileData>(
              future: _profileFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return _ProfileLoadError(
                    message:
                        snapshot.error?.toString() ??
                        'Không tải được thông tin tài khoản.',
                    onRetry: _reload,
                  );
                }

                final data = snapshot.data!;
                final account = data.account;
                final employee = data.employee;
                final hasEmployee = account.employeeId != null;
                final selectedTab = hasEmployee ? _selectedTab : 0;
                final name = account.fullName.trim().isEmpty
                    ? 'Chưa cập nhật'
                    : account.fullName;
                final position = (employee?['jobTitle'] ?? 'Chưa phân công')
                    .toString();
                final status = employee == null
                    ? (hasEmployee
                          ? 'Chưa tải được hồ sơ nhân viên'
                          : 'Tài khoản')
                    : employmentStatusLabel(
                        employee['employmentStatus']?.toString(),
                      );

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  children: [
                    _ProfileHeader(
                      name: name,
                      subtitle: hasEmployee ? position : _roleLabel(account),
                      status: status,
                      avatarUrl: account.avatarUrl,
                    ),
                    const SizedBox(height: 14),
                    if (hasEmployee)
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 0, label: Text('Thông tin')),
                          ButtonSegment(value: 1, label: Text('Chức danh')),
                          ButtonSegment(value: 2, label: Text('Hồ sơ')),
                        ],
                        selected: {selectedTab},
                        onSelectionChanged: (value) =>
                            setState(() => _selectedTab = value.first),
                      ),
                    const SizedBox(height: 14),
                    if (selectedTab == 0) ...[
                      _InfoCard(
                        title: 'Thông tin tài khoản',
                        rows: {
                          if (employee != null)
                            'Mã nhân viên': (employee['employeeCode'] ?? '—')
                                .toString(),
                          'Email': account.email.isEmpty ? '—' : account.email,
                          'Số điện thoại': account.phoneNumber ?? '—',
                          if (employee != null)
                            'Ngày vào làm': formatDate(employee['hireDate']),
                        },
                      ),
                      if (hasEmployee) ...[
                        const SizedBox(height: 12),
                        if (employee != null)
                          _InfoCard(
                            title: 'Thông tin công việc',
                            rows: {
                              'Chức vụ': position,
                              'Loại nhân viên': employmentTypeLabel(
                                employee['employmentType']?.toString(),
                              ),
                              'Trạng thái': status,
                              'Tình trạng hồ sơ': employeeProfileStatusLabel(
                                employee['profileStatus']?.toString(),
                              ),
                              'Điều kiện nhận ca': shiftEligibilityLabel(
                                employee['shiftEligibility']?.toString(),
                              ),
                            },
                          )
                        else
                          _OptionalEmployeeError(
                            error: data.employeeError,
                            onRetry: _reload,
                          ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _editProfile(account),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Chỉnh sửa thông tin'),
                        ),
                      ),
                    ] else if (selectedTab == 1 && employee != null) ...[
                      _InfoCard(
                        title: 'Thông tin chức danh',
                        rows: {
                          'Chức vụ': position,
                          'Mã chức danh': (employee['positionId'] ?? '—')
                              .toString(),
                          'Loại nhân viên': employmentTypeLabel(
                            employee['employmentType']?.toString(),
                          ),
                        },
                      ),
                    ] else if (selectedTab == 2 && employee != null) ...[
                      EmployeeDocumentsTab(
                        picker:
                            widget.documentPicker ??
                            const PlatformDocumentPicker(),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
      bottomNavigationBar: FutureBuilder<_AccountProfileData>(
        future: _profileFuture,
        builder: (context, snapshot) {
          final account = snapshot.data?.account;
          if (account == null || account.primaryRole != UserRole.employee) {
            return const SizedBox.shrink();
          }
          return const EmployeeBottomNavigation(selectedIndex: 3);
        },
      ),
    );
  }
}

String _roleLabel(User account) {
  if (account.primaryRole == UserRole.systemAdmin) return 'Quản trị hệ thống';
  if (account.primaryRole == UserRole.storeManager) return 'Quản lý';
  if (account.primaryRole == UserRole.employee) return 'Nhân viên';
  return 'Tài khoản';
}

class _AccountProfileData {
  const _AccountProfileData({
    required this.account,
    this.employee,
    this.employeeError,
  });

  final User account;
  final Map<String, dynamic>? employee;
  final Object? employeeError;
}

class _ProfileLoadError extends StatelessWidget {
  const _ProfileLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 40),
          const SizedBox(height: 12),
          const Text('Không tải được hồ sơ'),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    ),
  );
}

class _OptionalEmployeeError extends StatelessWidget {
  const _OptionalEmployeeError({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.info_outline),
      title: const Text('Chưa tải được thông tin nhân viên'),
      subtitle: Text(error?.toString() ?? 'Vui lòng thử tải lại.'),
      trailing: IconButton(
        tooltip: 'Thử lại',
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
      ),
    ),
  );
}

class _AccountProfileEditDialog extends StatefulWidget {
  const _AccountProfileEditDialog({
    required this.fullName,
    required this.phone,
  });

  final String fullName;
  final String phone;

  @override
  State<_AccountProfileEditDialog> createState() =>
      _AccountProfileEditDialogState();
}

class _AccountProfileEditDialogState extends State<_AccountProfileEditDialog> {
  late final TextEditingController _name;
  late final TextEditingController _phone;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.fullName);
    _phone = TextEditingController(text: widget.phone);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Chỉnh sửa thông tin'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _name,
          maxLength: 150,
          decoration: const InputDecoration(labelText: 'Họ và tên'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _phone,
          maxLength: 20,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Số điện thoại'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, {
          'name': _name.text.trim(),
          'phone': _phone.text.trim(),
        }),
        child: const Text('Lưu'),
      ),
    ],
  );
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.subtitle,
    required this.status,
    required this.avatarUrl,
  });

  final String name;
  final String subtitle;
  final String status;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE5E1DA)),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 31,
          backgroundImage: avatarUrl == null ? null : NetworkImage(avatarUrl!),
          child: avatarUrl == null ? const Icon(Icons.person, size: 30) : null,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(subtitle),
              const SizedBox(height: 7),
              Text(
                status,
                style: const TextStyle(
                  color: Color(0xFF25804B),
                  fontSize: 12,
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.rows});

  final String title;
  final Map<String, String> rows;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final entry in rows.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 145,
                    child: Text(
                      entry.key,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  Expanded(child: Text(entry.value)),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
