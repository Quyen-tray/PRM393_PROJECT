import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import 'dart:typed_data';
import 'dart:math';

/// Vai trò và quyền hiệu lực của tài khoản đang đăng nhập (GET /api/v1/users/me/permissions).
class CurrentAccess {
  const CurrentAccess({required this.roles, required this.permissions});

  final Set<String> roles;
  final Set<String> permissions;

  /// Danh sách chức vụ và tài khoản chỉ mở cho SYSTEM_ADMIN (backend @PreAuthorize hasRole).
  bool get isSystemAdmin => roles.contains('SYSTEM_ADMIN');

  /// Tạo và sửa hồ sơ nhân viên: EMPLOYEE_MANAGE (quản lý cửa hàng, HR, admin).
  bool get canManageEmployees => permissions.contains('EMPLOYEE_MANAGE');

  /// Đánh giá kỹ năng nhân viên: TRAINING_MANAGE (quản lý cửa hàng, HR).
  bool get canManageTraining => permissions.contains('TRAINING_MANAGE');

  /// Xem kỳ công và sẵn sàng chốt: PAYROLL_VIEW (quản lý cửa hàng, giám đốc vận hành, HR, admin).
  bool get canViewPayroll => permissions.contains('PAYROLL_VIEW');

  /// Tạo kỳ công: PAYROLL_PERIOD_MANAGE.
  bool get canCreatePayroll => permissions.contains('PAYROLL_PERIOD_MANAGE');

  /// Chốt kỳ công (HR): PAYROLL_FINALIZE.
  bool get canFinalizePayroll => permissions.contains('PAYROLL_FINALIZE');

  /// Mở lại kỳ đã chốt: PAYROLL_REOPEN (giám đốc vận hành, admin).
  bool get canReopenPayroll => permissions.contains('PAYROLL_REOPEN');

  /// Quản lý xác nhận và tạo đơn vắng: máy chủ kiểm tra theo vai trò STORE_MANAGER.
  bool get isStoreManager => roles.contains('STORE_MANAGER');

  /// Xem quyết định thưởng/phạt: REWARD_VIEW.
  bool get canViewRewards => permissions.contains('REWARD_VIEW');

  /// Đề xuất thưởng/phạt: REWARD_PROPOSE.
  bool get canProposeRewards => permissions.contains('REWARD_PROPOSE');

  /// Xem xét vi phạm (danh sách và xác nhận/bác bỏ): VIOLATION_REVIEW.
  bool get canReviewViolations => permissions.contains('VIOLATION_REVIEW');

  /// Duyệt giấy tờ nhân viên: DOCUMENT_REVIEW (quản lý cửa hàng hoặc tập quyền HR).
  bool get canReviewDocuments => permissions.contains('DOCUMENT_REVIEW');

  /// Duyệt vi phạm/thưởng-phạt thông thường: REWARD_APPROVE.
  bool get canApproveRewards => permissions.contains('REWARD_APPROVE');

  /// Duyệt mức CRITICAL: REWARD_APPROVE_CRITICAL (Giám đốc vận hành).
  bool get canApproveCritical =>
      permissions.contains('REWARD_APPROVE_CRITICAL');
}

class EmployeeRepository {
  EmployeeRepository(this._api);

  final ApiClient _api;

  Future<List<Map<String, dynamic>>> getEmployees({
    String? q,
    String? status,
    int page = 0,
  }) async {
    final response = await _api.get(
      '/api/v1/employees',
      queryParameters: {
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        if (status != null && status.isNotEmpty) 'status': status,
        'page': page,
        'size': 50,
      },
    );
    final body = response.data;
    final data = body is Map ? body['data'] : null;
    final items = data is Map ? data['items'] : null;
    if (body is! Map || body['success'] != true || items is! List) {
      throw const ApiException(message: 'Danh sách nhân viên không hợp lệ.');
    }
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> getEmployeeById(int employeeId) async =>
      _unwrapMap(await _api.get('/api/v1/employees/$employeeId'));

  /// Quyết định thưởng/phạt của chính nhân viên (GET /api/v1/rewards-penalties/me). Không cần quyền riêng.
  Future<Map<String, dynamic>> getMyDecisions({int page = 0}) async =>
      _unwrapMap(
        await _api.get(
          '/api/v1/rewards-penalties/me',
          queryParameters: {'page': page, 'size': 20},
        ),
      );

  /// Quyền hiệu lực của người đang đăng nhập (GET /api/v1/users/me/permissions).
  Future<CurrentAccess> getCurrentAccess() async {
    final data = _unwrapMap(await _api.get('/api/v1/users/me/permissions'));
    Set<String> strings(Object? value) =>
        value is List ? value.whereType<String>().toSet() : <String>{};
    return CurrentAccess(
      roles: strings(data['roles']),
      permissions: strings(data['permissions']),
    );
  }

  /// Tạo hồ sơ nhân viên cho một tài khoản chưa có hồ sơ (POST /api/v1/employees).
  /// Body theo EmployeeDto.CreateRequest (userId, employeeCode, positionId, hireDate bắt buộc).
  Future<Map<String, dynamic>> createEmployee(
    Map<String, dynamic> body,
  ) async => _unwrapMap(await _api.post('/api/v1/employees', data: body));

  /// Sửa một phần hồ sơ (PATCH /api/v1/employees/{id}). Chỉ gửi các trường đã đổi.
  /// Máy chủ bỏ qua trường null (không có cách xóa ngày sinh/ngày vào làm qua PATCH).
  /// Chuỗi rỗng: phone và identityNumber thành null; address và emergencyContact thành chuỗi rỗng.
  Future<Map<String, dynamic>> updateEmployee(
    int employeeId,
    Map<String, dynamic> changes,
  ) async => _unwrapMap(
    await _api.patch('/api/v1/employees/$employeeId', data: changes),
  );

  Future<List<Map<String, dynamic>>> getEmployeeTrainings(
    int employeeId,
  ) async {
    final response = await _api.get('/api/v1/employees/$employeeId/training');
    final body = response.data;
    if (body is! Map || body['success'] != true || body['data'] is! List) {
      throw const ApiException(
        message: 'Dữ liệu đào tạo nhân viên không hợp lệ.',
      );
    }
    return (body['data'] as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getAdminJobPositions({
    bool includeInactive = false,
  }) async {
    final response = await _api.get(
      '/api/v1/admin/job-positions',
      queryParameters: {'includeInactive': includeInactive},
    );
    final body = response.data;
    if (body is! Map || body['success'] != true || body['data'] is! List) {
      throw const ApiException(message: 'Danh sách chức vụ không hợp lệ.');
    }
    return (body['data'] as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  /// Loại hồ sơ của cửa hàng, kể cả đã ngưng (GET /api/v1/admin/document-types).
  Future<List<Map<String, dynamic>>> getAdminDocumentTypes() async {
    final response = await _api.get('/api/v1/admin/document-types');
    return _unwrapList(response, 'Danh sách loại hồ sơ không hợp lệ.');
  }

  /// Yêu cầu giấy tờ của một chức vụ (GET /api/v1/admin/job-positions/{id}/document-requirements).
  Future<List<Map<String, dynamic>>> getPositionDocumentRequirements(
    int positionId,
  ) async {
    final response = await _api.get(
      '/api/v1/admin/job-positions/$positionId/document-requirements',
    );
    return _unwrapList(response, 'Yêu cầu giấy tờ không hợp lệ.');
  }

  /// Thay toàn bộ yêu cầu giấy tờ của chức vụ (PUT). Danh sách gửi lên là danh sách đầy đủ.
  Future<List<Map<String, dynamic>>> replacePositionDocumentRequirements(
    int positionId,
    List<Map<String, dynamic>> requirements,
  ) async {
    final response = await _api.put(
      '/api/v1/admin/job-positions/$positionId/document-requirements',
      data: {'requirements': requirements},
    );
    return _unwrapList(response, 'Không lưu được yêu cầu giấy tờ.');
  }

  /// Yêu cầu khóa học của chức vụ (GET /api/v1/admin/job-positions/{id}/training-requirements).
  Future<List<Map<String, dynamic>>> getPositionTrainingRequirements(
    int positionId,
  ) async {
    final response = await _api.get(
      '/api/v1/admin/job-positions/$positionId/training-requirements',
    );
    return _unwrapList(response, 'Yêu cầu khóa học không hợp lệ.');
  }

  /// Thay toàn bộ yêu cầu khóa học của chức vụ (PUT). Danh sách gửi lên là danh sách đầy đủ.
  Future<List<Map<String, dynamic>>> replacePositionTrainingRequirements(
    int positionId,
    List<Map<String, dynamic>> requirements,
  ) async {
    final response = await _api.put(
      '/api/v1/admin/job-positions/$positionId/training-requirements',
      data: {'requirements': requirements},
    );
    return _unwrapList(response, 'Không lưu được yêu cầu khóa học.');
  }

  Future<Map<String, dynamic>> createAdminJobPosition({
    required String positionCode,
    required String positionName,
    String? description,
    bool isActive = true,
  }) async => _unwrapMap(
    await _api.post(
      '/api/v1/admin/job-positions',
      data: {
        'positionCode': positionCode,
        'positionName': positionName,
        'description': description,
        'isActive': isActive,
      },
    ),
  );

  Future<Map<String, dynamic>> updateAdminJobPosition({
    required int positionId,
    required String positionCode,
    required String positionName,
    String? description,
    bool isActive = true,
  }) async => _unwrapMap(
    await _api.put(
      '/api/v1/admin/job-positions/$positionId',
      data: {
        'positionCode': positionCode,
        'positionName': positionName,
        'description': description,
        'isActive': isActive,
      },
    ),
  );

  /// Lấy đủ mọi trang tài khoản (mỗi trang 50). Dùng cho màn cần toàn bộ danh sách, tránh chỉ thấy 50 người đầu.
  Future<List<Map<String, dynamic>>> getAllAdminUsers({
    int maxPages = 100,
  }) async {
    final all = <Map<String, dynamic>>[];
    for (var page = 0; page < maxPages; page++) {
      final items = await getAdminUsers(page: page);
      all.addAll(items);
      if (items.length < 50) break;
    }
    return all;
  }

  /// Lấy đủ mọi trang nhân viên (mỗi trang 50), có thể lọc theo từ khóa và trạng thái.
  Future<List<Map<String, dynamic>>> getAllEmployees({
    String? q,
    String? status,
    int maxPages = 20,
  }) async {
    final all = <Map<String, dynamic>>[];
    for (var page = 0; page < maxPages; page++) {
      final items = await getEmployees(q: q, status: status, page: page);
      all.addAll(items);
      if (items.length < 50) break;
    }
    return all;
  }

  Future<List<Map<String, dynamic>>> getAdminUsers({int page = 0}) async {
    final response = await _api.get(
      '/api/v1/admin/users',
      queryParameters: {'page': page, 'size': 50},
    );
    final body = response.data;
    final data = body is Map ? body['data'] : null;
    final items = data is Map ? data['items'] : null;
    if (body is! Map || body['success'] != true || items is! List) {
      throw const ApiException(message: 'Danh sách tài khoản không hợp lệ.');
    }
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> createAdminUser({
    required String email,
    required String displayName,
    String? phoneNumber,
    required List<String> roles,
  }) async => _unwrapMap(
    await _api.post(
      '/api/v1/admin/users',
      data: {
        'email': email,
        'displayName': displayName,
        'phoneNumber': phoneNumber,
        'roles': roles,
      },
    ),
  );

  Future<Map<String, dynamic>> setAdminUserRoles(
    int userId,
    List<String> roles,
  ) async => _unwrapMap(
    await _api.put('/api/v1/admin/users/$userId/roles', data: {'roles': roles}),
  );

  Future<Map<String, dynamic>> setAdminUserStatus(
    int userId,
    String status,
  ) async => _unwrapMap(
    await _api.patch(
      '/api/v1/admin/users/$userId/status',
      data: {'status': status},
    ),
  );

  /// Đánh giá kỹ năng của nhân viên, mức 1–5; mỗi lần là một dòng lịch sử
  /// (POST /api/v1/employees/{id}/skills/assessments, cần TRAINING_MANAGE).
  /// Máy chủ từ chối tự đánh giá chính mình.
  Future<Map<String, dynamic>> assessEmployeeSkill({
    required int employeeId,
    required int skillId,
    required int level,
    String? note,
  }) async => _unwrapMap(
    await _api.post(
      '/api/v1/employees/$employeeId/skills/assessments',
      data: {
        'skillId': skillId,
        'level': level,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    ),
  );

  /// Danh sách vi phạm (GET /api/v1/violations). status: OPEN | CONFIRMED | DISMISSED | RESOLVED, bỏ trống để xem tất cả.
  /// Cần VIOLATION_REVIEW. Trả về PageResponse.
  Future<Map<String, dynamic>> getViolations({
    String? status,
    int page = 0,
  }) async {
    final response = await _api.get(
      '/api/v1/violations',
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
        'page': page,
        'size': 50,
      },
    );
    return _unwrapMap(response);
  }

  /// Employee self-service violations; the backend derives ownership from the signed-in user.
  Future<Map<String, dynamic>> getMyViolations({int page = 0}) async =>
      _unwrapMap(
        await _api.get(
          '/api/v1/employees/me/violations',
          queryParameters: {'page': page, 'size': 50},
        ),
      );

  Future<List<Map<String, dynamic>>> getMyViolationExplanations(
    int violationId,
  ) async => _unwrapList(
    await _api.get('/api/v1/employees/me/violations/$violationId/explanations'),
    'Không tải được lịch sử giải trình.',
  );

  Future<Map<String, dynamic>> submitViolationExplanation(
    int violationId, {
    required String explanation,
    String? evidenceStorageKey,
  }) async => _unwrapMap(
    await _api.post(
      '/api/v1/employees/me/violations/$violationId/explanations',
      data: {
        'explanation': explanation.trim(),
        if (evidenceStorageKey != null && evidenceStorageKey.isNotEmpty)
          'evidenceStorageKey': evidenceStorageKey,
      },
    ),
  );

  Future<List<Map<String, dynamic>>> getViolationExplanationsForReview(
    int violationId,
  ) async => _unwrapList(
    await _api.get('/api/v1/violations/$violationId/explanations'),
    'Không tải được giải trình của nhân viên.',
  );

  /// Mã lý do thưởng/phạt đang bật (GET /api/v1/rule-catalog). ruleType: REWARD | PENALTY | VIOLATION.
  /// Cần REWARD_PROPOSE hoặc REWARD_VIEW.
  Future<List<Map<String, dynamic>>> getRuleCatalog({String? ruleType}) async {
    final response = await _api.get(
      '/api/v1/rule-catalog',
      queryParameters: {
        if (ruleType != null && ruleType.isNotEmpty) 'ruleType': ruleType,
      },
    );
    return _unwrapList(response, 'Danh mục lý do không hợp lệ.');
  }

  /// Danh sách kỳ công (GET /api/v1/payroll-periods). Cần PAYROLL_VIEW. Máy chủ trả mảng, không phân trang.
  Future<List<Map<String, dynamic>>> getPayrollPeriods() async {
    final response = await _api.get('/api/v1/payroll-periods');
    return _unwrapList(response, 'Danh sách kỳ công không hợp lệ.');
  }

  /// Sẵn sàng chốt của một kỳ (GET /api/v1/payroll-periods/{id}/readiness). Cần PAYROLL_VIEW.
  /// Chỉ phản ánh các điều kiện chặn; trạng thái bước (periodStatus) và ngày kết thúc do máy chủ kiểm tra khi chốt.
  Future<Map<String, dynamic>> getPayrollReadiness(int periodId) async =>
      _unwrapMap(await _api.get('/api/v1/payroll-periods/$periodId/readiness'));

  /// Tạo kỳ công (POST /api/v1/payroll-periods). Cần PAYROLL_PERIOD_MANAGE. Ngày là yyyy-MM-dd.
  Future<Map<String, dynamic>> createPayrollPeriod({
    required String periodCode,
    required String startDate,
    required String endDate,
    String? note,
  }) async => _unwrapMap(
    await _api.post(
      '/api/v1/payroll-periods',
      data: {
        'periodCode': periodCode,
        'startDate': startDate,
        'endDate': endDate,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    ),
  );

  /// Quản lý xác nhận kỳ công (POST .../manager-confirm). Chỉ STORE_MANAGER, khi kỳ ở OPEN hoặc MANAGER_REVIEW.
  Future<Map<String, dynamic>> managerConfirmPayroll(int periodId) async =>
      _unwrapMap(
        await _api.post('/api/v1/payroll-periods/$periodId/manager-confirm'),
      );

  /// Tạo đơn ABSENCE chờ duyệt cho các ca vắng (POST .../absence-requests). Trả về {created: n}. Chỉ STORE_MANAGER.
  Future<Map<String, dynamic>> generatePayrollAbsenceRequests(
    int periodId,
  ) async => _unwrapMap(
    await _api.post('/api/v1/payroll-periods/$periodId/absence-requests'),
  );

  /// HR chốt kỳ công (POST .../hr-finalize). Cần PAYROLL_FINALIZE, kỳ ở HR_REVIEW và đã kết thúc.
  Future<Map<String, dynamic>> hrFinalizePayroll(int periodId) async =>
      _unwrapMap(
        await _api.post('/api/v1/payroll-periods/$periodId/hr-finalize'),
      );

  /// Mở lại kỳ đã chốt (POST .../reopen). Cần PAYROLL_REOPEN. Lý do bắt buộc.
  Future<Map<String, dynamic>> reopenPayroll(
    int periodId, {
    required String reason,
  }) async => _unwrapMap(
    await _api.post(
      '/api/v1/payroll-periods/$periodId/reopen',
      data: {'reason': reason},
    ),
  );

  /// Quyết định thưởng/phạt (GET /api/v1/rewards-penalties). Cần REWARD_VIEW.
  /// type: REWARD | PENALTY. status: PENDING_APPROVAL | APPROVED | REJECTED | CANCELLED | APPLIED. Bỏ trống để xem tất cả.
  Future<Map<String, dynamic>> getDecisions({
    String? type,
    String? status,
    int? employeeId,
    int page = 0,
  }) async {
    final response = await _api.get(
      '/api/v1/rewards-penalties',
      queryParameters: {
        if (type != null && type.isNotEmpty) 'type': type,
        if (status != null && status.isNotEmpty) 'status': status,
        if (employeeId != null) 'employeeId': employeeId,
        'page': page,
        'size': 20,
      },
    );
    return _unwrapMap(response);
  }

  /// Đề xuất thưởng/phạt (POST /api/v1/rewards-penalties). Cần REWARD_PROPOSE.
  /// Bỏ amount để dùng mức mặc định của mã lý do. effectiveDate là yyyy-MM-dd, bỏ trống để dùng hiện tại.
  Future<Map<String, dynamic>> proposeDecision({
    required String decisionType,
    required int employeeId,
    required String reasonCode,
    required String description,
    num? amount,
    String? effectiveDate,
  }) async => _unwrapMap(
    await _api.post(
      '/api/v1/rewards-penalties',
      data: {
        'decisionType': decisionType,
        'employeeId': employeeId,
        'reasonCode': reasonCode,
        'description': description,
        if (amount != null) 'amount': amount,
        if (effectiveDate != null) 'effectiveDate': effectiveDate,
      },
    ),
  );

  /// Duyệt quyết định (POST .../{decisionId}/approve). decisionId dạng REWARD-12 hoặc PENALTY-7.
  Future<Map<String, dynamic>> approveDecision(
    String decisionId, {
    String? note,
  }) async => _unwrapMap(
    await _api.post(
      '/api/v1/rewards-penalties/$decisionId/approve',
      data: {if (note != null && note.isNotEmpty) 'note': note},
    ),
  );

  /// Từ chối quyết định đang chờ duyệt. Bắt buộc có lý do.
  Future<Map<String, dynamic>> rejectDecision(
    String decisionId, {
    required String reason,
  }) async => _unwrapMap(
    await _api.post(
      '/api/v1/rewards-penalties/$decisionId/reject',
      data: {'reason': reason},
    ),
  );

  /// Hủy quyết định đang chờ duyệt hoặc đã duyệt (chưa vào lương). Bắt buộc có lý do.
  Future<Map<String, dynamic>> cancelDecision(
    String decisionId, {
    required String reason,
  }) async => _unwrapMap(
    await _api.post(
      '/api/v1/rewards-penalties/$decisionId/cancel',
      data: {'reason': reason},
    ),
  );

  /// Xác nhận vi phạm (POST /api/v1/violations/{id}/confirm). Ghi chú không bắt buộc.
  Future<Map<String, dynamic>> confirmViolation(
    int violationId, {
    String? note,
  }) async => _unwrapMap(
    await _api.post(
      '/api/v1/violations/$violationId/confirm',
      data: {if (note != null && note.isNotEmpty) 'note': note},
    ),
  );

  /// Bác bỏ vi phạm (POST /api/v1/violations/{id}/dismiss). Bắt buộc có lý do.
  Future<Map<String, dynamic>> dismissViolation(
    int violationId, {
    required String reason,
  }) async => _unwrapMap(
    await _api.post(
      '/api/v1/violations/$violationId/dismiss',
      data: {'reason': reason},
    ),
  );

  /// Thêm kỹ năng vào danh mục (POST /api/v1/admin/skills, SYSTEM_ADMIN).
  /// Máy chủ đổi mã thành chữ hoa và trả lỗi nếu mã đã tồn tại.
  Future<Map<String, dynamic>> createSkill({
    required String skillCode,
    required String skillName,
    String? description,
  }) async => _unwrapMap(
    await _api.post(
      '/api/v1/admin/skills',
      data: {
        'skillCode': skillCode,
        'skillName': skillName,
        if (description != null && description.isNotEmpty)
          'description': description,
      },
    ),
  );

  /// Thông báo đã gửi và trạng thái giao, chỉ đọc (GET /api/v1/admin/notification-deliveries, SYSTEM_ADMIN).
  /// status: PENDING | SENT | FAILED | CANCELLED, bỏ trống để xem tất cả. Trả về PageResponse.
  /// Máy chủ không trả về người nhận trong dòng này.
  Future<Map<String, dynamic>> getNotificationDeliveries({
    String? status,
    int page = 0,
  }) async {
    final response = await _api.get(
      '/api/v1/admin/notification-deliveries',
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
        'page': page,
        'size': 50,
      },
    );
    return _unwrapMap(response);
  }

  /// Nhật ký hệ thống, chỉ đọc (GET /api/v1/admin/audit-logs, SYSTEM_ADMIN).
  /// Trả về PageResponse: items, page, size, totalElements, totalPages. from/to dạng yyyy-MM-dd.
  Future<Map<String, dynamic>> getAuditLogs({
    String? entityType,
    String? actionCode,
    String? from,
    String? to,
    int page = 0,
  }) async {
    final response = await _api.get(
      '/api/v1/admin/audit-logs',
      queryParameters: {
        if (entityType != null && entityType.isNotEmpty)
          'entityType': entityType,
        if (actionCode != null && actionCode.isNotEmpty)
          'actionCode': actionCode,
        if (from != null) 'from': from,
        if (to != null) 'to': to,
        'page': page,
        'size': 50,
      },
    );
    return _unwrapMap(response);
  }

  /// Danh mục quyền (permissions: code, name) và tập quyền dựng sẵn (permissionSets: HR -> danh sách mã quyền).
  /// GET /api/v1/admin/users/permission-catalog (SYSTEM_ADMIN).
  Future<Map<String, dynamic>> getPermissionCatalog() async =>
      _unwrapMap(await _api.get('/api/v1/admin/users/permission-catalog'));

  /// Quyền gán trực tiếp (direct), quyền hiệu lực (effective) và vai trò của một tài khoản.
  /// GET /api/v1/admin/users/{userId}/permissions.
  Future<Map<String, dynamic>> getUserPermissions(int userId) async =>
      _unwrapMap(await _api.get('/api/v1/admin/users/$userId/permissions'));

  /// THAY TOÀN BỘ quyền gán trực tiếp (PUT). Máy chủ hợp permissions với các tập trong permissionSets.
  /// Muốn giữ quyền khác thì phải gửi lại cả danh sách đó trong permissions.
  Future<Map<String, dynamic>> setUserPermissions(
    int userId, {
    required List<String> permissions,
    required List<String> permissionSets,
  }) async => _unwrapMap(
    await _api.put(
      '/api/v1/admin/users/$userId/permissions',
      data: {'permissions': permissions, 'permissionSets': permissionSets},
    ),
  );

  Future<Map<String, dynamic>> getEmployeeProfile() async =>
      _unwrapMap(await _api.get('/api/v1/employees/me'));

  Future<Map<String, dynamic>> getMyDocumentCatalog() async =>
      _unwrapMap(await _api.get('/api/v1/employees/me/documents/catalog'));

  Future<List<Map<String, dynamic>>> getMyDocuments() async => _unwrapList(
    await _api.get('/api/v1/employees/me/documents'),
    'Không tải được lịch sử hồ sơ.',
  );

  Future<String> uploadDocument({
    required Uint8List bytes,
    required String contentType,
  }) async {
    final response = await _api.uploadBytes(
      '/api/v1/storage/uploads?purpose=DOCUMENT',
      bytes: bytes,
      contentType: contentType,
    );
    final body = response.data;
    final data = body is Map ? body['data'] : null;
    if (body is! Map ||
        body['success'] != true ||
        data is! Map ||
        data['storageKey'] is! String) {
      throw const ApiException(
        message: 'Máy chủ không trả về khóa hồ sơ vừa tải lên.',
      );
    }
    return data['storageKey'] as String;
  }

  Future<Map<String, dynamic>> submitDocument({
    required int documentTypeId,
    required String storageKey,
    DateTime? issuedAt,
    DateTime? expiresAt,
  }) async => _unwrapMap(
    await _api.post(
      '/api/v1/employees/me/documents',
      data: {
        'documentTypeId': documentTypeId,
        'storageKey': storageKey,
        if (issuedAt != null) 'issuedAt': _dateOnly(issuedAt),
        if (expiresAt != null) 'expiresAt': _dateOnly(expiresAt),
      },
    ),
  );

  Future<List<Map<String, dynamic>>> getPendingDocuments() async => _unwrapList(
    await _api.get('/api/v1/documents/pending'),
    'Không tải được hàng đợi duyệt hồ sơ.',
  );

  Future<Map<String, dynamic>> getDocument(int documentId) async =>
      _unwrapMap(await _api.get('/api/v1/documents/$documentId'));

  Future<Map<String, dynamic>> approveDocument(int documentId) async =>
      _unwrapMap(await _api.post('/api/v1/documents/$documentId/approve'));

  Future<Map<String, dynamic>> rejectDocument({
    required int documentId,
    required String reason,
  }) async => _unwrapMap(
    await _api.post(
      '/api/v1/documents/$documentId/reject',
      data: {'reason': reason},
    ),
  );

  String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<Map<String, dynamic>> getEmployeeOverview() async =>
      _unwrapMap(await _api.get('/api/v1/dashboard/employee/overview'));

  Future<List<Map<String, dynamic>>> getMySchedule({
    required String from,
    required String to,
  }) async {
    final response = await _api.get(
      '/api/v1/shift-assignments/me',
      queryParameters: {'from': from, 'to': to},
    );
    final body = response.data;
    if (body is! Map || body['success'] != true || body['data'] is! List) {
      throw const ApiException(message: 'Dữ liệu lịch làm việc không hợp lệ.');
    }
    return (body['data'] as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>?> getCurrentShift() async {
    try {
      final response = await _api.get('/api/v1/attendance/me/current');
      final body = response.data;
      if (body is! Map || body['success'] != true) {
        throw const ApiException(
          message: 'Dữ liệu ca làm hiện tại không hợp lệ.',
        );
      }
      if (body['data'] == null) return null;
      if (body['data'] is! Map) {
        throw const ApiException(
          message: 'Dữ liệu ca làm hiện tại không hợp lệ.',
        );
      }
      return Map<String, dynamic>.from(body['data'] as Map);
    } on ApiException catch (error) {
      // A missing current shift should not prevent the dashboard from loading.
      if (error.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getManagerPendingExplanations() async {
    final response = await _api.get(
      '/api/v1/attendance/explanation-requests',
      queryParameters: {'status': 'PENDING_MANAGER', 'size': 50},
    );
    final body = response.data;
    final data = body is Map ? body['data'] : null;
    final items = data is Map ? data['items'] : null;
    if (body is! Map || body['success'] != true || items is! List) {
      throw const ApiException(
        message: 'Dữ liệu giải trình chờ duyệt không hợp lệ.',
      );
    }
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getManagerPendingAdjustments() async {
    final response = await _api.get(
      '/api/v1/attendance/adjustment-requests',
      queryParameters: {'status': 'PENDING_MANAGER', 'size': 50},
    );
    final body = response.data;
    final data = body is Map ? body['data'] : null;
    final items = data is Map ? data['items'] : null;
    if (body is! Map || body['success'] != true || items is! List) {
      throw const ApiException(
        message: 'Dữ liệu điều chỉnh công chờ duyệt không hợp lệ.',
      );
    }
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  /// Yêu cầu giải trình hoặc điều chỉnh công theo trạng thái, cho quản lý
  /// (GET /api/v1/attendance/explanation-requests | adjustment-requests).
  /// Trạng thái: PENDING_MANAGER, PENDING_HR, APPROVED, REJECTED.
  Future<List<Map<String, dynamic>>> getManagerAttendanceRequests({
    required bool adjustment,
    required String status,
  }) async {
    final segment = adjustment ? 'adjustment-requests' : 'explanation-requests';
    final response = await _api.get(
      '/api/v1/attendance/$segment',
      queryParameters: {'status': status, 'size': 50},
    );
    return _unwrapPageItems(
      response,
      'Dữ liệu yêu cầu chấm công không hợp lệ.',
    );
  }

  /// Checklist theo trạng thái của run (GET /api/v1/checklists/instances).
  /// SUBMITTED = chờ quản lý duyệt, APPROVED, REJECTED.
  Future<List<Map<String, dynamic>>> getManagerChecklistRuns({
    required String status,
  }) async {
    final response = await _api.get(
      '/api/v1/checklists/instances',
      queryParameters: {'status': status, 'size': 50},
    );
    return _unwrapPageItems(response, 'Dữ liệu checklist không hợp lệ.');
  }

  /// Đề nghị tăng ca theo trạng thái (GET /api/v1/attendance/overtime-requests).
  /// Trạng thái: PENDING, APPROVED, REJECTED.
  Future<List<Map<String, dynamic>>> getManagerOvertimeRequests({
    required String status,
  }) async {
    final response = await _api.get(
      '/api/v1/attendance/overtime-requests',
      queryParameters: {'status': status, 'size': 50},
    );
    return _unwrapPageItems(response, 'Dữ liệu đề nghị tăng ca không hợp lệ.');
  }

  /// Đề nghị tăng ca của bản thân (GET /api/v1/attendance/overtime-requests/me).
  Future<List<Map<String, dynamic>>> getMyOvertimeRequests() async {
    final response = await _api.get('/api/v1/attendance/overtime-requests/me');
    return _unwrapList(response, 'Dữ liệu đề nghị tăng ca không hợp lệ.');
  }

  /// Gửi đề nghị tăng ca trên một bản ghi chấm công (POST /api/v1/attendance/{attendanceId}/overtime-requests).
  /// requestedStartAt/requestedEndAt là ISO 8601 có offset. Backend kiểm tra OT sau giờ kết thúc ca và giới hạn thời lượng.
  Future<Map<String, dynamic>> createOvertimeRequest({
    required int attendanceId,
    required String requestedStartAt,
    required String requestedEndAt,
    required String reason,
  }) async => _unwrapMap(
    await _api.post(
      '/api/v1/attendance/$attendanceId/overtime-requests',
      data: {
        'requestedStartAt': requestedStartAt,
        'requestedEndAt': requestedEndAt,
        'reason': reason,
      },
    ),
  );

  Future<Map<String, dynamic>> approveOvertimeRequest(
    int requestId, {
    String? note,
  }) async => _unwrapMap(
    await _api.post(
      '/api/v1/attendance/overtime-requests/$requestId/approve',
      data: {if (note != null && note.isNotEmpty) 'note': note},
    ),
  );

  Future<Map<String, dynamic>> rejectOvertimeRequest(
    int requestId, {
    required String reason,
  }) async => _unwrapMap(
    await _api.post(
      '/api/v1/attendance/overtime-requests/$requestId/reject',
      data: {'reason': reason},
    ),
  );

  Future<Map<String, dynamic>> approveChecklistTask(
    int taskId, {
    String? note,
  }) async => _unwrapMap(
    await _api.post(
      '/api/v1/checklists/tasks/$taskId/approve',
      data: {if (note != null && note.isNotEmpty) 'note': note},
    ),
  );

  Future<Map<String, dynamic>> rejectChecklistTask(
    int taskId, {
    required String reason,
  }) async => _unwrapMap(
    await _api.post(
      '/api/v1/checklists/tasks/$taskId/reject',
      data: {'reason': reason},
    ),
  );

  List<Map<String, dynamic>> _unwrapPageItems(
    dynamic response,
    String errorMessage,
  ) {
    final body = response.data;
    final data = body is Map ? body['data'] : null;
    final items = data is Map ? data['items'] : null;
    if (body is! Map || body['success'] != true || items is! List) {
      throw ApiException(message: errorMessage);
    }
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  /// Ca làm của toàn cửa hàng trong khoảng ngày, cho quản lý (GET /api/v1/shift-assignments).
  /// from/to dạng yyyy-MM-dd. Trạng thái huỷ vẫn được trả về; UI tự bỏ qua.
  Future<List<Map<String, dynamic>>> getShiftAssignments({
    required String from,
    required String to,
  }) async {
    final response = await _api.get(
      '/api/v1/shift-assignments',
      queryParameters: {'from': from, 'to': to, 'size': 500},
    );
    return _unwrapPageItems(response, 'Dữ liệu phân ca không hợp lệ.');
  }

  /// Danh mục ca làm của cửa hàng (GET /api/v1/work-shifts). Quản lý thấy cả ca đã ngừng.
  Future<List<Map<String, dynamic>>> getWorkShifts() async {
    final response = await _api.get('/api/v1/work-shifts');
    return _unwrapList(response, 'Danh sách ca làm không hợp lệ.');
  }

  Future<Map<String, dynamic>> createShiftAssignment({
    required int employeeId,
    required int workShiftId,
    required String workDate,
    String? note,
  }) async => _unwrapMap(
    await _api.post(
      '/api/v1/shift-assignments',
      data: {
        'employeeId': employeeId,
        'workShiftId': workShiftId,
        'workDate': workDate,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    ),
  );

  /// Sửa ca đã phân: đổi ca, ngày hoặc ghi chú (PATCH /api/v1/shift-assignments/{id}).
  Future<Map<String, dynamic>> updateShiftAssignment(
    int assignmentId, {
    int? workShiftId,
    String? workDate,
    String? note,
  }) async => _unwrapMap(
    await _api.patch(
      '/api/v1/shift-assignments/$assignmentId',
      data: {
        if (workShiftId != null) 'workShiftId': workShiftId,
        if (workDate != null) 'workDate': workDate,
        if (note != null) 'note': note,
      },
    ),
  );

  Future<Map<String, dynamic>> cancelShiftAssignment(
    int assignmentId, {
    String? note,
  }) async => _unwrapMap(
    await _api.post(
      '/api/v1/shift-assignments/$assignmentId/cancel',
      data: {if (note != null && note.isNotEmpty) 'note': note},
    ),
  );

  /// Tổng quan hôm nay của quản lý: attendanceToday (StatsView), pending (số việc theo loại),
  /// nextActions (danh sách việc có số lượng > 0). GET /api/v1/dashboard/manager/overview.
  Future<Map<String, dynamic>> getManagerDashboardOverview() async =>
      _unwrapMap(await _api.get('/api/v1/dashboard/manager/overview'));

  /// Bản ghi chấm công trong khoảng ngày, cho quản lý (GET /api/v1/attendance). from/to: yyyy-MM-dd.
  Future<List<Map<String, dynamic>>> getAttendanceRecords({
    required String from,
    required String to,
  }) async {
    final response = await _api.get(
      '/api/v1/attendance',
      queryParameters: {'from': from, 'to': to, 'size': 100},
    );
    return _unwrapPageItems(response, 'Dữ liệu chấm công không hợp lệ.');
  }

  /// Thống kê chấm công trong khoảng ngày, có thể lọc theo ca (GET /api/v1/dashboard/manager/attendance).
  /// Trả về StatsView: scheduledShifts, checkedInOnTime, late, absent, missingCheckOuts,
  /// verificationPending, lateMinutesTotal.
  Future<Map<String, dynamic>> getAttendanceStats({
    required String from,
    required String to,
    int? shiftId,
  }) async => _unwrapMap(
    await _api.get(
      '/api/v1/dashboard/manager/attendance',
      queryParameters: {
        'from': from,
        'to': to,
        if (shiftId != null) 'shiftId': shiftId,
      },
    ),
  );

  /// Báo cáo chấm công theo từng nhân viên trong khoảng ngày (GET /api/v1/reports/attendance).
  /// Không lọc theo ca. Mỗi dòng: employeeId, employeeName, scheduledShifts, lateCount,
  /// lateMinutes, absentShifts, workedMinutes, approvedOvertimeMinutes.
  Future<List<Map<String, dynamic>>> getAttendanceReportRows({
    required String from,
    required String to,
  }) async {
    final response = await _api.get(
      '/api/v1/reports/attendance',
      queryParameters: {'from': from, 'to': to},
    );
    return _unwrapList(
      response,
      'Báo cáo chấm công theo nhân viên không hợp lệ.',
    );
  }

  Future<Map<String, dynamic>> reviewManagerAttendanceRequest({
    required int requestId,
    required bool adjustment,
    required bool approve,
    String? note,
  }) async {
    final segment = adjustment ? 'adjustment-requests' : 'explanation-requests';
    final action = adjustment
        ? (approve ? 'manager-approve' : 'manager-reject')
        : (approve ? 'approve' : 'reject');
    final body = approve ? {'note': note ?? ''} : {'reason': note ?? ''};
    return _unwrapMap(
      await _api.post(
        '/api/v1/attendance/$segment/$requestId/$action',
        data: body,
      ),
    );
  }

  /// Tổng quan của một nhân viên, gồm `training` (số khóa bắt buộc, đã đạt, hạn chế ca).
  /// Nhân viên xem được hồ sơ của chính mình (GET /api/v1/employees/{id}/overview).
  Future<Map<String, dynamic>> getEmployeeOverviewById(int employeeId) async =>
      _unwrapMap(await _api.get('/api/v1/employees/$employeeId/overview'));

  /// Cấu hình cửa hàng hiện tại: toạ độ và bán kính chấm công (GET /api/v1/stores/current).
  Future<Map<String, dynamic>> getCurrentStore() async =>
      _unwrapMap(await _api.get('/api/v1/stores/current'));

  Future<List<Map<String, dynamic>>> getMyAttendanceDevices() async {
    final response = await _api.get('/api/v1/attendance/devices/me');
    final body = response.data;
    if (body is! Map || body['success'] != true || body['data'] is! List) {
      throw const ApiException(
        message: 'Dữ liệu thiết bị chấm công không hợp lệ.',
      );
    }
    return (body['data'] as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getPendingAttendanceDevices() async {
    final response = await _api.get('/api/v1/attendance/devices/pending');
    final body = response.data;
    final data = body is Map ? body['data'] : null;
    final items = data is Map ? data['items'] : null;
    if (body is! Map || body['success'] != true || items is! List) {
      throw const ApiException(
        message: 'Dữ liệu thiết bị chờ duyệt không hợp lệ.',
      );
    }
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> approveAttendanceDevice(int deviceId) async =>
      _unwrapMap(
        await _api.post('/api/v1/attendance/devices/$deviceId/approve'),
      );

  Future<Map<String, dynamic>> rejectAttendanceDevice({
    required int deviceId,
    required String reason,
  }) async => _unwrapMap(
    await _api.post(
      '/api/v1/attendance/devices/$deviceId/reject',
      data: {'reason': reason},
    ),
  );

  /// Mọi thiết bị của một nhân viên, mới nhất trước, kèm status và reason
  /// (GET /api/v1/attendance/devices/employees/{id}, quyền DEVICE_APPROVE).
  Future<List<Map<String, dynamic>>> getEmployeeAttendanceDevices(
    int employeeId,
  ) async {
    final response = await _api.get(
      '/api/v1/attendance/devices/employees/$employeeId',
    );
    return _unwrapList(
      response,
      'Dữ liệu thiết bị của nhân viên không hợp lệ.',
    );
  }

  /// Thu hồi thiết bị ACTIVE, bắt buộc có lý do (POST /api/v1/attendance/devices/{id}/revoke).
  Future<Map<String, dynamic>> revokeAttendanceDevice({
    required int deviceId,
    required String reason,
  }) async => _unwrapMap(
    await _api.post(
      '/api/v1/attendance/devices/$deviceId/revoke',
      data: {'reason': reason},
    ),
  );

  Future<String> getOrCreateAttendanceDeviceFingerprint() async {
    const key = 'hrm_attendance_device_fingerprint';
    final existing = await _api.storage.read(key: key);
    if (existing != null && existing.length >= 32) return existing;
    final random = Random.secure();
    final fingerprint = List<int>.generate(
      32,
      (_) => random.nextInt(256),
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    await _api.storage.write(key: key, value: fingerprint);
    return fingerprint;
  }

  Future<Map<String, dynamic>> registerAttendanceDevice({
    required String fingerprint,
    required String platform,
    required String label,
  }) async => _unwrapMap(
    await _api.post(
      '/api/v1/attendance/devices/register',
      data: {
        'deviceFingerprint': fingerprint,
        'platform': platform,
        'deviceLabel': label,
      },
    ),
  );

  Future<Map<String, dynamic>> checkIn({
    required int shiftAssignmentId,
    required int deviceId,
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required String capturedAt,
    required String photoStorageKey,
    required String idempotencyKey,
  }) async => _unwrapMap(
    await _api.post(
      '/api/v1/attendance/check-in',
      data: {
        'shiftAssignmentId': shiftAssignmentId,
        'deviceId': deviceId,
        'location': {
          'latitude': latitude,
          'longitude': longitude,
          'accuracyMeters': accuracyMeters,
          'capturedAt': capturedAt,
        },
        'photoEvidence': {
          'storageKey': photoStorageKey,
          'cameraPermissionGranted': true,
        },
        'faceVerification': null,
        'idempotencyKey': idempotencyKey,
      },
    ),
  );

  Future<Map<String, dynamic>> checkOut({
    required int attendanceId,
    required int deviceId,
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required String capturedAt,
    required String photoStorageKey,
    required String idempotencyKey,
  }) async => _unwrapMap(
    await _api.post(
      '/api/v1/attendance/check-out',
      data: {
        'attendanceId': attendanceId,
        'deviceId': deviceId,
        'location': {
          'latitude': latitude,
          'longitude': longitude,
          'accuracyMeters': accuracyMeters,
          'capturedAt': capturedAt,
        },
        'photoEvidence': {
          'storageKey': photoStorageKey,
          'cameraPermissionGranted': true,
        },
        'faceVerification': null,
        'idempotencyKey': idempotencyKey,
      },
    ),
  );

  Future<List<Map<String, dynamic>>> getMyAttendance({
    String? from,
    String? to,
    int page = 0,
  }) async {
    final response = await _api.get(
      '/api/v1/attendance/me',
      queryParameters: {
        if (from != null) 'from': from,
        if (to != null) 'to': to,
        'page': page,
        'size': 31,
      },
    );
    final body = response.data;
    final data = body is Map ? body['data'] : null;
    final items = data is Map ? data['items'] : null;
    if (body is! Map || body['success'] != true || items is! List) {
      throw const ApiException(
        message: 'Dữ liệu lịch sử chấm công không hợp lệ.',
      );
    }
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getMyExplanations() async {
    final response = await _api.get(
      '/api/v1/attendance/explanation-requests/me',
    );
    final body = response.data;
    if (body is! Map || body['success'] != true || body['data'] is! List) {
      throw const ApiException(message: 'Dữ liệu giải trình không hợp lệ.');
    }
    return (body['data'] as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getMyAdjustments({int page = 0}) async {
    final response = await _api.get(
      '/api/v1/attendance/adjustment-requests/me',
      queryParameters: {'page': page, 'size': 20},
    );
    final body = response.data;
    final data = body is Map ? body['data'] : null;
    final items = data is Map ? data['items'] : null;
    if (body is! Map || body['success'] != true || items is! List) {
      throw const ApiException(
        message: 'Dữ liệu yêu cầu điều chỉnh công không hợp lệ.',
      );
    }
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> createExplanation({
    required String reasonCode,
    required String reason,
    int? scheduleId,
    int? attendanceId,
    String? evidenceStorageKey,
  }) async {
    final path = attendanceId == null
        ? '/api/v1/attendance/explanation-requests'
        : '/api/v1/attendance/$attendanceId/explanation-requests';
    return _unwrapMap(
      await _api.post(
        path,
        data: {
          'reasonCode': reasonCode,
          'reason': reason,
          if (scheduleId != null) 'scheduleId': scheduleId,
          if (evidenceStorageKey != null)
            'evidenceStorageKey': evidenceStorageKey,
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> createAdjustment({
    required int attendanceId,
    required String reasonCode,
    required String reason,
    String? requestedCheckInAt,
    String? requestedCheckOutAt,
    String? evidenceStorageKey,
  }) async {
    final response = await _api.post(
      '/api/v1/attendance/adjustment-requests',
      data: {
        'attendanceId': attendanceId,
        'reasonCode': reasonCode,
        'reason': reason,
        if (requestedCheckInAt != null)
          'requestedCheckInAt': requestedCheckInAt,
        if (requestedCheckOutAt != null)
          'requestedCheckOutAt': requestedCheckOutAt,
        if (evidenceStorageKey != null)
          'evidenceStorageKey': evidenceStorageKey,
      },
    );
    final body = response.data;
    if (body is! Map || body['success'] != true || body['data'] is! List) {
      throw const ApiException(
        message: 'Không gửi được yêu cầu điều chỉnh công.',
      );
    }
    return (body['data'] as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<String> uploadImage({
    required Uint8List bytes,
    required String purpose,
  }) async {
    final response = await _api.uploadBytes(
      '/api/v1/storage/uploads?purpose=$purpose',
      bytes: bytes,
      contentType: _imageContentType(bytes),
    );
    final body = response.data;
    final data = body is Map ? body['data'] : null;
    if (body is! Map ||
        body['success'] != true ||
        data is! Map ||
        data['storageKey'] is! String) {
      throw const ApiException(
        message: 'Máy chủ không trả về khóa lưu trữ ảnh.',
      );
    }
    return data['storageKey'] as String;
  }

  String _imageContentType(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return 'image/webp';
    }
    throw const ApiException(message: 'Định dạng ảnh không được hỗ trợ.');
  }

  Future<List<Map<String, dynamic>>> getTrainingCourses() async {
    final response = await _api.get('/api/v1/training/courses');
    final body = response.data;
    if (body is! Map || body['success'] != true || body['data'] is! List) {
      throw const ApiException(message: 'Danh sách khóa học không hợp lệ.');
    }
    return (body['data'] as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getMyTraining() async {
    final response = await _api.get('/api/v1/training/me');
    final body = response.data;
    if (body is! Map || body['success'] != true || body['data'] is! List) {
      throw const ApiException(
        message: 'Dữ liệu đào tạo cá nhân không hợp lệ.',
      );
    }
    return (body['data'] as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  /// Khóa bắt buộc đang hiệu lực của chức vụ hiện tại, kể cả khóa chưa ghi danh
  /// (GET /api/v1/training/me/requirements). Mỗi dòng: courseId, courseName,
  /// blocksShiftAssignment, status (NOT_ENROLLED hoặc trạng thái đào tạo), satisfied.
  Future<List<Map<String, dynamic>>> getMyTrainingRequirements() async {
    final response = await _api.get('/api/v1/training/me/requirements');
    return _unwrapList(response, 'Danh sách khóa bắt buộc không hợp lệ.');
  }

  Future<Map<String, dynamic>> enrollTraining(int courseId) async =>
      _unwrapMap(await _api.post('/api/v1/training/courses/$courseId/enroll'));

  /// Cấu hình cửa hàng và chính sách chấm công (GET /api/v1/admin/store-settings).
  /// Trả về SettingsView: store {name, address, latitude, longitude, ...} và các chính sách.
  Future<Map<String, dynamic>> getStoreSettings() async =>
      _unwrapMap(await _api.get('/api/v1/admin/store-settings'));

  /// Sửa một phần cấu hình (PATCH). Chỉ gửi các trường cần đổi.
  Future<Map<String, dynamic>> updateStoreSettings(
    Map<String, dynamic> changes,
  ) async => _unwrapMap(
    await _api.patch('/api/v1/admin/store-settings', data: changes),
  );

  /// Quy tắc nhắc việc (GET /api/v1/admin/reminder-rules): ruleId, description, leadMinutes, intervalMinutes, maxAttempts.
  Future<List<Map<String, dynamic>>> getReminderRules() async {
    final response = await _api.get('/api/v1/admin/reminder-rules');
    return _unwrapList(response, 'Quy tắc nhắc việc không hợp lệ.');
  }

  Future<Map<String, dynamic>> updateReminderRule(
    String ruleId, {
    required int leadMinutes,
    required int intervalMinutes,
    required int maxAttempts,
  }) async => _unwrapMap(
    await _api.put(
      '/api/v1/admin/reminder-rules/$ruleId',
      data: {
        'leadMinutes': leadMinutes,
        'intervalMinutes': intervalMinutes,
        'maxAttempts': maxAttempts,
      },
    ),
  );

  /// Tất cả phiên bản mẫu checklist của cửa hàng (GET /api/v1/admin/checklist-templates).
  /// Mỗi bản ghi là một phiên bản: checklistCode, version, isActive, items.
  Future<List<Map<String, dynamic>>> getAdminChecklistTemplates() async {
    final response = await _api.get('/api/v1/admin/checklist-templates');
    return _unwrapList(response, 'Danh sách mẫu checklist không hợp lệ.');
  }

  Future<Map<String, dynamic>> createAdminChecklistTemplate(
    Map<String, dynamic> payload,
  ) async => _unwrapMap(
    await _api.post('/api/v1/admin/checklist-templates', data: payload),
  );

  /// Sửa mẫu. Nếu mẫu đã có lượt thực hiện, máy chủ tạo phiên bản mới (chưa kích hoạt) và trả về phiên bản đó.
  Future<Map<String, dynamic>> updateAdminChecklistTemplate(
    int templateId,
    Map<String, dynamic> payload,
  ) async => _unwrapMap(
    await _api.put(
      '/api/v1/admin/checklist-templates/$templateId',
      data: payload,
    ),
  );

  /// Kích hoạt một phiên bản; các phiên bản khác cùng mã bị ngưng.
  Future<Map<String, dynamic>> activateAdminChecklistTemplate(
    int templateId,
  ) async => _unwrapMap(
    await _api.post('/api/v1/admin/checklist-templates/$templateId/activate'),
  );

  Future<Map<String, dynamic>> createTrainingCourse(
    Map<String, dynamic> payload,
  ) async => _unwrapMap(
    await _api.post('/api/v1/admin/training/courses', data: payload),
  );

  Future<Map<String, dynamic>> updateTrainingCourse(
    int courseId,
    Map<String, dynamic> payload,
  ) async => _unwrapMap(
    await _api.put('/api/v1/admin/training/courses/$courseId', data: payload),
  );

  Future<Map<String, dynamic>> getEmployeeTrainingProgress(
    int employeeId,
  ) async => _unwrapMap(
    await _api.get('/api/v1/training/employees/$employeeId/progress'),
  );

  Future<Map<String, dynamic>> recordTrainingAttempt({
    required int courseId,
    required int employeeId,
    double? score,
  }) async => _unwrapMap(
    await _api.post(
      '/api/v1/training/courses/$courseId/attempts',
      data: {'employeeId': employeeId, if (score != null) 'score': score},
    ),
  );

  /// Danh mục kỹ năng đang hoạt động (GET /api/v1/skills).
  Future<List<Map<String, dynamic>>> getSkills() async {
    final response = await _api.get('/api/v1/skills');
    return _unwrapList(response, 'Danh sách kỹ năng không hợp lệ.');
  }

  /// Lịch sử đánh giá kỹ năng của một nhân viên (GET /api/v1/employees/{id}/skills).
  Future<List<Map<String, dynamic>>> getEmployeeSkillHistory(
    int employeeId,
  ) async {
    final response = await _api.get('/api/v1/employees/$employeeId/skills');
    return _unwrapList(response, 'Dữ liệu kỹ năng nhân viên không hợp lệ.');
  }

  List<Map<String, dynamic>> _unwrapList(
    dynamic response,
    String errorMessage,
  ) {
    final body = response.data;
    if (body is! Map || body['success'] != true || body['data'] is! List) {
      throw ApiException(message: errorMessage);
    }
    return (body['data'] as List)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Map<String, dynamic> _unwrapMap(dynamic response) {
    final body = response.data;
    if (body is! Map || body['success'] != true || body['data'] is! Map) {
      throw const ApiException(
        message: 'Dữ liệu trả về từ máy chủ không hợp lệ.',
      );
    }
    return Map<String, dynamic>.from(body['data'] as Map);
  }
}
