import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/repositories/employee_providers.dart';
import '../../../shared/widgets/employee_bottom_navigation.dart';

/// Nhãn trạng thái quyết định (DecisionView.status) cho nhân viên.
const _statusLabels = <String, String>{
  'PENDING_APPROVAL': 'Chờ duyệt',
  'APPROVED': 'Đã duyệt',
  'REJECTED': 'Đã từ chối',
  'CANCELLED': 'Đã hủy',
  'APPLIED': 'Đã vào lương',
};

/// Thưởng/phạt của chính nhân viên (chỉ đọc). Máy chủ trả đúng phạm vi của tài khoản đang đăng nhập.
///
/// Không hiển thị tổng số tiền: mỗi trang chỉ có một phần dữ liệu, nên tổng sẽ gây hiểu nhầm.
class EmployeeRewardsPage extends ConsumerStatefulWidget {
  const EmployeeRewardsPage({super.key});

  @override
  ConsumerState<EmployeeRewardsPage> createState() => _EmployeeRewardsPageState();
}

class _EmployeeRewardsPageState extends ConsumerState<EmployeeRewardsPage> {
  List<Map<String, dynamic>> _rows = [];
  int _page = 0;
  int _totalPages = 0;
  int _totalElements = 0;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch(0, replace: true);
  }

  int _fetchSeq = 0;

  Future<void> _fetch(int page, {required bool replace}) async {
    final seq = ++_fetchSeq;
    setState(() {
      _error = null;
      if (replace) {
        _loading = true;
        _loadingMore = false;
      } else {
        _loadingMore = true;
      }
    });
    try {
      final data = await ref.read(employeeRepositoryProvider).getMyDecisions(page: page);
      if (!mounted || seq != _fetchSeq) return;
      final items = (data['items'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      setState(() {
        _rows = replace ? items : [..._rows, ...items];
        _page = (data['page'] as num?)?.toInt() ?? page;
        _totalPages = (data['totalPages'] as num?)?.toInt() ?? 0;
        _totalElements = (data['totalElements'] as num?)?.toInt() ?? 0;
        _loading = false;
        _loadingMore = false;
      });
    } on ApiException catch (e) {
      if (!mounted || seq != _fetchSeq) return;
      setState(() {
        _error = e.message;
        _loading = false;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted || seq != _fetchSeq) return;
      setState(() {
        _error = 'Không tải được thưởng/phạt của bạn.';
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RouteNames.employeeProfile);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Thưởng/phạt của tôi'),
        leading: IconButton(
          tooltip: 'Quay lại',
          onPressed: _back,
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _loading ? null : () => _fetch(0, replace: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(child: _body()),
      bottomNavigationBar: const EmployeeBottomNavigation(selectedIndex: 3),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => _fetch(0, replace: true), child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }
    if (_rows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Bạn chưa có quyết định thưởng/phạt nào.', textAlign: TextAlign.center),
        ),
      );
    }

    final canLoadMore = _page + 1 < _totalPages;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Hiển thị ${_rows.length} / $_totalElements quyết định',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            itemCount: _rows.length + (canLoadMore ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == _rows.length) {
                return Center(
                  child: _loadingMore
                      ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())
                      : OutlinedButton(
                          onPressed: () => _fetch(_page + 1, replace: false),
                          child: const Text('Tải thêm'),
                        ),
                );
              }
              return _row(_rows[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _row(Map<String, dynamic> row) {
    final isReward = _s(row['decisionType']) == 'REWARD';
    final status = _s(row['status']);
    final reason = _s(row['reasonName']).isEmpty ? _s(row['reasonCode']) : _s(row['reasonName']);
    final description = _s(row['description']);
    final note = _s(row['reviewNote']);
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${isReward ? 'Thưởng' : 'Phạt'} · $reason',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                _chip(
                  _statusLabels[status] ?? (status.isEmpty ? 'Không rõ' : status),
                  _statusColor(status),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${_money(row['amount'])} · Áp dụng từ ${_vnDmy(row['effectiveAt'])}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(description, style: const TextStyle(fontSize: 13)),
            ],
            if (note.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Ghi chú duyệt: $note', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
            if (status == 'APPLIED') ...[
              const SizedBox(height: 6),
              const Text(
                'Đã tính vào kỳ lương, không thay đổi được.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) => switch (status) {
        'APPROVED' || 'APPLIED' => const Color(0xFF25804B),
        'REJECTED' => AppColors.error,
        'PENDING_APPROVAL' => const Color(0xFFB96D17),
        _ => AppColors.textSecondary,
      };

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      );
}

// ---------- Tiện ích ----------

String _s(Object? value) => value?.toString().trim() ?? '';

/// Số tiền dạng 50.000 ₫.
String _money(Object? value) {
  final number = value is num ? value : num.tryParse(_s(value));
  if (number == null) return '—';
  final digits = number.round().abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return '${number < 0 ? '-' : ''}$buffer ₫';
}

const _vnOffset = Duration(hours: 7);

String _two(int value) => value.toString().padLeft(2, '0');

/// dd/MM/yyyy theo giờ Việt Nam, bất kể múi giờ của máy. Trả về '—' nếu không đọc được.
String _vnDmy(Object? value) {
  final parsed = DateTime.tryParse(_s(value));
  if (parsed == null) return '—';
  final clock = parsed.toUtc().add(_vnOffset);
  return '${_two(clock.day)}/${_two(clock.month)}/${clock.year}';
}
