class ApiException implements Exception {
  const ApiException({required this.message, this.statusCode, this.details});

  final String message;
  final int? statusCode;

  /// `error.details` của envelope lỗi. Với VALIDATION_ERROR là {tên trường: thông báo},
  /// ví dụ {"employeeCode": "..."}. Null nếu máy chủ không gửi.
  final Map<String, dynamic>? details;

  @override
  String toString() => message;
}
