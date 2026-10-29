import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../data/mock/demo_data.dart';

class EmployeeProfilePage extends StatefulWidget {
  const EmployeeProfilePage({super.key});

  @override
  State<EmployeeProfilePage> createState() => _EmployeeProfilePageState();
}

class _EmployeeProfilePageState extends State<EmployeeProfilePage> {
  _ProfileTab _selectedTab = _ProfileTab.info;
  final Map<String, String> _overrides = {};

  String _value(String key, String original) => _overrides[key] ?? original;

  Future<void> _editProfile() async {
    final employee = DemoData.employee;
    final nameController = TextEditingController(
      text: _value('name', employee.fullName),
    );
    final emailController = TextEditingController(
      text: _value('email', employee.email),
    );
    final phoneController = TextEditingController(
      text: _value('phone', employee.phone),
    );

    final updates = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Chỉnh sửa thông tin'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Họ và tên'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Số điện thoại'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop({
              'name': nameController.text.trim(),
              'email': emailController.text.trim(),
              'phone': phoneController.text.trim(),
            }),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();

    if (!mounted || updates == null) return;
    setState(() => _overrides.addAll(updates));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Đã cập nhật thông tin trên bản demo.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final employee = DemoData.employee;
    final employeeName = _value('name', employee.fullName);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Hồ sơ cá nhân'),
        leading: IconButton(
          tooltip: 'Quay lại trang chủ',
          onPressed: () => context.go(RouteNames.employeeHome),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              children: [
                _EmployeeProfileHeader(
                  name: employeeName,
                  code: employee.employeeCode,
                  position: employee.position,
                  status: employee.employmentStatus,
                ),
                const SizedBox(height: 14),
                SegmentedButton<_ProfileTab>(
                  segments: const [
                    ButtonSegment(
                      value: _ProfileTab.info,
                      label: Text('Thông tin'),
                    ),
                    ButtonSegment(
                      value: _ProfileTab.position,
                      label: Text('Chức danh'),
                    ),
                    ButtonSegment(
                      value: _ProfileTab.documents,
                      label: Text('Hồ sơ'),
                    ),
                  ],
                  selected: {_selectedTab},
                  onSelectionChanged: (tabs) {
                    setState(() => _selectedTab = tabs.first);
                  },
                ),
                const SizedBox(height: 14),
                if (_selectedTab == _ProfileTab.info) ...[
                  _ProfileSectionCard(
                    title: 'Thông tin cá nhân',
                    rows: [
                      _ProfileRowData('Mã nhân viên', employee.employeeCode),
                      _ProfileRowData('Email', _value('email', employee.email)),
                      _ProfileRowData('Số điện thoại', _value('phone', employee.phone)),
                      _ProfileRowData('Ngày vào làm', employee.hireDate),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _ProfileSectionCard(
                    title: 'Thông tin công việc',
                    rows: [
                      _ProfileRowData('Chức vụ', employee.position),
                      _ProfileRowData(
                        'Ca làm mặc định',
                        '${DemoData.currentShift.startTime} - '
                            '${DemoData.currentShift.endTime}',
                      ),
                      _ProfileRowData('Trạng thái', employee.employmentStatus),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _editProfile,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Chỉnh sửa thông tin'),
                    ),
                  ),
                ] else if (_selectedTab == _ProfileTab.position) ...[
                  _ProfileSectionCard(
                    title: 'Thông tin chức vụ',
                    rows: [
                      _ProfileRowData('Chức vụ', employee.position),
                      const _ProfileRowData('Chi nhánh', DemoData.storeBranch),
                      const _ProfileRowData(
                        'Quản lý trực tiếp',
                        'Trần Thị Bích Ngọc',
                      ),
                      _ProfileRowData(
                        'Ca làm mặc định',
                        '${DemoData.currentShift.startTime} - '
                            '${DemoData.currentShift.endTime}',
                      ),
                    ],
                  ),
                ] else ...[
                  const _ProfileSectionCard(
                    title: 'Thông tin hồ sơ',
                    rows: [
                      _ProfileRowData('Mã nhân viên', 'NV0012'),
                      _ProfileRowData('Ngày vào làm', '01/06/2026'),
                      _ProfileRowData('Nguồn dữ liệu', 'Hồ sơ demo cố định'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const _SectionHeading(
                    title: 'Chứng chỉ đã hoàn thành',
                    subtitle: 'Chứng chỉ mẫu từ các khóa đào tạo của nhân viên.',
                  ),
                  const SizedBox(height: 8),
                  for (final certificate in DemoData.employeeCertificates) ...[
                    _CertificateCard(certificate: certificate),
                    const SizedBox(height: 8),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 3,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Lịch',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'Checklist',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Cá nhân',
          ),
        ],
        onDestinationSelected: (index) {
          if (index == 0) {
            context.go(RouteNames.employeeHome);
          } else if (index == 1) {
            context.go(RouteNames.employeeSchedule);
          } else if (index == 2) {
            context.go(RouteNames.employeeChecklist);
          }
        },
      ),
    );
  }
}

enum _ProfileTab { info, position, documents }

class _EmployeeProfileHeader extends StatelessWidget {
  const _EmployeeProfileHeader({
    required this.name,
    required this.code,
    required this.position,
    required this.status,
  });

  final String name;
  final String code;
  final String position;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDE8E3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: const Color(0xFFEAD9CC),
            child: const Text(
              'AN',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$code · $position',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5F4E9),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(
                      color: Color(0xFF25804B),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileSectionCard extends StatelessWidget {
  const _ProfileSectionCard({required this.title, required this.rows});

  final String title;
  final List<_ProfileRowData> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDE8E3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (var index = 0; index < rows.length; index++) ...[
            if (index > 0)
              const Divider(height: 1, color: Color(0xFFEDE8E3)),
            _ProfileDataRow(row: rows[index]),
          ],
        ],
      ),
    );
  }
}

class _ProfileRowData {
  const _ProfileRowData(this.label, this.value);

  final String label;
  final String value;
}

class _ProfileDataRow extends StatelessWidget {
  const _ProfileDataRow({required this.row});

  final _ProfileRowData row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              row.label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              row.value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CertificateCard extends StatelessWidget {
  const _CertificateCard({required this.certificate});

  final DemoEmployeeCertificate certificate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDE8E3)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1D9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.workspace_premium_outlined,
              color: Color(0xFFBA821E),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  certificate.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Cấp ${certificate.issuedAt} · Hết hạn ${certificate.expiresAt}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.verified, color: Color(0xFF31A779), size: 19),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
