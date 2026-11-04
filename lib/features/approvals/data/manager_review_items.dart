import '../../../core/utils/formatters.dart';
import '../../../data/mock/demo_data.dart' show DemoManagerReviewStatus;
import '../../../data/repositories/employee_repository.dart';

/// Loại mục cần quản lý duyệt, gom từ nhiều API về cùng một dạng hiển thị.
enum ManagerReviewKind { explanation, adjustment, overtime, checklist, device }

/// Một mục trong hub Duyệt. `id` là mã của đúng loại mục đó (requestId, taskId, deviceId).
class ManagerReviewItem {
  const ManagerReviewItem({
    required this.kind,
    required this.id,
    required this.status,
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.evidence,
    this.rejectionReason,
  });

  final ManagerReviewKind kind;
  final int id;
  final DemoManagerReviewStatus status;
  final String title;
  final String subtitle;
  final String detail;
  final String evidence;
  final String? rejectionReason;

  bool get isPending => status == DemoManagerReviewStatus.pendingManager;
}

/// Ba nhóm hiển thị trong hub: chờ duyệt, đã duyệt, từ chối.
class ManagerReviewBuckets {
  const ManagerReviewBuckets({
    required this.pending,
    required this.approved,
    required this.rejected,
  });

  final List<ManagerReviewItem> pending;
  final List<ManagerReviewItem> approved;
  final List<ManagerReviewItem> rejected;

  List<ManagerReviewItem> whereKind(ManagerReviewKind kind) => [
    for (final item in [...pending, ...approved, ...rejected])
      if (item.kind == kind) item,
  ];
}

/// Tải các mục duyệt của quản lý, theo ba nhóm trạng thái. Chỉ gọi API của các loại trong
/// [kinds] (mặc định là tất cả). Các lệnh gọi chạy song song.
/// Thiết bị chỉ có danh sách chờ duyệt: backend chưa có lọc thiết bị theo trạng thái cho cửa hàng.
Future<ManagerReviewBuckets> loadManagerReviewBuckets(
  EmployeeRepository repo, {
  Set<ManagerReviewKind>? kinds,
}) async {
  final want = kinds ?? ManagerReviewKind.values.toSet();
  bool wants(ManagerReviewKind kind) => want.contains(kind);
  Future<List<Map<String, dynamic>>> none() =>
      Future.value(const <Map<String, dynamic>>[]);

  final results = await Future.wait<List<Map<String, dynamic>>>([
    wants(ManagerReviewKind.explanation)
        ? repo.getManagerAttendanceRequests(
            adjustment: false,
            status: 'PENDING_MANAGER',
          )
        : none(), // 0
    wants(ManagerReviewKind.adjustment)
        ? repo.getManagerAttendanceRequests(
            adjustment: true,
            status: 'PENDING_MANAGER',
          )
        : none(), // 1
    wants(ManagerReviewKind.overtime)
        ? repo.getManagerOvertimeRequests(status: 'PENDING')
        : none(), // 2
    wants(ManagerReviewKind.checklist)
        ? repo.getPendingChecklistReviews()
        : none(), // 3
    wants(ManagerReviewKind.device)
        ? repo.getPendingAttendanceDevices()
        : none(), // 4
    wants(ManagerReviewKind.explanation)
        ? repo.getManagerAttendanceRequests(
            adjustment: false,
            status: 'APPROVED',
          )
        : none(), // 5
    wants(ManagerReviewKind.adjustment)
        ? repo.getManagerAttendanceRequests(
            adjustment: true,
            status: 'PENDING_HR',
          )
        : none(), // 6
    wants(ManagerReviewKind.adjustment)
        ? repo.getManagerAttendanceRequests(
            adjustment: true,
            status: 'APPROVED',
          )
        : none(), // 7
    wants(ManagerReviewKind.overtime)
        ? repo.getManagerOvertimeRequests(status: 'APPROVED')
        : none(), // 8
    wants(ManagerReviewKind.checklist)
        ? repo.getManagerChecklistRuns(status: 'APPROVED')
        : none(), // 9
    wants(ManagerReviewKind.explanation)
        ? repo.getManagerAttendanceRequests(
            adjustment: false,
            status: 'REJECTED',
          )
        : none(), // 10
    wants(ManagerReviewKind.adjustment)
        ? repo.getManagerAttendanceRequests(
            adjustment: true,
            status: 'REJECTED',
          )
        : none(), // 11
    wants(ManagerReviewKind.overtime)
        ? repo.getManagerOvertimeRequests(status: 'REJECTED')
        : none(), // 12
    wants(ManagerReviewKind.checklist)
        ? repo.getManagerChecklistRuns(status: 'REJECTED')
        : none(), // 13
  ]);

  const pendingStatus = DemoManagerReviewStatus.pendingManager;
  return ManagerReviewBuckets(
    pending: [
      for (final row in results[0]) _explanation(row, pendingStatus),
      for (final row in results[1]) _adjustment(row, pendingStatus),
      for (final row in results[2]) _overtime(row, pendingStatus),
      for (final row in results[3]) _checklist(row, pendingStatus),
      for (final row in results[4]) _device(row),
    ],
    approved: [
      for (final row in results[5])
        _explanation(row, DemoManagerReviewStatus.approved),
      for (final row in results[6])
        _adjustment(row, DemoManagerReviewStatus.pendingHr),
      for (final row in results[7])
        _adjustment(row, DemoManagerReviewStatus.approved),
      for (final row in results[8])
        _overtime(row, DemoManagerReviewStatus.approved),
      for (final row in results[9])
        _checklist(row, DemoManagerReviewStatus.approved),
    ],
    rejected: [
      for (final row in results[10])
        _explanation(row, DemoManagerReviewStatus.rejected),
      for (final row in results[11])
        _adjustment(row, DemoManagerReviewStatus.rejected),
      for (final row in results[12])
        _overtime(row, DemoManagerReviewStatus.rejected),
      for (final row in results[13])
        _checklist(row, DemoManagerReviewStatus.rejected),
    ],
  );
}

/// Duyệt một mục. Ghi chú không bắt buộc.
Future<void> approveManagerReviewItem(
  EmployeeRepository repo,
  ManagerReviewItem item, {
  String? note,
}) async {
  switch (item.kind) {
    case ManagerReviewKind.explanation:
      await repo.reviewManagerAttendanceRequest(
        requestId: item.id,
        adjustment: false,
        approve: true,
        note: note,
      );
    case ManagerReviewKind.adjustment:
      await repo.reviewManagerAttendanceRequest(
        requestId: item.id,
        adjustment: true,
        approve: true,
        note: note,
      );
    case ManagerReviewKind.overtime:
      await repo.approveOvertimeRequest(item.id, note: note);
    case ManagerReviewKind.checklist:
      await repo.approveChecklistTask(item.id, note: note);
    case ManagerReviewKind.device:
      await repo.approveAttendanceDevice(item.id);
  }
}

/// Từ chối một mục. Lý do bắt buộc, vì backend yêu cầu cho mọi loại.
Future<void> rejectManagerReviewItem(
  EmployeeRepository repo,
  ManagerReviewItem item, {
  required String reason,
}) async {
  switch (item.kind) {
    case ManagerReviewKind.explanation:
      await repo.reviewManagerAttendanceRequest(
        requestId: item.id,
        adjustment: false,
        approve: false,
        note: reason,
      );
    case ManagerReviewKind.adjustment:
      await repo.reviewManagerAttendanceRequest(
        requestId: item.id,
        adjustment: true,
        approve: false,
        note: reason,
      );
    case ManagerReviewKind.overtime:
      await repo.rejectOvertimeRequest(item.id, reason: reason);
    case ManagerReviewKind.checklist:
      await repo.rejectChecklistTask(item.id, reason: reason);
    case ManagerReviewKind.device:
      await repo.rejectAttendanceDevice(deviceId: item.id, reason: reason);
  }
}

// ---- Chuyển từng loại dữ liệu API về ManagerReviewItem ----

String _lines(List<String?> lines) =>
    lines.where((line) => line != null && line.isNotEmpty).join('\n');

int _intOf(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

String? _textOf(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

ManagerReviewItem _explanation(
  Map<String, dynamic> row,
  DemoManagerReviewStatus status,
) {
  final checkIn = formatTimeOfDay(row['requestedCheckInAt'], fallback: '');
  final checkOut = formatTimeOfDay(row['requestedCheckOutAt'], fallback: '');
  return ManagerReviewItem(
    kind: ManagerReviewKind.explanation,
    id: _intOf(row['requestId']),
    status: status,
    title: _textOf(row['requestType']) ?? 'Giải trình chấm công',
    subtitle: 'Mã nhân viên ${row['employeeId'] ?? '—'}',
    detail: _lines([
      _textOf(row['reason']) == null ? null : 'Lý do: ${row['reason']}',
      checkIn.isEmpty && checkOut.isEmpty
          ? null
          : 'Giờ đề xuất: vào ${checkIn.isEmpty ? '—' : checkIn} · ra ${checkOut.isEmpty ? '—' : checkOut}',
      'Gửi lúc: ${formatDate(row['submittedAt'])}',
    ]),
    evidence: 'Chấm công #${row['attendanceId'] ?? '—'}',
    rejectionReason: status == DemoManagerReviewStatus.rejected
        ? _textOf(row['reviewNote'])
        : null,
  );
}

ManagerReviewItem _adjustment(
  Map<String, dynamic> row,
  DemoManagerReviewStatus status,
) {
  return ManagerReviewItem(
    kind: ManagerReviewKind.adjustment,
    id: _intOf(row['requestId']),
    status: status,
    title: 'Điều chỉnh ${row['fieldName'] ?? 'giờ công'}',
    subtitle: 'Chấm công #${row['attendanceId'] ?? '—'}',
    detail: _lines([
      '${row['oldValue'] ?? '—'} → ${row['newValue'] ?? '—'}',
      _textOf(row['reason']) == null ? null : 'Lý do: ${row['reason']}',
      'Gửi lúc: ${formatDate(row['createdAt'])}',
    ]),
    evidence: 'Yêu cầu #${row['requestId'] ?? '—'}',
  );
}

ManagerReviewItem _overtime(
  Map<String, dynamic> row,
  DemoManagerReviewStatus status,
) {
  final start = formatTimeOfDay(row['requestedStartAt'], fallback: '');
  final end = formatTimeOfDay(row['requestedEndAt'], fallback: '');
  return ManagerReviewItem(
    kind: ManagerReviewKind.overtime,
    id: _intOf(row['requestId']),
    status: status,
    title: 'Đề nghị tăng ca',
    subtitle: 'Mã nhân viên ${row['employeeId'] ?? '—'}',
    detail: _lines([
      formatDate(row['requestedStartAt']) == '—'
          ? null
          : 'Ngày ${formatDate(row['requestedStartAt'])}: '
                '${start.isEmpty ? '—' : start} → ${end.isEmpty ? '—' : end}',
      _textOf(row['reason']) == null ? null : 'Lý do: ${row['reason']}',
    ]),
    evidence: 'Yêu cầu #${row['requestId'] ?? '—'}',
    rejectionReason: status == DemoManagerReviewStatus.rejected
        ? _textOf(row['reviewNote'])
        : null,
  );
}

ManagerReviewItem _checklist(
  Map<String, dynamic> row,
  DemoManagerReviewStatus status,
) {
  final name = _textOf(row['employeeName']) ?? 'Mã ${row['employeeId'] ?? '—'}';
  return ManagerReviewItem(
    kind: ManagerReviewKind.checklist,
    id: _intOf(row['taskId']),
    status: status,
    title: _textOf(row['checklistName']) ?? 'Checklist',
    subtitle: 'Nhân viên: $name',
    detail: _lines([
      'Hạn: ${formatDate(row['dueAt'])}',
      'Gửi lúc: ${formatDate(row['submittedAt'])}',
    ]),
    evidence: 'Checklist #${row['taskId'] ?? '—'}',
    rejectionReason: status == DemoManagerReviewStatus.rejected
        ? _textOf(row['reviewNote'])
        : null,
  );
}

ManagerReviewItem _device(Map<String, dynamic> row) {
  return ManagerReviewItem(
    kind: ManagerReviewKind.device,
    id: _intOf(row['deviceId']),
    status: DemoManagerReviewStatus.pendingManager,
    title: 'Đăng ký thiết bị: ${_textOf(row['deviceLabel']) ?? 'chưa đặt tên'}',
    subtitle:
        'Nhân viên: ${_textOf(row['employeeName']) ?? 'Mã ${row['employeeId'] ?? '—'}'}',
    detail: _lines([
      'Nền tảng: ${row['platform'] ?? '—'}',
      'Gửi lúc: ${formatDate(row['requestedAt'])}',
    ]),
    evidence: 'Thiết bị #${row['deviceId'] ?? '—'}',
  );
}
