import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/repositories/employee_providers.dart';

class EmployeeAttendanceHistoryPage extends ConsumerStatefulWidget {
  const EmployeeAttendanceHistoryPage({super.key});

  @override
  ConsumerState<EmployeeAttendanceHistoryPage> createState() => _EmployeeAttendanceHistoryPageState();
}

class _EmployeeAttendanceHistoryPageState extends ConsumerState<EmployeeAttendanceHistoryPage> {
  late Future<List<Map<String, dynamic>>> _future;
  late Future<List<Map<String, dynamic>>> _explanationsFuture;
  late Future<List<Map<String, dynamic>>> _adjustmentsFuture;
  late Future<List<Map<String, dynamic>>> _overtimeFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final repository = ref.read(employeeRepositoryProvider);
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 30));
    _future = repository.getMyAttendance(
      from: '${from.year.toString().padLeft(4, '0')}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}',
      to: '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
    );
    _explanationsFuture = repository.getMyExplanations();
    _adjustmentsFuture = repository.getMyAdjustments();
    _overtimeFuture = repository.getMyOvertimeRequests();
  }

  String _date(dynamic value) {
    if (value == null) return '—';
    final parsed = DateTime.tryParse(value.toString())?.toLocal();
    if (parsed == null) return value.toString();
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }

  String _time(dynamic value) => value == null ? '—' : formatClockVn(value, fallback: '—');

  String _status(String value) => switch (value) {
    'PRESENT' => 'Đủ công',
    'LATE' => 'Đi muộn',
    'EARLY_LEAVE' => 'Về sớm',
    'ABSENT' => 'Vắng mặt',
    'IN_PROGRESS' => 'Đang làm',
    'EXPLANATION_PENDING' => 'Chờ duyệt giải trình',
    'PENDING' || 'PENDING_MANAGER' => 'Chờ quản lý duyệt',
    'PENDING_HR' => 'Chờ HR duyệt',
    'APPROVED' => 'Đã duyệt',
    'REJECTED' => 'Từ chối',
    _ => value.isEmpty ? 'Không rõ' : value,
  };

  Future<void> _showExplanation(Map<String, dynamic> row) async {
    final reason = TextEditingController();
    var code = 'MISSED_CHECK_IN';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        title: const Text('Gửi giải trình chấm công'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            value: code,
            decoration: const InputDecoration(labelText: 'Lý do'),
            items: const [
              DropdownMenuItem(value: 'MISSED_CHECK_IN', child: Text('Quên check-in')),
              DropdownMenuItem(value: 'MISSED_CHECK_OUT', child: Text('Quên check-out')),
              DropdownMenuItem(value: 'GPS_UNAVAILABLE', child: Text('Không có GPS')),
              DropdownMenuItem(value: 'DEVICE_ISSUE', child: Text('Lỗi thiết bị')),
              DropdownMenuItem(value: 'CAMERA_ISSUE', child: Text('Lỗi camera')),
              DropdownMenuItem(value: 'BUSINESS_TRIP', child: Text('Đi công tác')),
              DropdownMenuItem(value: 'OTHER', child: Text('Khác')),
            ],
            onChanged: (v) { if (v != null) setDialogState(() => code = v); },
          ),
          const SizedBox(height: 12),
          TextField(controller: reason, maxLines: 3, maxLength: 1000, decoration: const InputDecoration(labelText: 'Mô tả lý do', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Gửi')),
        ],
      )),
    );
    if (accepted != true) return;
    if (reason.text.trim().isEmpty) {
      _message('Vui lòng nhập mô tả lý do.');
      return;
    }
    try {
      final attendanceId = (row['attendanceId'] as num?)?.toInt();
      final scheduleId = (row['shiftAssignmentId'] as num?)?.toInt();
      await ref.read(employeeRepositoryProvider).createExplanation(
        reasonCode: code,
        reason: reason.text.trim(),
        scheduleId: scheduleId,
        attendanceId: attendanceId,
      );
      _message('Đã gửi giải trình.');
      setState(_reload);
    } catch (e) {
      _message(_error(e));
    }
  }

  Future<void> _showAdjustment(Map<String, dynamic> row) async {
    final reason = TextEditingController();
    final checkIn = TextEditingController();
    final checkOut = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yêu cầu điều chỉnh công'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Nhập giờ đề xuất theo ISO 8601, ví dụ: 2026-11-01T08:00:00+07:00. Ít nhất một giờ phải được nhập.'),
          const SizedBox(height: 12),
          TextField(controller: checkIn, decoration: const InputDecoration(labelText: 'Giờ check-in đề xuất', hintText: '2026-11-01T08:00:00+07:00')),
          const SizedBox(height: 8),
          TextField(controller: checkOut, decoration: const InputDecoration(labelText: 'Giờ check-out đề xuất', hintText: '2026-11-01T17:00:00+07:00')),
          const SizedBox(height: 8),
          TextField(controller: reason, maxLines: 2, decoration: const InputDecoration(labelText: 'Lý do', border: OutlineInputBorder())),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Gửi yêu cầu')),
        ],
      ),
    );
    if (accepted != true) return;
    final attendanceId = (row['attendanceId'] as num?)?.toInt();
    if (attendanceId == null || reason.text.trim().isEmpty ||
        (checkIn.text.trim().isEmpty && checkOut.text.trim().isEmpty)) {
      _message('Cần bản ghi công, lý do và ít nhất một giờ đề xuất.');
      return;
    }
    try {
      await ref.read(employeeRepositoryProvider).createAdjustment(
        attendanceId: attendanceId,
        reasonCode: 'TIME_CORRECTION',
        reason: reason.text.trim(),
        requestedCheckInAt: checkIn.text.trim().isEmpty ? null : checkIn.text.trim(),
        requestedCheckOutAt: checkOut.text.trim().isEmpty ? null : checkOut.text.trim(),
      );
      _message('Đã gửi yêu cầu điều chỉnh công.');
      setState(_reload);
    } catch (e) {
      _message(_error(e));
    }
  }

  /// Đề nghị tăng ca trên một bản ghi. Giờ nhập là giờ Việt Nam (UTC+7), gửi kèm offset +07:00.
  Future<void> _showOvertime(Map<String, dynamic> row) async {
    final attendanceId = (row['attendanceId'] as num?)?.toInt();
    if (attendanceId == null) {
      _message('Bản ghi chấm công không hợp lệ.');
      return;
    }
    final workDate = DateTime.tryParse(row['workDate']?.toString() ?? '') ?? DateTime.now();
    var date = DateTime(workDate.year, workDate.month, workDate.day);
    TimeOfDay? start;
    TimeOfDay? end;
    final reason = TextEditingController();

    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        String fmt(TimeOfDay? t) => t == null ? 'Chọn giờ' : _hm(t.hour, t.minute);
        return AlertDialog(
          title: const Text('Đề nghị tăng ca'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Giờ nhập theo giờ Việt Nam (UTC+7). Thời gian tăng ca phải nằm sau giờ kết thúc ca và không quá giới hạn của cửa hàng.'),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setDialogState(() => date = picked);
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text('Ngày: ${_dmyOf(date)}'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: start ?? const TimeOfDay(hour: 18, minute: 0),
                    );
                    if (picked != null) setDialogState(() => start = picked);
                  },
                  icon: const Icon(Icons.schedule),
                  label: Text('Bắt đầu: ${fmt(start)}'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: end ?? const TimeOfDay(hour: 20, minute: 0),
                    );
                    if (picked != null) setDialogState(() => end = picked);
                  },
                  icon: const Icon(Icons.schedule),
                  label: Text('Kết thúc: ${fmt(end)}'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reason,
                  maxLines: 2,
                  maxLength: 500,
                  decoration: const InputDecoration(labelText: 'Lý do', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Gửi')),
          ],
        );
      }),
    );
    if (accepted != true) return;

    final from = start;
    final to = end;
    if (from == null || to == null || reason.text.trim().isEmpty) {
      _message('Cần giờ bắt đầu, giờ kết thúc và lý do.');
      return;
    }
    if (to.hour * 60 + to.minute <= from.hour * 60 + from.minute) {
      _message('Giờ kết thúc phải sau giờ bắt đầu. Tăng ca qua nửa đêm chưa hỗ trợ.');
      return;
    }
    try {
      await ref.read(employeeRepositoryProvider).createOvertimeRequest(
        attendanceId: attendanceId,
        requestedStartAt: _vnIso(date, from),
        requestedEndAt: _vnIso(date, to),
        reason: reason.text.trim(),
      );
      _message('Đã gửi đề nghị tăng ca.');
      setState(_reload);
    } catch (e) {
      _message(_error(e));
    }
  }

  String _error(Object error) => error is ApiException ? error.message : 'Có lỗi xảy ra. Vui lòng thử lại.';
  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử chấm công')),
      body: RefreshIndicator(
        onRefresh: () async => setState(_reload),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('30 ngày gần nhất', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
                if (snapshot.hasError) return _errorCard(_error(snapshot.error!), _reload);
                final rows = snapshot.data ?? [];
                if (rows.isEmpty) return const _EmptyCard(message: 'Chưa có bản ghi chấm công trong khoảng thời gian này.');
                return Column(children: rows.map((row) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(_date(row['workDate']), style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
                        Chip(label: Text(_status((row['attendanceStatus'] ?? '').toString()))),
                      ]),
                      const SizedBox(height: 4),
                      Text('Check-in: ${_time(row['checkInAt'])}     Check-out: ${_time(row['checkOutAt'])}'),
                      Text('Đi muộn: ${row['lateMinutes'] ?? 0} phút · Về sớm: ${row['earlyLeaveMinutes'] ?? 0} phút'),
                      if (row['payrollStatus'] == 'LOCKED') const Text('Kỳ công đã khóa', style: TextStyle(color: Colors.red)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, children: [
                        OutlinedButton.icon(onPressed: () => _showExplanation(row), icon: const Icon(Icons.edit_note), label: const Text('Giải trình')),
                        if (row['payrollStatus'] != 'LOCKED')
                          OutlinedButton.icon(onPressed: () => _showAdjustment(row), icon: const Icon(Icons.tune), label: const Text('Điều chỉnh công')),
                        if (row['payrollStatus'] != 'LOCKED')
                          OutlinedButton.icon(onPressed: () => _showOvertime(row), icon: const Icon(Icons.more_time), label: const Text('Tăng ca')),
                      ]),
                    ]),
                  ),
                )).toList());
              },
            ),
            const SizedBox(height: 22),
            Text('Đơn giải trình', style: Theme.of(context).textTheme.titleMedium),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _explanationsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
                if (snapshot.hasError) return _errorCard(_error(snapshot.error!), _reload);
                final rows = snapshot.data ?? [];
                if (rows.isEmpty) return const _EmptyCard(message: 'Chưa gửi đơn giải trình.');
                return Column(children: rows.map((row) => _RequestCard(
                  title: (row['requestType'] ?? 'Giải trình').toString(),
                  status: _status((row['status'] ?? '').toString()),
                  detail: (row['reason'] ?? '').toString(),
                  date: _date(row['submittedAt']),
                )).toList());
              },
            ),
            const SizedBox(height: 18),
            Text('Đơn điều chỉnh công', style: Theme.of(context).textTheme.titleMedium),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _adjustmentsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
                if (snapshot.hasError) return _errorCard(_error(snapshot.error!), _reload);
                final rows = snapshot.data ?? [];
                if (rows.isEmpty) return const _EmptyCard(message: 'Chưa gửi đơn điều chỉnh công.');
                return Column(children: rows.map((row) => _RequestCard(
                  title: '${row['fieldName'] ?? 'Điều chỉnh'} · #${row['attendanceId'] ?? ''}',
                  status: _status((row['status'] ?? '').toString()),
                  detail: (row['reason'] ?? '').toString(),
                  date: _date(row['createdAt']),
                )).toList());
              },
            ),
            const SizedBox(height: 18),
            Text('Đề nghị tăng ca', style: Theme.of(context).textTheme.titleMedium),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _overtimeFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
                if (snapshot.hasError) return _errorCard(_error(snapshot.error!), _reload);
                final rows = snapshot.data ?? [];
                if (rows.isEmpty) return const _EmptyCard(message: 'Chưa gửi đề nghị tăng ca.');
                return Column(children: rows.map((row) {
                  final note = (row['reviewNote'] ?? '').toString();
                  return _RequestCard(
                    title: 'Tăng ca ${_vnHm(row['requestedStartAt'])} – ${_vnHm(row['requestedEndAt'])}',
                    status: _status((row['status'] ?? '').toString()),
                    detail: [(row['reason'] ?? '').toString(), if (note.isNotEmpty) 'Ghi chú duyệt: $note'].join('\n'),
                    date: _vnDmy(row['requestedStartAt']),
                  );
                }).toList());
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorCard(String message, VoidCallback retry) => Card(child: ListTile(
    leading: const Icon(Icons.error_outline, color: Colors.red),
    title: Text(message),
    trailing: IconButton(onPressed: retry, icon: const Icon(Icons.refresh)),
  ));
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.title, required this.status, required this.detail, required this.date});
  final String title;
  final String status;
  final String detail;
  final String date;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 8),
    child: ListTile(
      title: Text(title),
      subtitle: Text('$date · $detail', maxLines: 3, overflow: TextOverflow.ellipsis),
      trailing: Text(status, style: Theme.of(context).textTheme.labelSmall),
    ),
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(message)));
}

// ---------- Múi giờ Việt Nam (UTC+7, không có giờ mùa hè) ----------

const _vnOffset = Duration(hours: 7);

String _two(int value) => value.toString().padLeft(2, '0');

String _hm(int hour, int minute) => '${_two(hour)}:${_two(minute)}';

String _dmyOf(DateTime date) => '${_two(date.day)}/${_two(date.month)}/${date.year}';

/// Thời điểm máy chủ trả về, đổi sang giờ Việt Nam bất kể múi giờ của máy.
DateTime? _vnClock(Object? value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  return parsed?.toUtc().add(_vnOffset);
}

String _vnHm(Object? value) {
  final clock = _vnClock(value);
  return clock == null ? '—' : _hm(clock.hour, clock.minute);
}

String _vnDmy(Object? value) {
  final clock = _vnClock(value);
  return clock == null ? '—' : _dmyOf(clock);
}

/// yyyy-MM-ddTHH:mm:00+07:00 từ ngày và giờ nhập theo giờ Việt Nam.
String _vnIso(DateTime date, TimeOfDay time) =>
    '${date.year.toString().padLeft(4, '0')}-${_two(date.month)}-${_two(date.day)}'
    'T${_two(time.hour)}:${_two(time.minute)}:00+07:00';
