/// Fixed, presentation-only data for the BeanHub employee demo.
///
/// Policy values marked as proposed come from the SRS defaults and are not
/// production policy. Replace this data source with API-backed data later.
enum DemoAttendanceStatus { notCheckedIn, checkedIn, checkedOut }

enum DemoDeviceStatus { active, pending, locked, revoked }

enum DemoTrainingStatus { complete, inProgress, expired }

enum DemoChecklistStatus {
  pending,
  inProgress,
  submitted,
  approved,
  rejected,
  overdue,
}

class DemoEmployee {
  const DemoEmployee({
    required this.fullName,
    required this.employeeCode,
    required this.email,
    required this.phone,
    required this.position,
    required this.employmentStatus,
    required this.hireDate,
  });

  final String fullName;
  final String employeeCode;
  final String email;
  final String phone;
  final String position;
  final String employmentStatus;
  final String hireDate;
}

enum DemoManagerEmployeeStatus { working, paused, onLeave }

class DemoManagerEmployee {
  const DemoManagerEmployee({
    required this.name,
    required this.employeeCode,
    required this.position,
    required this.initials,
    required this.status,
    required this.avatarColorValue,
  });

  final String name;
  final String employeeCode;
  final String position;
  final String initials;
  final DemoManagerEmployeeStatus status;
  final int avatarColorValue;
}

class DemoShiftAssignment {
  const DemoShiftAssignment({
    required this.workDate,
    required this.dayLabel,
    required this.shiftName,
    required this.startTime,
    required this.endTime,
    required this.workArea,
    required this.assignmentStatus,
  });

  final String workDate;
  final String dayLabel;
  final String shiftName;
  final String startTime;
  final String endTime;
  final String workArea;
  final String assignmentStatus;
}

enum DemoRosterShift { morning, afternoon, off, leave }

class DemoManagerShiftRosterRow {
  const DemoManagerShiftRosterRow({
    required this.employeeName,
    required this.employeeCode,
    required this.position,
    required this.initials,
    required this.shifts,
  });

  final String employeeName;
  final String employeeCode;
  final String position;
  final String initials;

  /// Shift for each day from Tuesday 13/10/2026 through Monday 19/10/2026.
  final List<DemoRosterShift> shifts;
}

class DemoAttendancePolicy {
  const DemoAttendancePolicy({
    required this.storeRadiusMeters,
    required this.checkInEarlyMinutes,
    required this.graceMinutes,
    required this.monthlyGraceLimit,
    required this.valuesAreProposed,
  });

  final int storeRadiusMeters;
  final int checkInEarlyMinutes;
  final int graceMinutes;
  final int monthlyGraceLimit;

  /// These values are for the visual demo only until the SRS decisions are
  /// approved and validated against the backend policy.
  final bool valuesAreProposed;
}

class DemoDevice {
  const DemoDevice({
    required this.name,
    required this.status,
    required this.isPrimary,
  });

  final String name;
  final DemoDeviceStatus status;
  final bool isPrimary;
}

class DemoTrainingCourse {
  const DemoTrainingCourse({
    required this.title,
    required this.category,
    required this.progressPercent,
    required this.isMandatory,
    required this.blocksShiftAssignment,
    required this.status,
    required this.dueDate,
  });

  final String title;
  final String category;
  final int progressPercent;
  final bool isMandatory;
  final bool blocksShiftAssignment;
  final DemoTrainingStatus status;
  final String dueDate;
}

class DemoManagerSkill {
  const DemoManagerSkill({
    required this.name,
    required this.levelLabel,
    required this.scorePercent,
    required this.evaluatedAt,
  });

  final String name;
  final String levelLabel;
  final int scorePercent;
  final String evaluatedAt;
}

class DemoChecklistTask {
  const DemoChecklistTask({
    required this.title,
    required this.status,
    required this.dueTime,
    required this.evidenceRequired,
    required this.managerApprovalRequired,
    this.reviewReason,
  });

  final String title;
  final DemoChecklistStatus status;
  final String dueTime;
  final bool evidenceRequired;
  final bool managerApprovalRequired;
  final String? reviewReason;
}

enum DemoManagerReviewStatus {
  pendingManager,
  pendingHr,
  approved,
  rejected,
}

class DemoAttendanceAdjustmentRequest {
  const DemoAttendanceAdjustmentRequest({
    required this.id,
    required this.employeeName,
    required this.employeeCode,
    required this.position,
    required this.workDate,
    required this.adjustmentLabel,
    required this.requestedValue,
    required this.reason,
    required this.evidenceLabel,
    required this.submittedAt,
    this.status = DemoManagerReviewStatus.pendingManager,
  });

  final String id;
  final String employeeName;
  final String employeeCode;
  final String position;
  final String workDate;
  final String adjustmentLabel;
  final String requestedValue;
  final String reason;
  final String evidenceLabel;
  final String submittedAt;
  final DemoManagerReviewStatus status;
}

enum DemoManagerRequestType { gpsException, deviceChange, overtime }

class DemoManagerRequest {
  const DemoManagerRequest({
    required this.id,
    required this.employeeName,
    required this.employeeCode,
    required this.position,
    required this.type,
    required this.detail,
    required this.reason,
    required this.evidenceLabel,
    required this.submittedAt,
    this.status = DemoManagerReviewStatus.pendingManager,
    this.reviewReason,
  });

  final String id;
  final String employeeName;
  final String employeeCode;
  final String position;
  final DemoManagerRequestType type;
  final String detail;
  final String reason;
  final String evidenceLabel;
  final String submittedAt;
  final DemoManagerReviewStatus status;
  final String? reviewReason;
}

class DemoChecklistReview {
  const DemoChecklistReview({
    required this.id,
    required this.employeeName,
    required this.employeeCode,
    required this.checklistTitle,
    required this.taskTitle,
    required this.workDate,
    required this.shiftTime,
    required this.evidenceLabel,
    required this.submittedAt,
    this.status = DemoManagerReviewStatus.pendingManager,
  });

  final String id;
  final String employeeName;
  final String employeeCode;
  final String checklistTitle;
  final String taskTitle;
  final String workDate;
  final String shiftTime;
  final String evidenceLabel;
  final String submittedAt;
  final DemoManagerReviewStatus status;
}

class DemoAttendanceReport {
  const DemoAttendanceReport({
    required this.monthLabel,
    required this.totalShifts,
    required this.lateCount,
    required this.absentCount,
    required this.violationCount,
    required this.missingCheckOutCount,
    required this.verificationPendingCount,
    required this.totalLateMinutes,
    required this.dailyRates,
    this.shiftLabel = 'Tất cả ca',
  });

  final String monthLabel;
  final String shiftLabel;
  final int totalShifts;
  final int lateCount;
  final int absentCount;
  final int violationCount;
  final int missingCheckOutCount;
  final int verificationPendingCount;
  final int totalLateMinutes;
  final List<int> dailyRates;
}

class DemoNotice {
  const DemoNotice({
    required this.title,
    required this.message,
    required this.category,
    required this.timeLabel,
    required this.isRead,
  });

  final String title;
  final String message;
  final String category;
  final String timeLabel;
  final bool isRead;
}

abstract final class DemoData {
  static const demoDate = 'Thứ Ba, 13/10/2026';
  static const storeName = 'HRM Coffee Shop';
  static const storeBranch = 'Chi nhánh trung tâm';
  static const storeLocationLabel = 'Khu vực cửa hàng';

  static const employee = DemoEmployee(
    fullName: 'Nguyễn Văn An',
    employeeCode: 'NV0012',
    email: 'an.nguyen@coffee.vn',
    phone: '0901 234 567',
    position: 'Nhân viên phục vụ',
    employmentStatus: 'Đang làm việc',
    hireDate: '01/06/2026',
  );

  static const managerEmployees = <DemoManagerEmployee>[
    DemoManagerEmployee(
      name: 'Nguyễn Văn An',
      employeeCode: 'NV0012',
      position: 'Nhân viên phục vụ',
      initials: 'AN',
      status: DemoManagerEmployeeStatus.working,
      avatarColorValue: 0xFFEAD9CC,
    ),
    DemoManagerEmployee(
      name: 'Trần Văn Bình',
      employeeCode: 'NV0013',
      position: 'Nhân viên pha chế',
      initials: 'TB',
      status: DemoManagerEmployeeStatus.working,
      avatarColorValue: 0xFFDCE9E2,
    ),
    DemoManagerEmployee(
      name: 'Lê Thị Hương',
      employeeCode: 'NV0014',
      position: 'Nhân viên phục vụ',
      initials: 'LH',
      status: DemoManagerEmployeeStatus.working,
      avatarColorValue: 0xFFE7E0F0,
    ),
    DemoManagerEmployee(
      name: 'Phạm Quang Minh',
      employeeCode: 'NV0015',
      position: 'Thu ngân',
      initials: 'PM',
      status: DemoManagerEmployeeStatus.working,
      avatarColorValue: 0xFFF1E4C9,
    ),
    DemoManagerEmployee(
      name: 'Hoàng Thị Lan',
      employeeCode: 'NV0016',
      position: 'Nhân viên pha chế',
      initials: 'HL',
      status: DemoManagerEmployeeStatus.working,
      avatarColorValue: 0xFFF2DCD8,
    ),
    DemoManagerEmployee(
      name: 'Vũ Thị Ngọc',
      employeeCode: 'NV0017',
      position: 'Nhân viên phục vụ',
      initials: 'VN',
      status: DemoManagerEmployeeStatus.working,
      avatarColorValue: 0xFFDCE9E2,
    ),
    DemoManagerEmployee(
      name: 'Nguyễn Minh Tuấn',
      employeeCode: 'NV0018',
      position: 'Nhân viên phục vụ',
      initials: 'NT',
      status: DemoManagerEmployeeStatus.working,
      avatarColorValue: 0xFFEAD9CC,
    ),
    DemoManagerEmployee(
      name: 'Lâm Thị Thảo',
      employeeCode: 'NV0019',
      position: 'Thu ngân',
      initials: 'LT',
      status: DemoManagerEmployeeStatus.working,
      avatarColorValue: 0xFFE7E0F0,
    ),
    DemoManagerEmployee(
      name: 'Đặng Quốc Huy',
      employeeCode: 'NV0020',
      position: 'Nhân viên pha chế',
      initials: 'DH',
      status: DemoManagerEmployeeStatus.working,
      avatarColorValue: 0xFFF1E4C9,
    ),
    DemoManagerEmployee(
      name: 'Bùi Thị Mai',
      employeeCode: 'NV0021',
      position: 'Nhân viên phục vụ',
      initials: 'BM',
      status: DemoManagerEmployeeStatus.working,
      avatarColorValue: 0xFFF2DCD8,
    ),
    DemoManagerEmployee(
      name: 'Đoàn Văn Nam',
      employeeCode: 'NV0022',
      position: 'Nhân viên phục vụ',
      initials: 'DN',
      status: DemoManagerEmployeeStatus.working,
      avatarColorValue: 0xFFDCE9E2,
    ),
    DemoManagerEmployee(
      name: 'Võ Thanh Hà',
      employeeCode: 'NV0023',
      position: 'Nhân viên pha chế',
      initials: 'VH',
      status: DemoManagerEmployeeStatus.working,
      avatarColorValue: 0xFFEAD9CC,
    ),
    DemoManagerEmployee(
      name: 'Hà Gia Bảo',
      employeeCode: 'NV0024',
      position: 'Nhân viên phục vụ',
      initials: 'HB',
      status: DemoManagerEmployeeStatus.paused,
      avatarColorValue: 0xFFE7E0F0,
    ),
    DemoManagerEmployee(
      name: 'Phan Thị Linh',
      employeeCode: 'NV0025',
      position: 'Thu ngân',
      initials: 'PL',
      status: DemoManagerEmployeeStatus.paused,
      avatarColorValue: 0xFFF1E4C9,
    ),
    DemoManagerEmployee(
      name: 'Trịnh Gia Hân',
      employeeCode: 'NV0026',
      position: 'Nhân viên phục vụ',
      initials: 'TH',
      status: DemoManagerEmployeeStatus.onLeave,
      avatarColorValue: 0xFFF2DCD8,
    ),
  ];

  static const attendancePolicy = DemoAttendancePolicy(
    storeRadiusMeters: 30,
    checkInEarlyMinutes: 15,
    graceMinutes: 5,
    monthlyGraceLimit: 3,
    valuesAreProposed: true,
  );

  static const currentShift = DemoShiftAssignment(
    workDate: '2026-10-13',
    dayLabel: 'Thứ Ba, 13/10/2026',
    shiftName: 'Ca sáng',
    startTime: '08:00',
    endTime: '16:00',
    workArea: 'Khu vực phục vụ',
    assignmentStatus: 'Đã phân',
  );

  static const managerShiftRoster = <DemoManagerShiftRosterRow>[
    DemoManagerShiftRosterRow(
      employeeName: 'Nguyễn Văn An',
      employeeCode: 'NV0012',
      position: 'Nhân viên phục vụ',
      initials: 'AN',
      shifts: [
        DemoRosterShift.morning,
        DemoRosterShift.afternoon,
        DemoRosterShift.morning,
        DemoRosterShift.off,
        DemoRosterShift.afternoon,
        DemoRosterShift.morning,
        DemoRosterShift.afternoon,
      ],
    ),
    DemoManagerShiftRosterRow(
      employeeName: 'Trần Văn Bình',
      employeeCode: 'NV0013',
      position: 'Nhân viên pha chế',
      initials: 'TB',
      shifts: [
        DemoRosterShift.afternoon,
        DemoRosterShift.morning,
        DemoRosterShift.morning,
        DemoRosterShift.afternoon,
        DemoRosterShift.off,
        DemoRosterShift.afternoon,
        DemoRosterShift.morning,
      ],
    ),
    DemoManagerShiftRosterRow(
      employeeName: 'Lê Thị Hương',
      employeeCode: 'NV0014',
      position: 'Nhân viên phục vụ',
      initials: 'LH',
      shifts: [
        DemoRosterShift.morning,
        DemoRosterShift.afternoon,
        DemoRosterShift.leave,
        DemoRosterShift.morning,
        DemoRosterShift.afternoon,
        DemoRosterShift.off,
        DemoRosterShift.afternoon,
      ],
    ),
    DemoManagerShiftRosterRow(
      employeeName: 'Phạm Quang Minh',
      employeeCode: 'NV0015',
      position: 'Thu ngân',
      initials: 'PM',
      shifts: [
        DemoRosterShift.afternoon,
        DemoRosterShift.off,
        DemoRosterShift.morning,
        DemoRosterShift.afternoon,
        DemoRosterShift.morning,
        DemoRosterShift.afternoon,
        DemoRosterShift.off,
      ],
    ),
    DemoManagerShiftRosterRow(
      employeeName: 'Hoàng Thị Lan',
      employeeCode: 'NV0016',
      position: 'Nhân viên pha chế',
      initials: 'HL',
      shifts: [
        DemoRosterShift.off,
        DemoRosterShift.afternoon,
        DemoRosterShift.morning,
        DemoRosterShift.morning,
        DemoRosterShift.leave,
        DemoRosterShift.afternoon,
        DemoRosterShift.morning,
      ],
    ),
  ];

  static const upcomingShifts = <DemoShiftAssignment>[
    currentShift,
    DemoShiftAssignment(
      workDate: '2026-10-14',
      dayLabel: 'Thứ Tư, 14/10/2026',
      shiftName: 'Ca chiều',
      startTime: '16:00',
      endTime: '22:00',
      workArea: 'Khu vực phục vụ',
      assignmentStatus: 'Đã phân',
    ),
    DemoShiftAssignment(
      workDate: '2026-10-15',
      dayLabel: 'Thứ Năm, 15/10/2026',
      shiftName: 'Ca sáng',
      startTime: '08:00',
      endTime: '16:00',
      workArea: 'Khu vực phục vụ',
      assignmentStatus: 'Đã phân',
    ),
    DemoShiftAssignment(
      workDate: '2026-10-16',
      dayLabel: 'Thứ Sáu, 16/10/2026',
      shiftName: 'Ca nghỉ',
      startTime: '',
      endTime: '',
      workArea: '',
      assignmentStatus: 'Ngày nghỉ',
    ),
    DemoShiftAssignment(
      workDate: '2026-10-17',
      dayLabel: 'Thứ Bảy, 17/10/2026',
      shiftName: 'Ca chiều',
      startTime: '16:00',
      endTime: '22:00',
      workArea: 'Khu vực phục vụ',
      assignmentStatus: 'Chờ duyệt',
    ),
  ];

  /// Weekly personal schedule sample anchored at Tuesday, 13/10/2026.
  static const employeeScheduleAnchorDate = '2026-10-13';
  static const employeeScheduleShifts = <DemoShiftAssignment>[
    DemoShiftAssignment(
      workDate: '2026-10-13',
      dayLabel: 'Thứ Ba, 13/10/2026',
      shiftName: 'Ca sáng',
      startTime: '08:00',
      endTime: '16:00',
      workArea: 'Nhân viên phục vụ',
      assignmentStatus: 'Đã phân',
    ),
    DemoShiftAssignment(
      workDate: '2026-10-13',
      dayLabel: 'Thứ Ba, 13/10/2026',
      shiftName: 'Ca chiều',
      startTime: '16:00',
      endTime: '22:00',
      workArea: 'Nhân viên pha chế',
      assignmentStatus: 'Chờ duyệt',
    ),
    DemoShiftAssignment(
      workDate: '2026-10-14',
      dayLabel: 'Thứ Tư, 14/10/2026',
      shiftName: 'Ca chiều',
      startTime: '16:00',
      endTime: '22:00',
      workArea: 'Nhân viên phục vụ',
      assignmentStatus: 'Đã phân',
    ),
    DemoShiftAssignment(
      workDate: '2026-10-15',
      dayLabel: 'Thứ Năm, 15/10/2026',
      shiftName: 'Ca sáng',
      startTime: '08:00',
      endTime: '16:00',
      workArea: 'Nhân viên phục vụ',
      assignmentStatus: 'Đã phân',
    ),
    DemoShiftAssignment(
      workDate: '2026-10-16',
      dayLabel: 'Thứ Sáu, 16/10/2026',
      shiftName: 'Ca nghỉ',
      startTime: '',
      endTime: '',
      workArea: '',
      assignmentStatus: 'Ngày nghỉ',
    ),
    DemoShiftAssignment(
      workDate: '2026-10-17',
      dayLabel: 'Thứ Bảy, 17/10/2026',
      shiftName: 'Ca chiều',
      startTime: '16:00',
      endTime: '22:00',
      workArea: 'Nhân viên phục vụ',
      assignmentStatus: 'Đã phân',
    ),
    DemoShiftAssignment(
      workDate: '2026-10-18',
      dayLabel: 'Chủ Nhật, 18/10/2026',
      shiftName: 'Ca sáng',
      startTime: '08:00',
      endTime: '16:00',
      workArea: 'Nhân viên phục vụ',
      assignmentStatus: 'Đã phân',
    ),
    DemoShiftAssignment(
      workDate: '2026-10-19',
      dayLabel: 'Thứ Hai, 19/10/2026',
      shiftName: 'Ca chiều',
      startTime: '16:00',
      endTime: '22:00',
      workArea: 'Nhân viên phục vụ',
      assignmentStatus: 'Đã phân',
    ),
  ];

  static const attendanceStatus = DemoAttendanceStatus.notCheckedIn;
  static const lateMinutes = 7;
  static const locationDistanceMeters = 12;
  static const locationAccuracyMeters = 12.5;
  static const checkInPhotoLabel = 'Ảnh xác minh mẫu';

  static const device = DemoDevice(
    name: 'Thiết bị demo của Nguyễn Văn An',
    status: DemoDeviceStatus.active,
    isPrimary: true,
  );

  static const trainingCourses = <DemoTrainingCourse>[
    DemoTrainingCourse(
      title: 'An toàn thực phẩm',
      category: 'Bắt buộc',
      progressPercent: 100,
      isMandatory: true,
      blocksShiftAssignment: true,
      status: DemoTrainingStatus.complete,
      dueDate: '30/10/2026',
    ),
    DemoTrainingCourse(
      title: 'Quy trình phục vụ',
      category: 'Bắt buộc',
      progressPercent: 100,
      isMandatory: true,
      blocksShiftAssignment: true,
      status: DemoTrainingStatus.complete,
      dueDate: '24/10/2026',
    ),
    DemoTrainingCourse(
      title: 'Vệ sinh và an toàn lao động',
      category: 'Bắt buộc',
      progressPercent: 100,
      isMandatory: true,
      blocksShiftAssignment: true,
      status: DemoTrainingStatus.complete,
      dueDate: '31/10/2026',
    ),
    DemoTrainingCourse(
      title: 'Kỹ năng giao tiếp',
      category: 'Tùy chọn',
      progressPercent: 60,
      isMandatory: false,
      blocksShiftAssignment: false,
      status: DemoTrainingStatus.inProgress,
      dueDate: '30/11/2026',
    ),
  ];

  static const managerEmployeeSkills = <DemoManagerSkill>[
    DemoManagerSkill(
      name: 'Giao tiếp với khách hàng',
      levelLabel: 'Tốt',
      scorePercent: 92,
      evaluatedAt: '10/10/2026',
    ),
    DemoManagerSkill(
      name: 'Quy trình phục vụ',
      levelLabel: 'Tốt',
      scorePercent: 88,
      evaluatedAt: '10/10/2026',
    ),
    DemoManagerSkill(
      name: 'Phối hợp nhóm',
      levelLabel: 'Khá',
      scorePercent: 84,
      evaluatedAt: '10/10/2026',
    ),
  ];

  static const checklistTasks = <DemoChecklistTask>[
    DemoChecklistTask(
      title: 'Kiểm tra khu vực quầy',
      status: DemoChecklistStatus.approved,
      dueTime: '07:15',
      evidenceRequired: true,
      managerApprovalRequired: false,
    ),
    DemoChecklistTask(
      title: 'Kiểm tra máy pha cà phê',
      status: DemoChecklistStatus.approved,
      dueTime: '07:20',
      evidenceRequired: true,
      managerApprovalRequired: false,
    ),
    DemoChecklistTask(
      title: 'Vệ sinh khu vực bàn ghế',
      status: DemoChecklistStatus.inProgress,
      dueTime: '07:30',
      evidenceRequired: true,
      managerApprovalRequired: false,
    ),
    DemoChecklistTask(
      title: 'Kiểm tra nguyên liệu',
      status: DemoChecklistStatus.pending,
      dueTime: '07:35',
      evidenceRequired: true,
      managerApprovalRequired: true,
    ),
  ];

  static const managerAttendanceAdjustmentRequests =
      <DemoAttendanceAdjustmentRequest>[
    DemoAttendanceAdjustmentRequest(
      id: 'adjustment-001',
      employeeName: 'Trần Văn Bình',
      employeeCode: 'NV0013',
      position: 'Nhân viên pha chế',
      workDate: '14/10/2026',
      adjustmentLabel: 'Giờ check-out đề nghị',
      requestedValue: '22:05',
      reason: 'Quên check-out khi kết thúc ca.',
      evidenceLabel: 'Ảnh minh chứng mẫu',
      submittedAt: '15/10/2026 · 08:10',
    ),
    DemoAttendanceAdjustmentRequest(
      id: 'adjustment-002',
      employeeName: 'Lê Thị Hương',
      employeeCode: 'NV0014',
      position: 'Nhân viên phục vụ',
      workDate: '13/10/2026',
      adjustmentLabel: 'Giờ check-in đề nghị',
      requestedValue: '08:05',
      reason: 'GPS mất tín hiệu lúc check-in.',
      evidenceLabel: 'Ảnh minh chứng mẫu',
      submittedAt: '13/10/2026 · 09:15',
      status: DemoManagerReviewStatus.pendingHr,
    ),
  ];

  static const managerOtherRequests = <DemoManagerRequest>[
    DemoManagerRequest(
      id: 'gps-001',
      employeeName: 'Nguyễn Văn An',
      employeeCode: 'NV0012',
      position: 'Nhân viên phục vụ',
      type: DemoManagerRequestType.gpsException,
      detail: 'Check-in ca sáng · 13/10/2026 · GPS không khả dụng',
      reason: 'Điện thoại không lấy được vị trí khi check-in.',
      evidenceLabel: 'Minh chứng ảnh mẫu',
      submittedAt: '13/10/2026 · 08:08',
    ),
    DemoManagerRequest(
      id: 'device-001',
      employeeName: 'Trần Văn Bình',
      employeeCode: 'NV0013',
      position: 'Nhân viên pha chế',
      type: DemoManagerRequestType.deviceChange,
      detail: 'Đăng ký thiết bị Android mới',
      reason: 'Điện thoại cũ bị hỏng, cần đăng ký thiết bị thay thế.',
      evidenceLabel: 'Thiết bị Android',
      submittedAt: '13/10/2026 · 09:20',
    ),
    DemoManagerRequest(
      id: 'overtime-001',
      employeeName: 'Lê Thị Hương',
      employeeCode: 'NV0014',
      position: 'Nhân viên phục vụ',
      type: DemoManagerRequestType.overtime,
      detail: 'Ca 16:00–22:00 · OT đề nghị 22:00–23:00',
      reason: 'Ở lại hỗ trợ bàn giao cuối ca.',
      evidenceLabel: 'Không có tệp đính kèm',
      submittedAt: '12/10/2026 · 21:45',
      status: DemoManagerReviewStatus.rejected,
      reviewReason: 'Yêu cầu OT cần được gửi trước khi phát sinh.',
    ),
  ];

  static const managerChecklistReviews = <DemoChecklistReview>[
    DemoChecklistReview(
      id: 'checklist-review-001',
      employeeName: 'Nguyễn Văn An',
      employeeCode: 'NV0012',
      checklistTitle: 'Checklist đầu ca',
      taskTitle: 'Kiểm tra khu vực quầy',
      workDate: '13/10/2026',
      shiftTime: '08:00 - 16:00',
      evidenceLabel: '2 ảnh minh chứng mẫu',
      submittedAt: '13/10/2026 · 08:05',
    ),
    DemoChecklistReview(
      id: 'checklist-review-002',
      employeeName: 'Trần Văn Bình',
      employeeCode: 'NV0013',
      checklistTitle: 'Checklist cuối ca',
      taskTitle: 'Vệ sinh máy pha cà phê',
      workDate: '12/10/2026',
      shiftTime: '16:00 - 22:00',
      evidenceLabel: '1 ảnh minh chứng mẫu',
      submittedAt: '12/10/2026 · 22:10',
    ),
    DemoChecklistReview(
      id: 'checklist-review-003',
      employeeName: 'Lê Thị Hương',
      employeeCode: 'NV0014',
      checklistTitle: 'Checklist đầu ca',
      taskTitle: 'Kiểm tra nguyên liệu',
      workDate: '13/10/2026',
      shiftTime: '08:00 - 16:00',
      evidenceLabel: '1 ảnh minh chứng mẫu',
      submittedAt: '13/10/2026 · 08:12',
    ),
    DemoChecklistReview(
      id: 'checklist-review-004',
      employeeName: 'Phạm Quang Minh',
      employeeCode: 'NV0015',
      checklistTitle: 'Checklist cuối ca',
      taskTitle: 'Bàn giao quỹ ca',
      workDate: '11/10/2026',
      shiftTime: '16:00 - 22:00',
      evidenceLabel: '2 ảnh minh chứng mẫu',
      submittedAt: '11/10/2026 · 22:05',
      status: DemoManagerReviewStatus.approved,
    ),
  ];

  static const managerAttendanceReport = DemoAttendanceReport(
    monthLabel: 'Tháng 10/2026',
    totalShifts: 312,
    lateCount: 18,
    absentCount: 4,
    violationCount: 6,
    missingCheckOutCount: 3,
    verificationPendingCount: 3,
    totalLateMinutes: 185,
    dailyRates: [
      78, 84, 80, 86, 82, 88, 79, 83, 91, 76,
      87, 85, 81, 90, 84, 78, 88, 82, 86, 80,
      89, 83, 77, 85, 91, 82, 87, 79, 84, 88,
    ],
  );

  static const _octoberMorningRates = <int>[
    82, 86, 83, 89, 85, 91, 81, 86, 94, 79,
    88, 87, 83, 92, 86, 81, 90, 84, 89, 83,
    92, 85, 80, 88, 94, 84, 90, 82, 87, 91,
  ];

  static const _octoberAfternoonRates = <int>[
    74, 81, 77, 83, 79, 85, 76, 80, 88, 72,
    84, 82, 78, 87, 81, 75, 86, 79, 83, 77,
    85, 80, 74, 82, 89, 78, 84, 76, 81, 86,
  ];

  static const _septemberAllRates = <int>[
    76, 82, 79, 85, 80, 87, 78, 82, 89, 74,
    85, 83, 80, 88, 82, 77, 86, 80, 84, 78,
    87, 81, 75, 83, 90, 80, 85, 77, 82, 86,
  ];

  static const _septemberMorningRates = <int>[
    80, 85, 82, 88, 83, 90, 80, 84, 92, 78,
    87, 85, 82, 91, 85, 79, 89, 83, 87, 81,
    90, 84, 79, 87, 93, 83, 89, 80, 86, 90,
  ];

  static const _septemberAfternoonRates = <int>[
    72, 79, 75, 82, 77, 84, 74, 78, 86, 70,
    82, 80, 76, 85, 79, 73, 83, 77, 81, 75,
    84, 78, 72, 80, 87, 76, 82, 74, 79, 84,
  ];

  static const managerAttendanceReports = <DemoAttendanceReport>[
    managerAttendanceReport,
    DemoAttendanceReport(
      monthLabel: 'Tháng 10/2026',
      shiftLabel: 'Ca sáng',
      totalShifts: 156,
      lateCount: 8,
      absentCount: 1,
      violationCount: 2,
      missingCheckOutCount: 1,
      verificationPendingCount: 2,
      totalLateMinutes: 82,
      dailyRates: _octoberMorningRates,
    ),
    DemoAttendanceReport(
      monthLabel: 'Tháng 10/2026',
      shiftLabel: 'Ca chiều',
      totalShifts: 156,
      lateCount: 10,
      absentCount: 3,
      violationCount: 4,
      missingCheckOutCount: 2,
      verificationPendingCount: 1,
      totalLateMinutes: 103,
      dailyRates: _octoberAfternoonRates,
    ),
    DemoAttendanceReport(
      monthLabel: 'Tháng 9/2026',
      totalShifts: 298,
      lateCount: 16,
      absentCount: 3,
      violationCount: 5,
      missingCheckOutCount: 2,
      verificationPendingCount: 2,
      totalLateMinutes: 165,
      dailyRates: _septemberAllRates,
    ),
    DemoAttendanceReport(
      monthLabel: 'Tháng 9/2026',
      shiftLabel: 'Ca sáng',
      totalShifts: 148,
      lateCount: 7,
      absentCount: 1,
      violationCount: 2,
      missingCheckOutCount: 1,
      verificationPendingCount: 1,
      totalLateMinutes: 70,
      dailyRates: _septemberMorningRates,
    ),
    DemoAttendanceReport(
      monthLabel: 'Tháng 9/2026',
      shiftLabel: 'Ca chiều',
      totalShifts: 150,
      lateCount: 9,
      absentCount: 2,
      violationCount: 3,
      missingCheckOutCount: 1,
      verificationPendingCount: 1,
      totalLateMinutes: 95,
      dailyRates: _septemberAfternoonRates,
    ),
  ];

  static const notifications = <DemoNotice>[
    DemoNotice(
      title: 'Ca làm hôm nay',
      message: 'Ca sáng của bạn bắt đầu lúc 08:00.',
      category: 'Lịch làm',
      timeLabel: '2 giờ trước',
      isRead: false,
    ),
    DemoNotice(
      title: 'Checklist chưa hoàn thành',
      message: 'Vui lòng hoàn thành checklist đầu ca.',
      category: 'Checklist',
      timeLabel: '1 giờ trước',
      isRead: false,
    ),
    DemoNotice(
      title: 'Khóa học sắp hết hạn',
      message: 'Kiểm tra hạn hiệu lực khóa học của bạn.',
      category: 'Đào tạo',
      timeLabel: 'Hôm qua',
      isRead: true,
    ),
  ];
}
