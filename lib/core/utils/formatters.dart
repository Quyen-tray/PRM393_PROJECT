/// Định dạng dữ liệu nhận từ API để hiển thị.
///
/// Backend trả thời gian dạng ISO-8601 (ví dụ `2026-10-13T08:00:00+07:00`).
/// Hàm dưới đây chỉ lấy phần ngày để tránh phụ thuộc múi giờ của thiết bị.
String formatDate(Object? value, {String fallback = '—'}) {
  final text = value?.toString() ?? '';
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(text);
  if (match == null) return fallback;
  return '${match.group(3)}/${match.group(2)}/${match.group(1)}';
}

/// Hiển thị điểm số: bỏ phần thập phân khi là số nguyên.
String formatScore(Object? value, {String fallback = '—'}) {
  if (value == null) return fallback;
  if (value is num) {
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
  }
  final parsed = num.tryParse(value.toString());
  return parsed == null ? fallback : formatScore(parsed);
}

/// Nhãn tiếng Việt cho trạng thái đào tạo (TrainingStatus trong backend).
String trainingStatusLabel(String? status) => switch (status) {
  'PASSED' => 'Đã đạt',
  'PENDING_REVIEW' => 'Chờ quản lý duyệt',
  'IN_PROGRESS' => 'Đang học',
  'NOT_STARTED' => 'Chưa bắt đầu',
  'FAILED' => 'Chưa đạt',
  'EXPIRED' => 'Hết hạn',
  _ => 'Chưa ghi danh',
};

/// Mã khóa học dạng số nguyên, -1 nếu thiếu.
int courseIdOf(Map<String, dynamic> course) =>
    (course['courseId'] as num?)?.toInt() ?? -1;

/// Nhãn tiếng Việt cho trạng thái làm việc của nhân viên (EmploymentStatus).
String employmentStatusLabel(String? status) => switch (status) {
  'ACTIVE' => 'Đang làm việc',
  'ON_LEAVE' => 'Nghỉ phép',
  'SUSPENDED' => 'Tạm ngưng',
  'RESIGNED' => 'Đã nghỉ việc',
  _ => 'Chưa rõ trạng thái',
};

/// Nhãn tiếng Việt cho loại hợp đồng (EmploymentType).
String employmentTypeLabel(String? type) => switch (type) {
  'FULL_TIME' => 'Toàn thời gian',
  'PART_TIME' => 'Bán thời gian',
  'TEMPORARY' => 'Thời vụ',
  'PROBATION' => 'Thử việc',
  _ => 'Chưa cập nhật',
};

/// Nhãn tiếng Việt cho mức độ hoàn thiện hồ sơ nhân viên.
String employeeProfileStatusLabel(String? status) => switch (status) {
  'COMPLETE' => 'Đã hoàn thiện',
  'INCOMPLETE' => 'Cần bổ sung hồ sơ',
  'PENDING_REVIEW' => 'Đang chờ duyệt',
  _ => 'Chưa xác định',
};

/// Nhãn tiếng Việt cho điều kiện được xếp ca.
String shiftEligibilityLabel(String? eligibility) => switch (eligibility) {
  'ELIGIBLE' => 'Đủ điều kiện nhận ca',
  'INELIGIBLE' => 'Chưa đủ điều kiện nhận ca',
  'BLOCKED' => 'Đang bị tạm khóa nhận ca',
  _ => 'Chưa xác định',
};

/// Giờ:phút từ chuỗi ISO-8601, giữ nguyên múi giờ của máy chủ (`2026-10-13T08:00:00+07:00` → `08:00`).
String formatTimeOfDay(Object? value, {String fallback = '--:--'}) {
  final match = RegExp(r'T(\d{2}):(\d{2})').firstMatch(value?.toString() ?? '');
  if (match == null) return fallback;
  return '${match.group(1)}:${match.group(2)}';
}

/// Nhãn tiếng Việt cho trạng thái chấm công trong ngày (AttendanceStatus trong backend).
String attendanceStatusLabel(String? status) {
  if (status == null || status.isEmpty) return 'Chưa check-in';
  if (status.startsWith('PENDING')) return 'Đang chờ duyệt';
  return switch (status) {
    'CHECKED_IN' => 'Đã check-in',
    'CHECKED_OUT' => 'Đã check-out',
    'LATE' => 'Đi muộn',
    'EARLY_LEAVE' => 'Về sớm',
    'MISSING' => 'Thiếu chấm công',
    _ => status,
  };
}

/// Giờ:phút theo giờ Việt Nam (UTC+7) từ chuỗi ISO-8601, không phụ thuộc múi giờ của máy.
///
/// Không dùng `.hour` trực tiếp trên kết quả `DateTime.tryParse`: khi chuỗi có offset
/// (ví dụ `+07:00`), Dart trả về thời điểm UTC nên giờ sẽ lệch 7 tiếng.
String formatClockVn(Object? value, {String fallback = '--:--'}) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) return fallback;
  final vn = parsed.toUtc().add(const Duration(hours: 7));
  return '${vn.hour.toString().padLeft(2, '0')}:${vn.minute.toString().padLeft(2, '0')}';
}
