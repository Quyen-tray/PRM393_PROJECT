class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.code,
    this.details = const {},
  });

  final String message;
  final int? statusCode;
  final String? code;
  final Map<String, dynamic> details;

  @override
  String toString() => message;
}
