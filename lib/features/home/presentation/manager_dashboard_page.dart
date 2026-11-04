import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/repositories/employee_providers.dart';
import '../../auth/data/auth_providers.dart';
import '../../../data/repositories/employee_repository.dart';
import 'widgets/manager_bottom_navigation.dart';
import '../../auth/domain/entities/user.dart';

const _borderColor = Color(0xFFEDE8E3);

/// Nhãn và đích điều hướng cho từng loại việc trong `nextActions` của backend.
/// Loại chưa có màn trong app hoặc thuộc vai trò khác thì đích là null (chỉ hiển thị số lượng).
class _ActionInfo {
  const _ActionInfo(this.label, this.route);
  final String label;
  final String? route;
}

const _actionInfo = <String, _ActionInfo>{
  'devices': _ActionInfo('Thiết bị chờ duyệt', RouteNames.managerDevices),
  'explanations': _ActionInfo(
    'Giải trình chờ duyệt',
    RouteNames.managerApprovals,
  ),
  'overtime': _ActionInfo('Đề nghị tăng ca', RouteNames.managerApprovals),
  'adjustmentsAwaitingManager': _ActionInfo(
    'Điều chỉnh công chờ duyệt',
    RouteNames.managerApprovals,
  ),
  'adjustmentsAwaitingHr': _ActionInfo('Điều chỉnh chờ HR', null),
  'checklistReviews': _ActionInfo(
    'Checklist chờ duyệt',
    RouteNames.managerChecklistApprovals,
  ),
  'documents': _ActionInfo('Hồ sơ chờ duyệt', RouteNames.managerDocumentReview),
  'violations': _ActionInfo(
    'Vi phạm chờ xác nhận',
    RouteNames.managerViolations,
  ),
  'rewardsAndPenalties': _ActionInfo(
    'Thưởng/phạt chờ duyệt',
    RouteNames.managerRewards,
  ),
};

const _weekdays = [
  'Thứ Hai',
  'Thứ Ba',
  'Thứ Tư',
  'Thứ Năm',
  'Thứ Sáu',
  'Thứ Bảy',
  'Chủ nhật',
];

/// "2026-11-02" -> "Thứ Hai, 02/11/2026".
String _dateLabel(String? iso) {
  final date = DateTime.tryParse(iso ?? '');
  if (date == null) return '—';
  final dd = date.day.toString().padLeft(2, '0');
  final mm = date.month.toString().padLeft(2, '0');
  return '${_weekdays[date.weekday - 1]}, $dd/$mm/${date.year}';
}

int _intOf(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

Map<String, dynamic> _mapOf(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

/// Dữ liệu đã đọc của dashboard, tách sẵn các phần cần hiển thị.
class _DashboardData {
  const _DashboardData({
    required this.date,
    required this.present,
    required this.scheduled,
    required this.late,
    required this.absent,
    required this.pendingTotal,
    required this.nextActions,
    required this.entries,
    required this.canReviewDocuments,
  });

  final String? date;
  final int present;
  final int scheduled;
  final int late;
  final int absent;
  final int pendingTotal;
  final List<({String queue, int count})> nextActions;
  final List<_AttendanceEntry> entries;
  final bool canReviewDocuments;
}

class _AttendanceEntry {
  const _AttendanceEntry({
    required this.name,
    required this.subtitle,
    required this.timeLabel,
    required this.statusLabel,
    required this.statusColor,
    required this.isLate,
  });

  final String name;
  final String subtitle;
  final String timeLabel;
  final String statusLabel;
  final Color statusColor;
  final bool isLate;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  factory _AttendanceEntry.fromRecord(Map<String, dynamic> row) {
    final status = row['attendanceStatus']?.toString();
    final late = _intOf(row['lateMinutes']);
    final checkIn = formatTimeOfDay(row['checkInAt'], fallback: '');
    final isLate = status == 'LATE' || late > 0;
    final needsAttention =
        isLate || status == 'MISSING' || (status ?? '').startsWith('PENDING');
    final timeParts = <String>[
      checkIn.isEmpty ? 'Chưa check-in' : 'Vào lúc $checkIn',
      if (late > 0) 'trễ $late phút',
    ];
    return _AttendanceEntry(
      name: (row['employeeName'] ?? 'Mã ${row['employeeId'] ?? '—'}')
          .toString(),
      subtitle: 'Mã nhân viên ${row['employeeId'] ?? '—'}',
      timeLabel: timeParts.join(' · '),
      statusLabel: attendanceStatusLabel(status),
      statusColor: needsAttention
          ? const Color(0xFFB96D17)
          : const Color(0xFF287A38),
      isLate: isLate,
    );
  }
}

class ManagerDashboardPage extends ConsumerStatefulWidget {
  const ManagerDashboardPage({super.key});

  @override
  ConsumerState<ManagerDashboardPage> createState() =>
      _ManagerDashboardPageState();
}

class _ManagerDashboardPageState extends ConsumerState<ManagerDashboardPage> {
  _DashboardData? _data;
  String _managerName = 'Quản lý';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(employeeRepositoryProvider);
      final today = DateTime.now();
      final todayIso =
          '${today.year.toString().padLeft(4, '0')}-'
          '${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final results = await Future.wait<Object>([
        repo.getManagerDashboardOverview(),
        repo.getAttendanceRecords(from: todayIso, to: todayIso),
        ref.read(authRepositoryProvider).getCurrentUser(),
        repo.getCurrentAccess(),
      ]);
      if (!mounted) return;

      final overview = results[0] as Map<String, dynamic>;
      final stats = _mapOf(overview['attendanceToday']);
      final pending = _mapOf(overview['pending']);
      final actions =
          (overview['nextActions'] as List?)
              ?.whereType<Map>()
              .map(
                (item) => (
                  queue: item['queue']?.toString() ?? '',
                  count: _intOf(item['count']),
                ),
              )
              .toList() ??
          <({String queue, int count})>[];
      final records = (results[1] as List<Map<String, dynamic>>)
          .map(_AttendanceEntry.fromRecord)
          .toList();
      final account = results[2] as User;
      final access = results[3] as CurrentAccess;

      setState(() {
        _managerName = account.fullName.trim().isEmpty
            ? 'Quản lý'
            : account.fullName;
        _data = _DashboardData(
          date: overview['date']?.toString(),
          present: _intOf(stats['checkedInOnTime']) + _intOf(stats['late']),
          scheduled: _intOf(stats['scheduledShifts']),
          late: _intOf(stats['late']),
          absent: _intOf(stats['absent']),
          pendingTotal: pending.values.fold<int>(
            0,
            (sum, value) => sum + _intOf(value),
          ),
          nextActions: actions,
          entries: records,
          canReviewDocuments: access.canReviewDocuments,
        );
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Không tải được tổng quan. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openAction(String queue) {
    if (queue == 'documents' && _data?.canReviewDocuments != true) return;
    final route = _actionInfo[queue]?.route;
    if (route != null) {
      context.go(
        route,
        extra: route == RouteNames.managerDocumentReview
            ? RouteNames.home
            : null,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: data == null
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  children: [
                    _ManagerHeader(onRefresh: _loading ? null : _load),
                    const SizedBox(height: 40),
                    if (_loading)
                      const Center(child: CircularProgressIndicator())
                    else
                      _ErrorBlock(
                        message: _error ?? 'Không tải được tổng quan.',
                        onRetry: _load,
                      ),
                  ],
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  children: [
                    _ManagerHeader(onRefresh: _loading ? null : _load),
                    const SizedBox(height: 18),
                    Text(
                      'Xin chào, $_managerName',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Quản lý cửa hàng',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _DateLabel(date: _dateLabel(data.date)),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columnCount = constraints.maxWidth >= 900 ? 4 : 2;
                        final tileWidth =
                            (constraints.maxWidth - 10.0 * (columnCount - 1)) /
                            columnCount;
                        final metrics = [
                          _ManagerMetric(
                            label: 'Có mặt hôm nay',
                            value: '${data.present}/${data.scheduled}',
                            icon: Icons.people_alt_outlined,
                            color: const Color(0xFF28A765),
                          ),
                          _ManagerMetric(
                            label: 'Đi muộn',
                            value: '${data.late}',
                            icon: Icons.alarm_on_outlined,
                            color: const Color(0xFFE75B59),
                          ),
                          _ManagerMetric(
                            label: 'Vắng',
                            value: '${data.absent}',
                            icon: Icons.person_off_outlined,
                            color: const Color(0xFFE75B59),
                          ),
                          _ManagerMetric(
                            label: 'Việc chờ duyệt',
                            value: '${data.pendingTotal}',
                            icon: Icons.fact_check_outlined,
                            color: const Color(0xFFE39A2F),
                          ),
                        ];
                        return GridView.count(
                          crossAxisCount: columnCount,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: tileWidth / 112,
                          children: [
                            for (final metric in metrics)
                              _ManagerMetricCard(metric: metric),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Việc cần duyệt',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _NextActions(
                      actions: data.nextActions,
                      canReviewDocuments: data.canReviewDocuments,
                      onTap: _openAction,
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Chấm công hôm nay',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              context.go(RouteNames.managerAttendanceReport),
                          child: const Text('Xem tất cả'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (data.entries.isEmpty)
                      const _EmptyBlock(
                        message: 'Chưa có bản ghi chấm công hôm nay.',
                      )
                    else
                      _AttendanceList(entries: _sortedEntries(data.entries)),
                  ],
                ),
        ),
      ),
      bottomNavigationBar: const ManagerBottomNavigation(selectedIndex: 0),
    );
  }

  /// Người đi muộn và cần chú ý lên đầu.
  List<_AttendanceEntry> _sortedEntries(List<_AttendanceEntry> entries) {
    final sorted = [...entries];
    sorted.sort((a, b) => (b.isLate ? 1 : 0).compareTo(a.isLate ? 1 : 0));
    return sorted;
  }
}

class _ManagerHeader extends StatelessWidget {
  const _ManagerHeader({required this.onRefresh});

  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.coffee, color: Color(0xFFF1D2A6), size: 22),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'HRM COFFEE SHOP',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Làm mới',
            onPressed: onRefresh,
            color: Colors.white,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}

class _DateLabel extends StatelessWidget {
  const _DateLabel({required this.date});

  final String date;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.calendar_today_outlined,
          size: 16,
          color: AppColors.primary,
        ),
        const SizedBox(width: 7),
        Text(
          date,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ManagerMetric {
  const _ManagerMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _ManagerMetricCard extends StatelessWidget {
  const _ManagerMetricCard({required this.metric});

  final _ManagerMetric metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: metric.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(metric.icon, color: metric.color, size: 19),
          ),
          Text(
            metric.value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            metric.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _NextActions extends StatelessWidget {
  const _NextActions({
    required this.actions,
    required this.canReviewDocuments,
    required this.onTap,
  });

  final List<({String queue, int count})> actions;
  final bool canReviewDocuments;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return const _EmptyBlock(message: 'Không có việc nào đang chờ.');
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          for (var index = 0; index < actions.length; index++) ...[
            if (index > 0) const Divider(height: 1),
            _ActionRow(
              label:
                  _actionInfo[actions[index].queue]?.label ??
                  actions[index].queue,
              count: actions[index].count,
              route: actions[index].queue == 'documents' && !canReviewDocuments
                  ? null
                  : _actionInfo[actions[index].queue]?.route,
              onTap: () => onTap(actions[index].queue),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.label,
    required this.count,
    required this.route,
    required this.onTap,
  });

  final String label;
  final int count;
  final String? route;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tappable = route != null;
    return Material(
      color: Colors.transparent,
      child: ListTile(
        dense: true,
        enabled: tappable,
        onTap: tappable ? onTap : null,
        title: Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: tappable
            ? null
            : const Text(
                'Xử lý ở màn khác hoặc chưa có trong app',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (tappable) ...[
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ],
        ),
      ),
    );
  }
}

class _AttendanceList extends StatelessWidget {
  const _AttendanceList({required this.entries});

  final List<_AttendanceEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        children: [
          for (var index = 0; index < entries.length; index++) ...[
            if (index > 0)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Divider(height: 1),
              ),
            _AttendanceRow(entry: entries[index]),
          ],
        ],
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({required this.entry});

  final _AttendanceEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: const Color(0xFFEAD9CC),
            child: Text(
              entry.initials,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  entry.subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  entry.timeLabel,
                  style: TextStyle(color: entry.statusColor, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: entry.statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              entry.statusLabel,
              style: TextStyle(
                color: entry.statusColor,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Center(
      child: Text(
        message,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
    ),
  );
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
      ],
    ),
  );
}
