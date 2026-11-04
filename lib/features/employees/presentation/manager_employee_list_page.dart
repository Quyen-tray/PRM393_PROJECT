import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/repositories/employee_providers.dart';
import '../../home/presentation/widgets/manager_bottom_navigation.dart';

class ManagerEmployeeListPage extends ConsumerStatefulWidget {
  const ManagerEmployeeListPage({super.key});

  @override
  ConsumerState<ManagerEmployeeListPage> createState() =>
      _ManagerEmployeeListPageState();
}

class _ManagerEmployeeListPageState
    extends ConsumerState<ManagerEmployeeListPage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _employees = [];
  bool _loading = true;
  String? _error;
  String _filter = 'ALL';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({String? query}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data =
          await ref.read(employeeRepositoryProvider).getAllEmployees(q: query);
      if (!mounted) return;
      setState(() {
        _employees = data;
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
        _error = 'Không thể tải danh sách nhân viên.';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _visible => _employees.where((e) {
        final status = (e['employmentStatus'] ?? '').toString().toUpperCase();
        return _filter == 'ALL' || status == _filter;
      }).toList();

  String _statusLabel(String value) => switch (value.toUpperCase()) {
        'ACTIVE' => 'Đang làm',
        'ON_LEAVE' => 'Nghỉ phép',
        'SUSPENDED' => 'Tạm ngưng',
        'RESIGNED' => 'Đã nghỉ',
        _ => value.isEmpty ? 'Chưa rõ' : value,
      };

  Color _statusColor(String value) => switch (value.toUpperCase()) {
        'ACTIVE' => const Color(0xFF25804B),
        'ON_LEAVE' => const Color(0xFF487DA3),
        'SUSPENDED' => const Color(0xFFB96D17),
        _ => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Quản lý nhân viên'),
        leading: IconButton(
            onPressed: () => context.go(RouteNames.home),
            icon: const Icon(Icons.arrow_back)),
        actions: [
          IconButton(
              onPressed: () => _load(query: _searchController.text),
              icon: const Icon(Icons.refresh))
        ],
      ),
      body: SafeArea(
          child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: TextField(
            controller: _searchController,
            onSubmitted: (value) => _load(query: value),
            decoration: InputDecoration(
              hintText: 'Tìm theo tên, mã hoặc chức vụ...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _load();
                  }),
              filled: true,
              fillColor: AppColors.surface,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        SizedBox(
            height: 42,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: [
                ('ALL', 'Tất cả'),
                ('ACTIVE', 'Đang làm'),
                ('ON_LEAVE', 'Nghỉ phép'),
                ('SUSPENDED', 'Tạm ngưng'),
                ('RESIGNED', 'Đã nghỉ'),
              ]
                  .map((item) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                            label: Text(item.$2),
                            selected: _filter == item.$1,
                            onSelected: (_) =>
                                setState(() => _filter = item.$1),
                            showCheckmark: false),
                      ))
                  .toList(),
            )),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                          padding: const EdgeInsets.all(24),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.cloud_off,
                                size: 40, color: AppColors.textSecondary),
                            const SizedBox(height: 12),
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            FilledButton(
                                onPressed: () =>
                                    _load(query: _searchController.text),
                                child: const Text('Thử lại')),
                          ])))
                  : visible.isEmpty
                      ? const Center(child: Text('Không có nhân viên phù hợp.'))
                      : RefreshIndicator(
                          onRefresh: () => _load(query: _searchController.text),
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                            itemCount: visible.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 9),
                            itemBuilder: (context, index) {
                              final e = visible[index];
                              final name =
                                  (e['fullName'] ?? 'Chưa có tên').toString();
                              final code = (e['employeeCode'] ?? '').toString();
                              final status =
                                  (e['employmentStatus'] ?? '').toString();
                              final id = e['employeeId'];
                              return Card(
                                  color: AppColors.surface,
                                  child: ListTile(
                                    leading: CircleAvatar(
                                        child: Text(name.isEmpty
                                            ? '?'
                                            : name
                                                .trim()
                                                .substring(0, 1)
                                                .toUpperCase())),
                                    title: Text(name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    subtitle: Text(
                                        '$code · ${(e['jobTitle'] ?? 'Chưa có chức vụ')}'),
                                    trailing: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 9, vertical: 5),
                                        decoration: BoxDecoration(
                                            color: _statusColor(status)
                                                .withValues(alpha: .12),
                                            borderRadius:
                                                BorderRadius.circular(18)),
                                        child: Text(_statusLabel(status),
                                            style: TextStyle(
                                                color: _statusColor(status),
                                                fontSize: 11))),
                                    onTap: id is num
                                        ? () => context.go(
                                            RouteNames.managerEmployeeDetailFor(
                                                id.toInt().toString()))
                                        : null,
                                  ));
                            },
                          )),
        ),
      ])),
      bottomNavigationBar: const ManagerBottomNavigation(selectedIndex: 1),
    );
  }
}
