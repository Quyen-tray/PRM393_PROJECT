import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/repositories/employee_providers.dart';

/// Trạng thái giao thông báo (DeliveryStatus trong backend) và nhãn tiếng Việt.
const _statusFilters = <String, String>{
  '': 'Tất cả',
  'PENDING': 'Chờ gửi',
  'SENT': 'Đã gửi',
  'FAILED': 'Lỗi',
  'CANCELLED': 'Đã hủy',
};

/// Thông báo đã gửi và trạng thái giao, chỉ đọc (GET /api/v1/admin/notification-deliveries).
///
/// Máy chủ không trả về người nhận trong dòng này, nên màn hình không hiển thị người nhận.
class AdminNotificationDeliveryPage extends ConsumerStatefulWidget {
  const AdminNotificationDeliveryPage({super.key});

  @override
  ConsumerState<AdminNotificationDeliveryPage> createState() => _AdminNotificationDeliveryPageState();
}

class _AdminNotificationDeliveryPageState extends ConsumerState<AdminNotificationDeliveryPage> {
  String _status = '';

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
      final data = await ref.read(employeeRepositoryProvider).getNotificationDeliveries(
            status: _status,
            page: page,
          );
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
        _error = 'Không tải được thông báo đã gửi.';
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _selectStatus(String status) {
    if (status == _status) return;
    setState(() => _status = status);
    _fetch(0, replace: true);
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RouteNames.adminHome);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Thông báo đã gửi'),
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
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                for (final entry in _statusFilters.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(entry.value),
                      selected: _status == entry.key,
                      onSelected: _loading ? null : (_) => _selectStatus(entry.key),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
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
      return const Center(child: Text('Không có thông báo phù hợp.'));
    }

    final canLoadMore = _page + 1 < _totalPages;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Hiển thị ${_rows.length} / $_totalElements thông báo',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
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
    final title = _s(row['title']);
    final message = _s(row['message']);
    final read = _s(row['readAt']).isNotEmpty;
    final status = _s(row['deliveryStatus']);
    return Card(
      color: AppColors.surface,
      child: ListTile(
        onTap: () => _showDetail(row),
        title: Text(
          title.isEmpty ? '(Không có tiêu đề)' : title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: Text(
          '${_s(row['type']).isEmpty ? 'Không rõ loại' : _s(row['type'])}'
          ' · ${_formatWhen(row['createdAt'])}'
          '${message.isEmpty ? '' : '\n$message'}',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _statusChip(status),
            const SizedBox(height: 4),
            Text(
              read ? 'Đã đọc' : 'Chưa đọc',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = switch (status) {
      'SENT' => const Color(0xFF25804B),
      'FAILED' => AppColors.error,
      'PENDING' => const Color(0xFFB96D17),
      _ => AppColors.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _statusFilters[status] ?? (status.isEmpty ? 'Không rõ' : status),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  void _showDetail(Map<String, dynamic> row) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _s(row['title']).isEmpty ? '(Không có tiêu đề)' : _s(row['title']),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 12),
              _line('Nội dung', _orDash(row['message'])),
              _line('Loại thông báo', _orDash(row['type'])),
              _line('Trạng thái giao', _statusFilters[_s(row['deliveryStatus'])] ?? _orDash(row['deliveryStatus'])),
              _line('Đối tượng liên quan', _relatedLabel(row)),
              _line('Thời gian tạo', _formatWhen(row['createdAt'])),
              _line('Thời gian đọc', _s(row['readAt']).isEmpty ? 'Chưa đọc' : _formatWhen(row['readAt'])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 2),
          SelectableText(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ---------- Tiện ích ----------

String _s(Object? value) => value?.toString().trim() ?? '';

String _orDash(Object? value) {
  final text = _s(value);
  return text.isEmpty ? '—' : text;
}

String _relatedLabel(Map<String, dynamic> row) {
  final entity = _s(row['relatedEntityType']);
  final id = _s(row['relatedEntityId']);
  if (entity.isEmpty) return '—';
  return id.isEmpty ? entity : '$entity #$id';
}

/// dd/MM/yyyy HH:mm theo giờ máy chủ (+07:00).
String _formatWhen(Object? value) {
  final date = formatDate(value, fallback: '');
  if (date.isEmpty) return '—';
  return '$date ${formatTimeOfDay(value, fallback: '')}'.trim();
}
