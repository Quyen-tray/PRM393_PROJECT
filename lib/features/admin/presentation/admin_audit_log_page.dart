import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/repositories/employee_providers.dart';

/// Nhật ký hệ thống (audit log), chỉ đọc. Backend không có endpoint sửa hay xóa.
///
/// Lọc theo loại đối tượng (entityType) và mã hành động (actionCode) khớp đúng như backend lưu,
/// ví dụ `Employee` và `EMPLOYEE_UPDATE`. Khoảng ngày lọc theo giờ server.
class AdminAuditLogPage extends ConsumerStatefulWidget {
  const AdminAuditLogPage({super.key});

  @override
  ConsumerState<AdminAuditLogPage> createState() => _AdminAuditLogPageState();
}

class _AdminAuditLogPageState extends ConsumerState<AdminAuditLogPage> {
  final _entityController = TextEditingController();
  final _actionController = TextEditingController();

  DateTime? _from;
  DateTime? _to;

  /// Bộ lọc đang áp dụng. Phân trang dùng bộ này, không đọc lại ô nhập nên không bị lệch khi người dùng gõ thêm.
  String _entityFilter = '';
  String _actionFilter = '';
  DateTime? _fromFilter;
  DateTime? _toFilter;

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
    _applyFilters();
  }

  @override
  void dispose() {
    _entityController.dispose();
    _actionController.dispose();
    super.dispose();
  }

  /// Áp dụng bộ lọc từ các ô nhập và tải lại từ trang đầu.
  void _applyFilters() {
    _entityFilter = _entityController.text.trim();
    _actionFilter = _actionController.text.trim();
    _fromFilter = _from;
    _toFilter = _to;
    _fetch(0, replace: true);
  }

  void _clearFilters() {
    _entityController.clear();
    _actionController.clear();
    setState(() {
      _from = null;
      _to = null;
    });
    _applyFilters();
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
      final data = await ref.read(employeeRepositoryProvider).getAuditLogs(
            entityType: _entityFilter,
            actionCode: _actionFilter,
            from: _fromFilter == null ? null : _isoDate(_fromFilter!),
            to: _toFilter == null ? null : _isoDate(_toFilter!),
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
        _error = 'Không tải được nhật ký hệ thống.';
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _pickDate({required bool from}) async {
    final current = from ? _from : _to;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (from) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
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
        title: const Text('Nhật ký hệ thống'),
        leading: IconButton(
          tooltip: 'Quay lại',
          onPressed: _back,
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _loading ? null : _applyFilters,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          _filterPanel(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _filterPanel() {
    return Material(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          children: [
            TextField(
              controller: _entityController,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _applyFilters(),
              decoration: const InputDecoration(
                labelText: 'Loại đối tượng',
                hintText: 'Ví dụ: Employee',
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _actionController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _applyFilters(),
              decoration: const InputDecoration(
                labelText: 'Mã hành động',
                hintText: 'Ví dụ: EMPLOYEE_UPDATE',
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _dateChip(label: 'Từ ngày', value: _from, onTap: () => _pickDate(from: true),
                    onClear: () => setState(() => _from = null))),
                const SizedBox(width: 8),
                Expanded(child: _dateChip(label: 'Đến ngày', value: _to, onTap: () => _pickDate(from: false),
                    onClear: () => setState(() => _to = null))),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: _loading ? null : _clearFilters, child: const Text('Xóa lọc')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(onPressed: _loading ? null : _applyFilters, child: const Text('Lọc')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateChip({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          suffixIcon: value == null
              ? const Icon(Icons.calendar_today_outlined, size: 18)
              : IconButton(
                  tooltip: 'Bỏ ngày',
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: onClear,
                ),
        ),
        child: Text(value == null ? 'Tất cả' : _displayDate(value)),
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
              FilledButton(onPressed: _applyFilters, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
    }
    if (_rows.isEmpty) {
      return const Center(child: Text('Không có bản ghi nhật ký phù hợp.'));
    }

    final canLoadMore = _page + 1 < _totalPages;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Hiển thị ${_rows.length} / $_totalElements bản ghi',
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
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(),
                        )
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
    final entity = _s(row['entityType']);
    final entityId = _s(row['entityId']);
    final actor = row['actorUserId'];
    return Card(
      color: AppColors.surface,
      child: ListTile(
        onTap: () => _showDetail(row),
        title: Text(
          _s(row['actionCode']).isEmpty ? '—' : _s(row['actionCode']),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: Text(
          '${entity.isEmpty ? 'Không rõ đối tượng' : entity}'
          '${entityId.isEmpty ? '' : ' #$entityId'}'
          ' · ${actor == null ? 'Hệ thống' : 'Người dùng $actor'}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Text(
          _formatWhen(row['createdAt']),
          textAlign: TextAlign.right,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
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
                _s(row['actionCode']).isEmpty ? '—' : _s(row['actionCode']),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 12),
              _detailLine('Thời gian', _formatWhen(row['createdAt'])),
              _detailLine('Đối tượng', _entityLabel(row)),
              _detailLine('Người thực hiện', row['actorUserId'] == null ? 'Hệ thống' : 'Tài khoản #${row['actorUserId']}'),
              _detailLine('Địa chỉ IP', _orDash(row['ipAddress'])),
              _detailLine('Mã tương quan', _orDash(row['correlationId'])),
              const SizedBox(height: 12),
              _jsonBlock('Trước khi thay đổi', row['beforeJson']),
              const SizedBox(height: 12),
              _jsonBlock('Sau khi thay đổi', row['afterJson']),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailLine(String label, String value) {
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

  Widget _jsonBlock(String label, Object? value) {
    final text = _s(value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: SelectableText(
            text.isEmpty ? '—' : text,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ],
    );
  }
}

// ---------- Tiện ích ----------

String _s(Object? value) => value?.toString().trim() ?? '';

String _orDash(Object? value) {
  final text = _s(value);
  return text.isEmpty ? '—' : text;
}

String _entityLabel(Map<String, dynamic> row) {
  final entity = _s(row['entityType']);
  final id = _s(row['entityId']);
  if (entity.isEmpty) return '—';
  return id.isEmpty ? entity : '$entity #$id';
}

/// Ngày giờ hiển thị dạng dd/MM/yyyy HH:mm, giữ múi giờ của máy chủ.
String _formatWhen(Object? value) {
  final date = formatDate(value, fallback: '');
  if (date.isEmpty) return '—';
  return '$date ${formatTimeOfDay(value, fallback: '')}'.trim();
}

/// yyyy-MM-dd cho tham số from/to.
String _isoDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// dd/MM/yyyy để hiển thị.
String _displayDate(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '$d/$m/${date.year}';
}
