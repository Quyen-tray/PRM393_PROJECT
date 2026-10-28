import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../data/mock/demo_data.dart';
import '../../home/presentation/widgets/manager_more_menu.dart';

enum _EmployeeFilter { all, working, paused, onLeave }

class ManagerEmployeeListPage extends StatefulWidget {
  const ManagerEmployeeListPage({super.key});

  @override
  State<ManagerEmployeeListPage> createState() => _ManagerEmployeeListPageState();
}

class _ManagerEmployeeListPageState extends State<ManagerEmployeeListPage> {
  static const _employees = DemoData.managerEmployees;
  static const _filters = <(_EmployeeFilter, String)>[
    (_EmployeeFilter.all, 'Tất cả'),
    (_EmployeeFilter.working, 'Đang làm'),
    (_EmployeeFilter.paused, 'Tạm nghỉ'),
    (_EmployeeFilter.onLeave, 'Nghỉ phép'),
  ];

  _EmployeeFilter _selectedFilter = _EmployeeFilter.all;
  String _searchQuery = '';

  int _countFor(_EmployeeFilter filter) {
    if (filter == _EmployeeFilter.all) return _employees.length;
    return _employees.where((employee) {
      return switch (filter) {
        _EmployeeFilter.all => true,
        _EmployeeFilter.working =>
          employee.status == DemoManagerEmployeeStatus.working,
        _EmployeeFilter.paused =>
          employee.status == DemoManagerEmployeeStatus.paused,
        _EmployeeFilter.onLeave =>
          employee.status == DemoManagerEmployeeStatus.onLeave,
      };
    }).length;
  }

  List<DemoManagerEmployee> get _visibleEmployees {
    final query = _searchQuery.trim().toLowerCase();

    return _employees.where((employee) {
      final matchesFilter = switch (_selectedFilter) {
        _EmployeeFilter.all => true,
        _EmployeeFilter.working =>
          employee.status == DemoManagerEmployeeStatus.working,
        _EmployeeFilter.paused =>
          employee.status == DemoManagerEmployeeStatus.paused,
        _EmployeeFilter.onLeave =>
          employee.status == DemoManagerEmployeeStatus.onLeave,
      };
      final matchesSearch = query.isEmpty ||
          employee.name.toLowerCase().contains(query) ||
          employee.employeeCode.toLowerCase().contains(query) ||
          employee.position.toLowerCase().contains(query);

      return matchesFilter && matchesSearch;
    }).toList();
  }

  Future<void> _showEmployeeFilterSheet() async {
    final selectedFilter = await showModalBottomSheet<_EmployeeFilter>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Lọc nhân viên',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            for (final (filter, label) in _filters)
              ListTile(
                title: Text('$label (${_countFor(filter)})'),
                trailing: _selectedFilter == filter
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(sheetContext, filter),
              ),
          ],
        ),
      ),
    );

    if (!mounted || selectedFilter == null) return;
    setState(() => _selectedFilter = selectedFilter);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Quản lý nhân viên'),
        leading: IconButton(
          tooltip: 'Quay lại tổng quan',
          onPressed: () => context.go(RouteNames.home),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Tìm theo tên, mã hoặc chức vụ...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Lọc nhân viên',
                    onPressed: _showEmployeeFilterSheet,
                    icon: const Icon(Icons.tune),
                  ),
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
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary),
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
                      color: selected ? AppColors.primary : const Color(0xFFEDE8E3),
                    ),
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _visibleEmployees.isEmpty
                  ? const Center(
                      child: Text(
                        'Không tìm thấy nhân viên phù hợp.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                      itemCount: _visibleEmployees.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 9),
                      itemBuilder: (context, index) {
                        final employee = _visibleEmployees[index];
                        return _EmployeeCard(
                          employee: employee,
                          onTap: () => context.go(
                            RouteNames.managerEmployeeDetailFor(
                              employee.employeeCode,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 1,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Tổng quan',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Nhân viên',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Lịch',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check),
            label: 'Duyệt',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'Khác',
          ),
        ],
        onDestinationSelected: (index) {
          if (index == 0) context.go(RouteNames.home);
          if (index == 2) context.go(RouteNames.managerSchedule);
          if (index == 3) context.go(RouteNames.managerApprovals);
          if (index == 4) showManagerMoreMenu(context);
        },
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({required this.employee, required this.onTap});

  final DemoManagerEmployee employee;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (employee.status) {
      DemoManagerEmployeeStatus.working => const Color(0xFF25804B),
      DemoManagerEmployeeStatus.paused => const Color(0xFFB96D17),
      DemoManagerEmployeeStatus.onLeave => const Color(0xFF487DA3),
    };
    final statusLabel = switch (employee.status) {
      DemoManagerEmployeeStatus.working => 'Đang làm',
      DemoManagerEmployeeStatus.paused => 'Tạm nghỉ',
      DemoManagerEmployeeStatus.onLeave => 'Nghỉ phép',
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFEDE8E3)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Color(employee.avatarColorValue),
                child: Text(
                  employee.initials,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${employee.employeeCode} · ${employee.position}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
