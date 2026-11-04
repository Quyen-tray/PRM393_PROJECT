import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/repositories/employee_providers.dart';

class HrAttendanceAdjustmentsPage extends ConsumerStatefulWidget {
  const HrAttendanceAdjustmentsPage({super.key});

  @override
  ConsumerState<HrAttendanceAdjustmentsPage> createState() =>
      _HrAttendanceAdjustmentsPageState();
}

class _HrAttendanceAdjustmentsPageState
    extends ConsumerState<HrAttendanceAdjustmentsPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  int? _actingId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await ref
          .read(employeeRepositoryProvider)
          .getManagerAttendanceRequests(adjustment: true, status: 'PENDING_HR');
      if (mounted) setState(() => _items = items);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Không tải được yêu cầu chờ HR.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _detail(Map<String, dynamic> item) async {
    final id = item['requestId'] is num
        ? (item['requestId'] as num).toInt()
        : null;
    if (id == null) return;
    try {
      final detail = await ref
          .read(employeeRepositoryProvider)
          .getAttendanceAdjustmentRequest(id);
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
                'Yêu cầu điều chỉnh #$id',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              for (final entry in detail.entries)
                ListTile(
                  dense: true,
                  title: Text(entry.key),
                  subtitle: SelectableText('${entry.value ?? '—'}'),
                ),
            ],
          ),
        ),
      );
    } catch (error) {
      _message(
        error is ApiException
            ? error.message
            : 'Không tải được chi tiết yêu cầu.',
      );
    }
  }

  Future<void> _review(
    Map<String, dynamic> item, {
    required bool approve,
  }) async {
    final id = item['requestId'] is num
        ? (item['requestId'] as num).toInt()
        : null;
    if (id == null) return;
    final reason = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            approve ? 'Duyệt điều chỉnh công' : 'Từ chối điều chỉnh công',
          ),
          content: TextField(
            controller: reason,
            maxLength: 500,
            maxLines: 3,
            onChanged: (_) => setDialogState(() {}),
            decoration: InputDecoration(
              labelText: approve ? 'Ghi chú (tùy chọn)' : 'Lý do từ chối',
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: !approve && reason.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, reason.text.trim()),
              child: Text(approve ? 'Duyệt' : 'Từ chối'),
            ),
          ],
        ),
      ),
    );
    reason.dispose();
    if (note == null || (!approve && note.isEmpty) || !mounted) return;
    setState(() => _actingId = id);
    try {
      await ref
          .read(employeeRepositoryProvider)
          .reviewHrAttendanceAdjustment(
            requestId: id,
            approve: approve,
            reason: note,
          );
      _message(approve ? 'Đã duyệt yêu cầu.' : 'Đã từ chối yêu cầu.');
      await _load();
    } catch (error) {
      _message(
        error is ApiException ? error.message : 'Không xử lý được yêu cầu.',
      );
    } finally {
      if (mounted) setState(() => _actingId = null);
    }
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('Điều chỉnh công chờ HR'),
      leading: IconButton(
        onPressed: () => context.go(RouteNames.hrHome),
        icon: const Icon(Icons.arrow_back),
      ),
      actions: [
        IconButton(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: _loading && _items.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : _error != null && _items.isEmpty
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!),
                const SizedBox(height: 12),
                FilledButton(onPressed: _load, child: const Text('Thử lại')),
              ],
            ),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: _items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 180),
                      Center(child: Text('Không có yêu cầu chờ HR.')),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final id = item['requestId'] is num
                          ? (item['requestId'] as num).toInt()
                          : -1;
                      final busy = _actingId == id;
                      return Card(
                        color: AppColors.surface,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  '${item['employeeName'] ?? 'Nhân viên ${item['employeeId'] ?? '—'}'}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  'Chấm công #${item['attendanceId'] ?? '—'} · ${item['fieldName'] ?? 'Điều chỉnh giờ công'}\n${item['reason'] ?? ''}',
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _detail(item),
                              ),
                              Wrap(
                                spacing: 8,
                                children: [
                                  OutlinedButton(
                                    onPressed: busy
                                        ? null
                                        : () => _detail(item),
                                    child: const Text('Chi tiết'),
                                  ),
                                  OutlinedButton(
                                    onPressed: busy
                                        ? null
                                        : () => _review(item, approve: false),
                                    child: const Text('Từ chối'),
                                  ),
                                  FilledButton(
                                    onPressed: busy
                                        ? null
                                        : () => _review(item, approve: true),
                                    child: busy
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text('Duyệt'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
  );
}
