import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/repositories/employee_providers.dart';

class ManagerAttendanceRequestsPage extends ConsumerStatefulWidget {
  const ManagerAttendanceRequestsPage({super.key});

  @override
  ConsumerState<ManagerAttendanceRequestsPage> createState() =>
      _ManagerAttendanceRequestsPageState();
}

class _ManagerAttendanceRequestsPageState
    extends ConsumerState<ManagerAttendanceRequestsPage> {
  late Future<List<Map<String, dynamic>>> _explanations;
  late Future<List<Map<String, dynamic>>> _adjustments;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final repository = ref.read(employeeRepositoryProvider);
    _explanations = repository.getManagerPendingExplanations();
    _adjustments = repository.getManagerPendingAdjustments();
  }

  String _error(Object e) =>
      e is ApiException ? e.message : 'Không thể tải yêu cầu chấm công.';
  String _date(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (parsed == null) return '—';
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year} ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _review(
    Map<String, dynamic> row, {
    required bool adjustment,
    required bool approve,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(approve ? 'Xác nhận duyệt' : 'Từ chối yêu cầu'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: approve ? 'Ghi chú (không bắt buộc)' : 'Lý do từ chối',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(approve ? 'Duyệt' : 'Từ chối'),
          ),
        ],
      ),
    );
    final note = controller.text.trim();
    controller.dispose();
    if (!mounted || result == null) return;
    if (!approve && note.isEmpty) {
      _message('Cần nhập lý do từ chối.');
      return;
    }
    final id = (row['requestId'] as num?)?.toInt();
    if (id == null) {
      _message('Yêu cầu không có mã hợp lệ.');
      return;
    }
    try {
      await ref
          .read(employeeRepositoryProvider)
          .reviewManagerAttendanceRequest(
            requestId: id,
            adjustment: adjustment,
            approve: approve,
            note: note,
          );
      if (mounted) {
        setState(_reload);
        _message(approve ? 'Đã duyệt yêu cầu.' : 'Đã từ chối yêu cầu.');
      }
    } catch (e) {
      _message(_error(e));
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Duyệt chấm công'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Giải trình'),
            Tab(text: 'Điều chỉnh công'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(_reload),
        child: TabBarView(
          children: [
            _list(future: _explanations, adjustment: false),
            _list(future: _adjustments, adjustment: true),
          ],
        ),
      ),
    ),
  );

  Widget _list({
    required Future<List<Map<String, dynamic>>> future,
    required bool adjustment,
  }) => FutureBuilder<List<Map<String, dynamic>>>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error(snapshot.error!)),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => setState(_reload),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        );
      }
      final rows = snapshot.data ?? [];
      if (rows.isEmpty) {
        return const Center(child: Text('Không có yêu cầu đang chờ duyệt.'));
      }
      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final row = rows[index];
          final reason = (row['reason'] ?? 'Không có mô tả').toString();
          final title = adjustment
              ? 'Điều chỉnh ${row['fieldName'] ?? 'giờ công'} · #${row['attendanceId'] ?? ''}'
              : (row['requestType'] ?? 'Giải trình').toString();
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(reason),
                  const SizedBox(height: 6),
                  Text(
                    'Gửi lúc: ${_date(row[adjustment ? 'createdAt' : 'submittedAt'])}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (adjustment) ...[
                    Text('Giá trị cũ: ${row['oldValue'] ?? '—'}'),
                    Text('Giá trị đề xuất: ${row['newValue'] ?? '—'}'),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _review(
                            row,
                            adjustment: adjustment,
                            approve: false,
                          ),
                          child: const Text('Từ chối'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _review(
                            row,
                            adjustment: adjustment,
                            approve: true,
                          ),
                          child: const Text('Duyệt'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
