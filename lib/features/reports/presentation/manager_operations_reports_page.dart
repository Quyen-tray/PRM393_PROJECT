import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/repositories/employee_providers.dart';
import '../../home/presentation/widgets/manager_bottom_navigation.dart';

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class ManagerOperationsReportsPage extends ConsumerStatefulWidget {
  const ManagerOperationsReportsPage({super.key});

  @override
  ConsumerState<ManagerOperationsReportsPage> createState() =>
      _ManagerOperationsReportsPageState();
}

class _ManagerOperationsReportsPageState
    extends ConsumerState<ManagerOperationsReportsPage> {
  late final String _from;
  late final String _to;
  late Future<Map<String, dynamic>> _employeeStatus;
  late Future<Map<String, dynamic>> _attendanceSummary;
  late Future<List<Map<String, dynamic>>> _attendanceRecords;
  late Future<Map<String, dynamic>> _operations;
  late Future<Map<String, dynamic>> _rewards;
  late Future<List<Map<String, dynamic>>> _operationsReport;
  late Future<List<Map<String, dynamic>>> _periods;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = _isoDate(DateTime(now.year, now.month, 1));
    _to = _isoDate(now);
    final repo = ref.read(employeeRepositoryProvider);
    _employeeStatus = repo.getManagerEmployeeStatus();
    _attendanceSummary = repo.getAttendanceSummary(from: _from, to: _to);
    _attendanceRecords = repo.getAttendanceRecords(from: _from, to: _to);
    _operations = repo.getManagerOperations(from: _from, to: _to);
    _rewards = repo.getManagerRewardsPenalties(from: _from, to: _to);
    _operationsReport = repo.getOperationsReport(from: _from, to: _to);
    _periods = repo.getPayrollPeriods();
  }

  Future<void> _reload() async {
    final repo = ref.read(employeeRepositoryProvider);
    setState(() {
      _employeeStatus = repo.getManagerEmployeeStatus();
      _attendanceSummary = repo.getAttendanceSummary(from: _from, to: _to);
      _attendanceRecords = repo.getAttendanceRecords(from: _from, to: _to);
      _operations = repo.getManagerOperations(from: _from, to: _to);
      _rewards = repo.getManagerRewardsPenalties(from: _from, to: _to);
      _operationsReport = repo.getOperationsReport(from: _from, to: _to);
      _periods = repo.getPayrollPeriods();
    });
  }

  Future<void> _showPayrollReadiness(int periodId, String label) async {
    try {
      final data = await ref
          .read(employeeRepositoryProvider)
          .getPayrollReadinessReport(periodId);
      if (!mounted) return;
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text(
                'Mức sẵn sàng kỳ $label',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              for (final row in _rows(data))
                ListTile(
                  dense: true,
                  title: Text(row.$1),
                  subtitle: SelectableText(row.$2),
                ),
            ],
          ),
        ),
      );
    } catch (error) {
      _message(
        error is ApiException
            ? error.message
            : 'Không tải được mức sẵn sàng kỳ công.',
      );
    }
  }

  Future<void> _showAttendanceDetail(Map<String, dynamic> row) async {
    final id = (row['attendanceId'] ?? row['id']) as num?;
    if (id == null) return;
    try {
      final repo = ref.read(employeeRepositoryProvider);
      final values = await Future.wait<Object>([
        repo.getAttendanceDetail(id.toInt()),
        repo.getAttendanceVerifications(id.toInt()),
      ]);
      if (!mounted) return;
      final detail = values[0] as Map<String, dynamic>;
      final verifications = values[1] as List<Map<String, dynamic>>;
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text(
                'Chấm công #${id.toInt()}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              for (final entry in detail.entries)
                ListTile(
                  dense: true,
                  title: Text(entry.key),
                  subtitle: SelectableText('${entry.value ?? '—'}'),
                ),
              const Divider(),
              Text(
                'Lịch sử xác minh (${verifications.length})',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (verifications.isEmpty)
                const ListTile(title: Text('Chưa có bản ghi xác minh.')),
              for (final item in verifications)
                ListTile(
                  dense: true,
                  title: Text(
                    '${item['verificationType'] ?? item['type'] ?? 'Xác minh'} · ${item['status'] ?? ''}',
                  ),
                  subtitle: Text(
                    '${item['createdAt'] ?? item['verifiedAt'] ?? ''}',
                  ),
                ),
            ],
          ),
        ),
      );
    } catch (error) {
      _message(
        error is ApiException
            ? error.message
            : 'Không tải được chi tiết chấm công.',
      );
    }
  }

  List<(String, String)> _rows(Map<String, dynamic> values) => [
    for (final entry in values.entries)
      (
        entry.key,
        entry.value is Map || entry.value is List
            ? entry.value.toString()
            : '${entry.value ?? '—'}',
      ),
  ];

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Báo cáo vận hành'),
        leading: IconButton(
          onPressed: () => context.go(RouteNames.home),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
        ],
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Tổng quan'),
            Tab(text: 'Báo cáo'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Kỳ báo cáo: $_from – $_to',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                _DataPanel(
                  title: 'Tình trạng nhân sự',
                  future: _employeeStatus,
                ),
                _DataPanel(
                  title: 'Tổng hợp chấm công',
                  future: _attendanceSummary,
                ),
                _DataPanel(title: 'Vận hành cửa hàng', future: _operations),
                _DataPanel(title: 'Thưởng và phạt', future: _rewards),
              ],
            ),
          ),
          RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _DataPanel(
                  title: 'Chi tiết vận hành',
                  future: _operationsReport,
                ),
                const SizedBox(height: 8),
                _AttendanceRecordsPanel(
                  future: _attendanceRecords,
                  onTap: _showAttendanceDetail,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Mức sẵn sàng chốt kỳ lương',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 8),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _periods,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Text(
                        snapshot.error is ApiException
                            ? (snapshot.error as ApiException).message
                            : 'Không tải được danh sách kỳ.',
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    final periods = snapshot.data!;
                    if (periods.isEmpty) {
                      return const Card(
                        child: ListTile(title: Text('Chưa có kỳ công.')),
                      );
                    }
                    return Column(
                      children: [
                        for (final period in periods)
                          Card(
                            color: AppColors.surface,
                            child: ListTile(
                              title: Text(
                                '${period['periodCode'] ?? 'Kỳ công'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                '${period['status'] ?? period['periodStatus'] ?? ''} · ${period['startDate'] ?? ''} – ${period['endDate'] ?? ''}',
                              ),
                              trailing: const Icon(Icons.fact_check_outlined),
                              onTap: () {
                                final id =
                                    (period['periodId'] ??
                                            period['payrollPeriodId'])
                                        as num?;
                                if (id != null) {
                                  _showPayrollReadiness(
                                    id.toInt(),
                                    '${period['periodCode'] ?? id}',
                                  );
                                }
                              },
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const ManagerBottomNavigation(selectedIndex: 4),
    ),
  );
}

class _DataPanel extends StatelessWidget {
  const _DataPanel({required this.title, required this.future});
  final String title;
  final Future<dynamic> future;

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.surface,
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: FutureBuilder<dynamic>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
            );
          }
          if (snapshot.hasError) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  snapshot.error is ApiException
                      ? (snapshot.error as ApiException).message
                      : 'Không tải được dữ liệu.',
                  style: const TextStyle(color: AppColors.error),
                ),
              ],
            );
          }
          final value = snapshot.data;
          final rows = value is Map<String, dynamic>
              ? value.entries
                    .map((entry) => (entry.key, '${entry.value ?? '—'}'))
                    .toList()
              : value is List
              ? value
                    .asMap()
                    .entries
                    .map((entry) => ('Mục ${entry.key + 1}', '${entry.value}'))
                    .toList()
              : <(String, String)>[];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              if (rows.isEmpty)
                const Text(
                  'Không có dữ liệu trong kỳ này.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 148,
                        child: Text(
                          row.$1,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        child: SelectableText(
                          row.$2,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

class _AttendanceRecordsPanel extends StatelessWidget {
  const _AttendanceRecordsPanel({required this.future, required this.onTap});
  final Future<List<Map<String, dynamic>>> future;
  final ValueChanged<Map<String, dynamic>> onTap;

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.surface,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return Text(
                snapshot.error is ApiException
                    ? (snapshot.error as ApiException).message
                    : 'Không tải được bản ghi công.',
              );
            }
            return const LinearProgressIndicator();
          }
          final records = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bản ghi chấm công (${records.length})',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              if (records.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Không có bản ghi trong kỳ này.'),
                ),
              for (final record in records.take(40))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${record['employeeName'] ?? 'Nhân viên ${record['employeeId'] ?? '—'}'} · ${record['workDate'] ?? ''}',
                  ),
                  subtitle: Text(
                    '${record['attendanceStatus'] ?? record['status'] ?? ''} · vào ${record['checkInAt'] ?? '—'} · ra ${record['checkOutAt'] ?? '—'}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onTap(record),
                ),
            ],
          );
        },
      ),
    ),
  );
}
