import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/repositories/employee_providers.dart';

class EmployeeProfilePage extends ConsumerStatefulWidget {
  const EmployeeProfilePage({super.key});

  @override
  ConsumerState<EmployeeProfilePage> createState() => _EmployeeProfilePageState();
}

class _EmployeeProfilePageState extends ConsumerState<EmployeeProfilePage> {
  int _selectedTab = 0;
  late Future<Map<String, dynamic>> _profileFuture;
  late Future<List<Map<String, dynamic>>> _certificatesFuture;

  @override
  void initState() {
    super.initState();
    _loadFutures();
  }

  void _loadFutures() {
    final repo = ref.read(employeeRepositoryProvider);
    _profileFuture = repo.getEmployeeProfile();
    _certificatesFuture = repo.getMyTraining();
  }

  void _reload() => setState(_loadFutures);

  Future<void> _editProfile(Map<String, dynamic> employee) async {
    final name = TextEditingController(text: (employee['fullName'] ?? '').toString());
    final phone = TextEditingController(text: (employee['phone'] ?? '').toString());
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Chỉnh sửa thông tin'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, maxLength: 150, decoration: const InputDecoration(labelText: 'Họ và tên')),
          const SizedBox(height: 8),
          TextField(controller: phone, maxLength: 20, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Số điện thoại')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, {'name': name.text.trim(), 'phone': phone.text.trim()}), child: const Text('Lưu')),
        ],
      ),
    );
    name.dispose();
    phone.dispose();
    if (!mounted || result == null) return;
    if (result['name']!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Họ và tên không được để trống.')));
      return;
    }
    try {
      await ref.read(employeeRepositoryProvider).updateMyAccount(
        displayName: result['name'],
        phoneNumber: result['phone'],
      );
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật hồ sơ.')));
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Hồ sơ cá nhân'),
        leading: IconButton(tooltip: 'Quay lại trang chủ', onPressed: () => context.go(RouteNames.employeeHome), icon: const Icon(Icons.arrow_back)),
        actions: [IconButton(tooltip: 'Tải lại', onPressed: _reload, icon: const Icon(Icons.refresh))],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: FutureBuilder<Map<String, dynamic>>(
              future: _profileFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError || !snapshot.hasData) {
                  return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.cloud_off_outlined, size: 40),
                    const SizedBox(height: 12),
                    const Text('Không tải được hồ sơ'),
                    const SizedBox(height: 8),
                    Text(snapshot.error?.toString() ?? 'Lỗi không xác định', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _reload, child: const Text('Thử lại')),
                  ])));
                }
                final employee = snapshot.data!;
                final name = (employee['fullName'] ?? 'Chưa cập nhật').toString();
                final code = (employee['employeeCode'] ?? '—').toString();
                final position = (employee['jobTitle'] ?? 'Chưa phân công').toString();
                final status = (employee['employmentStatus'] ?? '—').toString();
                return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 20), children: [
                  _ProfileHeader(name: name, code: code, position: position, status: status),
                  const SizedBox(height: 14),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Thông tin')),
                      ButtonSegment(value: 1, label: Text('Chức danh')),
                      ButtonSegment(value: 2, label: Text('Hồ sơ')),
                    ],
                    selected: {_selectedTab},
                    onSelectionChanged: (value) => setState(() => _selectedTab = value.first),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.payments_outlined),
                      title: const Text('Thưởng/phạt của tôi'),
                      subtitle: const Text('Các quyết định về thưởng hoặc phạt liên quan đến bạn'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push(RouteNames.employeeRewards),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_selectedTab == 0) ...[
                    _InfoCard(title: 'Thông tin cá nhân', rows: {
                      'Mã nhân viên': code,
                      'Email': (employee['email'] ?? '—').toString(),
                      'Số điện thoại': (employee['phone'] ?? '—').toString(),
                      'Ngày vào làm': formatDate(employee['hireDate']),
                    }),
                    const SizedBox(height: 12),
                    _InfoCard(title: 'Thông tin công việc', rows: {
                      'Chức vụ': position,
                      'Loại nhân viên': (employee['employmentType'] ?? '—').toString(),
                      'Trạng thái': status,
                      'Tình trạng hồ sơ': (employee['profileStatus'] ?? '—').toString(),
                      'Điều kiện nhận ca': (employee['shiftEligibility'] ?? '—').toString(),
                    }),
                    const SizedBox(height: 12),
                    SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => _editProfile(employee), icon: const Icon(Icons.edit_outlined), label: const Text('Chỉnh sửa thông tin'))),
                  ] else if (_selectedTab == 1) ...[
                    _InfoCard(title: 'Thông tin chức danh', rows: {
                      'Chức vụ': position,
                      'Mã chức danh': (employee['positionId'] ?? '—').toString(),
                      'Loại nhân viên': (employee['employmentType'] ?? '—').toString(),
                    }),
                  ] else ...[
                    _InfoCard(title: 'Tình trạng hồ sơ', rows: {
                      'Trạng thái hồ sơ': (employee['profileStatus'] ?? '—').toString(),
                      'Ngày vào làm': formatDate(employee['hireDate']),
                    }),
                    const SizedBox(height: 12),
                    _CertificateSection(future: _certificatesFuture),
                  ],
                ]);
              },
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 3,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Trang chủ'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Lịch'),
          NavigationDestination(icon: Icon(Icons.checklist_outlined), selectedIcon: Icon(Icons.checklist), label: 'Checklist'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Cá nhân'),
        ],
        onDestinationSelected: (index) {
          if (index == 0) context.go(RouteNames.employeeHome);
          if (index == 1) context.go(RouteNames.employeeSchedule);
          if (index == 2) context.go(RouteNames.employeeChecklist);
        },
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.name, required this.code, required this.position, required this.status});
  final String name;
  final String code;
  final String position;
  final String status;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E1DA))),
    child: Row(children: [
      const CircleAvatar(radius: 28, child: Icon(Icons.person, size: 30)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        Text('$code · $position', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Text(status, style: const TextStyle(color: AppColors.primary, fontSize: 11)),
      ])),
    ]),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.rows});
  final String title;
  final Map<String, String> rows;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E1DA))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      for (final row in rows.entries) Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 145, child: Text(row.key, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
        Expanded(child: Text(row.value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
      ])),
    ]),
  );
}

/// Danh sách chứng chỉ: các khóa học đã đạt (PASSED) hoặc đã hết hạn (EXPIRED).
class _CertificateSection extends StatelessWidget {
  const _CertificateSection({required this.future});

  final Future<List<Map<String, dynamic>>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return const Text('Không tải được danh sách chứng chỉ.', style: TextStyle(color: AppColors.textSecondary));
        }
        final certificates = (snapshot.data ?? const <Map<String, dynamic>>[])
            .where((item) => item['status'] == 'PASSED' || item['status'] == 'EXPIRED')
            .toList();
        return Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E1DA))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Chứng chỉ đã hoàn thành', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (certificates.isEmpty)
                const Text('Chưa có chứng chỉ nào.', style: TextStyle(color: AppColors.textSecondary))
              else
                for (final item in certificates)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          item['status'] == 'EXPIRED' ? Icons.warning_amber_outlined : Icons.workspace_premium_outlined,
                          size: 18,
                          color: item['status'] == 'EXPIRED' ? AppColors.error : AppColors.secondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${item['courseName'] ?? 'Khóa học'}\n'
                            'Hoàn thành ${formatDate(item['completedAt'])} · Hiệu lực đến ${formatDate(item['expiresAt'])}'
                            '${item['status'] == 'EXPIRED' ? ' (đã hết hạn)' : ''}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}
