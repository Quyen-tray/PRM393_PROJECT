package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.shared.dto.AttendanceDto.AttendanceView;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.CheckInRequest;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.CheckInResponse;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.CheckOutRequest;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.CheckOutResponse;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.CurrentShiftView;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.FaceVerification;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.LocationDto;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.PhotoEvidence;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.VerificationView;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.ShiftChoice;

import com.hrm.coffeeshop.common.*;
import com.hrm.coffeeshop.config.AppProperties;
import com.hrm.coffeeshop.domain.*;
import com.hrm.coffeeshop.repository.*;
import org.springframework.data.domain.Pageable;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.util.*;
import java.util.regex.Pattern;

@Service
public class AttendanceService {

    private final AttendanceRepository attendance;
    private final AttendanceVerificationRepository evidences;
    private final ShiftAssignmentRepository schedules;
    private final WorkShiftRepository shifts;
    private final EmployeeRepository employees;
    private final AttendanceAdjustmentRequestRepository adjustments;
    private final DeviceService devices;
    private final TrainingService training;
    private final StoreService storeService;
    private final AttendanceMetricsService metrics;
    private final FaceVerificationClient face;
    private final StorageGateway storage;
    private final ViolationService violations;
    private final PersonLookup people;
    private final AuditService audit;
    private final AppProperties props;
    private final PayrollLockGuard lockGuard;
    private final VerificationAttemptRecorder attemptRecorder;
    private final Clock clock;
    private final AttendancePhotoPolicy photoPolicy;
    private final boolean flexibleTesting;

    public AttendanceService(AttendanceRepository attendance, AttendanceVerificationRepository evidences,
                             ShiftAssignmentRepository schedules, WorkShiftRepository shifts,
                             EmployeeRepository employees, AttendanceAdjustmentRequestRepository adjustments,
                             DeviceService devices, TrainingService training, StoreService storeService,
                             AttendanceMetricsService metrics, FaceVerificationClient face,
                             StorageGateway storage, ViolationService violations, PersonLookup people,
                             AuditService audit, AppProperties props, PayrollLockGuard lockGuard, VerificationAttemptRecorder attemptRecorder, Clock clock,
                             AttendancePhotoPolicy photoPolicy,
                             @Value("${app.attendance.flexible-testing-enabled:false}") boolean flexibleTesting) {
        this.attendance = attendance;
        this.evidences = evidences;
        this.schedules = schedules;
        this.shifts = shifts;
        this.employees = employees;
        this.adjustments = adjustments;
        this.devices = devices;
        this.training = training;
        this.storeService = storeService;
        this.metrics = metrics;
        this.face = face;
        this.storage = storage;
        this.violations = violations;
        this.people = people;
        this.audit = audit;
        this.props = props;
        this.lockGuard = lockGuard;
        this.attemptRecorder = attemptRecorder;
        this.clock = clock;
        this.photoPolicy = photoPolicy;
        this.flexibleTesting = flexibleTesting;
    }

    private record Geo(BigDecimal lat, BigDecimal lon, BigDecimal accuracy, double distance) {}

    // =============================== CHECK-IN ===============================
    @Transactional
    public CheckInResponse checkIn(CheckInRequest r) {
        Long empId = SecurityUtils.requireEmployeeId();
        Employee emp = employees.findById(empId).orElseThrow(() -> BusinessException.notFound("nhân viên"));
        if (!flexibleTesting && !"ACTIVE".equals(emp.getEmploymentStatus()))
            throw BusinessException.forbidden("Nhân viên không ở trạng thái đang làm việc");
        ShiftAssignment sc = schedules.findById(r.shiftAssignmentId()).filter(s -> s.getEmployeeId().equals(empId))
                .orElseThrow(() -> new BusinessException(ErrorCode.SHIFT_NOT_FOUND, "Không tìm thấy ca làm"));

        // Khóa kỳ công TRƯỚC khi nạp bản ghi công: bản ghi có thể được tạo hoặc cập nhật ngay bên dưới.
        if (!flexibleTesting) lockGuard.assertWorkDateOpen(sc.getWorkDate());
        Optional<Attendance> existing = attendance.findByShiftAssignmentId(sc.getShiftAssignmentId());
        if (existing.isPresent() && existing.get().getCheckInAt() != null) {
            Attendance ex = existing.get();
            if (r.idempotencyKey() != null && r.idempotencyKey().equals(ex.getCheckInIdempotencyKey()))
                return checkInResponse(ex);                        // retry an toàn (TC19)
            throw new BusinessException(ErrorCode.ATTENDANCE_ALREADY_CHECKED_IN, "Bạn đã check-in ca này",
                    BusinessException.details("attendanceId", ex.getAttendanceId()));
        }
        if (!"PUBLISHED".equals(sc.getScheduleStatus()))
            throw new BusinessException(ErrorCode.SHIFT_NOT_FOUND, "Ca làm không còn hiệu lực");
        WorkShift sh = shifts.findById(sc.getWorkShiftId()).orElseThrow();

        Instant now = clock.instant();                              // thời gian server là nguồn duy nhất
        Instant opens = sc.getPlannedStartAt().minus(Duration.ofMinutes(sh.getEarlyCheckInMinutes()));
        if (!flexibleTesting && now.isBefore(opens))
            throw new BusinessException(ErrorCode.CHECK_IN_TOO_EARLY, "Chưa đến thời gian check-in",
                    BusinessException.details("checkInOpensAt", TimeUtils.vn(opens)));
        if (!flexibleTesting && now.isAfter(sc.getPlannedEndAt()))
            throw new BusinessException(ErrorCode.CHECK_IN_WINDOW_CLOSED, "Ca làm đã kết thúc, hãy gửi giải trình");

        TrainingService.Eligibility el = training.eligibility(emp);
        if (!flexibleTesting && !el.eligible())
            throw new BusinessException(ErrorCode.EMPLOYEE_NOT_ELIGIBLE_FOR_SHIFT, "Chưa hoàn thành đào tạo bắt buộc",
                    BusinessException.details("restrictions", el.restrictions()));
        devices.requireActive(empId, r.deviceId());
        Geo geo = gpsOrRecord(r.location(), now, sc.getShiftAssignmentId(), empId, "CHECK_IN", r.deviceId());
        String photoKey = requirePhoto(r.photoEvidence(), photoPolicy.required(empId, sc.getShiftAssignmentId(), "CHECK_IN"));
        FaceVerificationClient.Result fr = faceOrRecord(r.faceVerification(), photoKey, empId, sc.getShiftAssignmentId(), "CHECK_IN", r.deviceId(), now);

        Attendance a = existing.orElseGet(Attendance::new);
        a.setShiftAssignmentId(sc.getShiftAssignmentId());
        a.setEmployeeId(empId);
        a.setCheckInAt(now);
        a.setCheckInLatitude(geo.lat());
        a.setCheckInLongitude(geo.lon());
        a.setCheckInAccuracyM(geo.accuracy());
        a.setCheckInMethod("GPS");
        a.setCheckInFaceStatus(fr.matchStatus());
        a.setCheckInDeviceId(r.deviceId());
        a.setCheckInIdempotencyKey(r.idempotencyKey());
        a.setAttendanceStatus("IN_PROGRESS");
        metrics.apply(a, sc, sh);
        try {
            attendance.saveAndFlush(a);     // flush ngay để vi phạm unique theo ca lộ ra tại đây
        } catch (org.springframework.dao.DataIntegrityViolationException dup) {
            // Hai request check-in đồng thời cùng ca: request thua nhận mã nghiệp vụ thay vì lỗi DB chung.
            // Retry tuần tự với cùng idempotencyKey sẽ được nhánh "đã check-in" ở đầu hàm xử lý idempotent.
            String m = dup.getMostSpecificCause().getMessage();
            m = m == null ? "" : m.toLowerCase();
            if (existing.isEmpty() && (m.contains("unique") || m.contains("duplicate")))
                throw new BusinessException(ErrorCode.ATTENDANCE_ALREADY_CHECKED_IN, "Bạn đã check-in ca này");
            throw dup;
        }
        saveVerifications(a, "CHECK_IN", r.deviceId(), photoKey, geo, fr, now);
        if (a.getLateMinutes() > 0) violations.recordLate(emp, a.getAttendanceId(), a.getLateMinutes());
        audit.log("ATTENDANCE_CHECK_IN", "Attendance", a.getAttendanceId(), null,
                Map.of("scheduleId", sc.getShiftAssignmentId(), "late", a.getLateMinutes(), "distanceM", Math.round(geo.distance())));
        return checkInResponse(a);
    }

    private CheckInResponse checkInResponse(Attendance a) {
        return new CheckInResponse(a.getAttendanceId(), a.getShiftAssignmentId(), TimeUtils.vn(a.getCheckInAt()), "CHECKED_IN",
                "REVIEW".equals(a.getCheckInFaceStatus()) ? "REVIEW_REQUIRED" : "PASSED", a.getLateMinutes(),
                Boolean.TRUE.equals(a.getGraceApplied()));
    }

    // =============================== CHECK-OUT ===============================
    @Transactional
    public CheckOutResponse checkOut(CheckOutRequest r) {
        Long empId = SecurityUtils.requireEmployeeId();
        LocalDate workDate = attendance.findWorkDateOfAttendance(r.attendanceId(), empId)
                .orElseThrow(() -> BusinessException.notFound("bản ghi chấm công"));
        if (!flexibleTesting) lockGuard.assertWorkDateOpen(workDate);
        Attendance a = attendance.findById(r.attendanceId()).filter(x -> x.getEmployeeId().equals(empId))
                .orElseThrow(() -> BusinessException.notFound("bản ghi chấm công"));
        ShiftAssignment sc = schedules.findById(a.getShiftAssignmentId()).orElseThrow();
        WorkShift sh = shifts.findById(sc.getWorkShiftId()).orElseThrow();
        if (a.getCheckInAt() == null)
            throw new BusinessException(ErrorCode.ATTENDANCE_NOT_CHECKED_IN, "Bạn chưa check-in ca này");
        if (a.getCheckOutAt() != null) {
            if (r.idempotencyKey() != null && r.idempotencyKey().equals(a.getCheckOutIdempotencyKey()))
                return checkOutResponse(a, sc);
            throw new BusinessException(ErrorCode.ATTENDANCE_ALREADY_CHECKED_OUT, "Bạn đã check-out ca này");
        }
        if (!flexibleTesting) assertNotLocked(a);
        Instant now = clock.instant();
        devices.requireActive(empId, r.deviceId());
        Geo geo = gpsOrRecord(r.location(), now, sc.getShiftAssignmentId(), empId, "CHECK_OUT", r.deviceId());
        String photoKey = requirePhoto(r.photoEvidence(), photoPolicy.required(empId, sc.getShiftAssignmentId(), "CHECK_OUT"));
        FaceVerificationClient.Result fr = faceOrRecord(r.faceVerification(), photoKey, empId, sc.getShiftAssignmentId(), "CHECK_OUT", r.deviceId(), now);

        a.setCheckOutAt(now.isBefore(a.getCheckInAt()) ? a.getCheckInAt() : now);
        a.setCheckOutLatitude(geo.lat());
        a.setCheckOutLongitude(geo.lon());
        a.setCheckOutAccuracyM(geo.accuracy());
        a.setCheckOutMethod("GPS");
        a.setCheckOutFaceStatus(fr.matchStatus());
        a.setCheckOutDeviceId(r.deviceId());
        a.setCheckOutIdempotencyKey(r.idempotencyKey());
        metrics.apply(a, sc, sh);
        attendance.save(a);
        saveVerifications(a, "CHECK_OUT", r.deviceId(), photoKey, geo, fr, now);
        audit.log("ATTENDANCE_CHECK_OUT", "Attendance", a.getAttendanceId(), null,
                Map.of("worked", a.getWorkedMinutes(), "early", a.getEarlyLeaveMinutes(), "approvedOt", a.getApprovedOTMinutes()));
        return checkOutResponse(a, sc);
    }

    private CheckOutResponse checkOutResponse(Attendance a, ShiftAssignment sc) {
        long presence = TimeUtils.minutes(a.getCheckInAt(), a.getCheckOutAt());
        return new CheckOutResponse(a.getAttendanceId(), TimeUtils.vn(a.getCheckOutAt()), "CHECKED_OUT",
                a.getWorkedMinutes() == null ? 0 : a.getWorkedMinutes(), presence, metrics.rawOvertimeMinutes(a, sc),
                a.getApprovedOTMinutes(), a.getEarlyLeaveMinutes());
    }

    // =============================== XÁC MINH ===============================
    /** B-17: GPS thất bại được ghi nhận (transaction riêng) rồi mới ném lại lỗi cho người dùng. */
    private Geo gpsOrRecord(LocationDto loc, Instant now, Long shiftId, Long empId, String event, Long deviceId) {
        try {
            return verifyGps(loc, now);
        } catch (BusinessException e) {
            attemptRecorder.record(empId, shiftId, event, "GPS", e.getCode().name(), deviceId, now);
            throw e;
        }
    }

    private FaceVerificationClient.Result faceOrRecord(FaceVerification fv, String photoKey, Long empId, Long shiftId,
                                                       String event, Long deviceId, Instant now) {
        if (photoKey == null) return new FaceVerificationClient.Result("NOT_RUN", "NOT_RUN", null);
        try {
            return verifyFace(fv, photoKey, empId);
        } catch (BusinessException e) {
            attemptRecorder.record(empId, shiftId, event, "FACE", e.getCode().name(), deviceId, now);
            throw e;
        }
    }

    private Geo verifyGps(LocationDto loc, Instant now) {
        if (loc == null || loc.latitude() == null || loc.longitude() == null)
            throw new BusinessException(ErrorCode.GPS_UNAVAILABLE, "Không lấy được vị trí GPS. Hãy bật GPS hoặc gửi giải trình.");
        if (!Double.isFinite(loc.latitude()) || !Double.isFinite(loc.longitude())
                || Math.abs(loc.latitude()) > 90 || Math.abs(loc.longitude()) > 180)
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Tọa độ không hợp lệ");
        if (loc.capturedAt() == null)
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Thiếu thời điểm đo GPS (capturedAt)");
        int maxAcc = storeService.current().getGpsMaxAccuracyMeters();
        if (loc.accuracyMeters() == null || !Double.isFinite(loc.accuracyMeters())
                || loc.accuracyMeters() < 0 || loc.accuracyMeters() > maxAcc)
            throw new BusinessException(ErrorCode.GPS_ACCURACY_INSUFFICIENT, "Sai số GPS quá lớn, hãy thử ở nơi thoáng hơn",
                    BusinessException.details("accuracyMeters", loc.accuracyMeters(), "maxAllowedMeters", maxAcc));
        if (loc.capturedAt() != null && Duration.between(loc.capturedAt().toInstant(), now).abs().getSeconds() > props.attendance().gpsMaxAgeSeconds())
            throw new BusinessException(ErrorCode.GPS_STALE, "Dữ liệu GPS đã cũ, hãy lấy lại vị trí");
        Store store = storeService.current();
        double d = GeoUtils.distanceMeters(loc.latitude(), loc.longitude(), store.getLatitude().doubleValue(), store.getLongitude().doubleValue());
        if (d > store.getAttendanceRadiusMeters())
            throw new BusinessException(ErrorCode.GPS_OUT_OF_RANGE, "Bạn đang ở ngoài phạm vi cửa hàng",
                    BusinessException.details("distanceMeters", Math.round(d * 10) / 10.0, "allowedRadiusMeters", store.getAttendanceRadiusMeters()));
        return new Geo(BigDecimal.valueOf(loc.latitude()).setScale(7, RoundingMode.HALF_UP),
                BigDecimal.valueOf(loc.longitude()).setScale(7, RoundingMode.HALF_UP),
                BigDecimal.valueOf(loc.accuracyMeters()).setScale(2, RoundingMode.HALF_UP), d);
    }

    private String requirePhoto(PhotoEvidence p, boolean required) {
        if (!required && (p == null || p.storageKey() == null || p.storageKey().isBlank())) return null;
        if (p != null && Boolean.FALSE.equals(p.cameraPermissionGranted()))
            throw new BusinessException(ErrorCode.CAMERA_PERMISSION_DENIED, "Chưa cấp quyền camera. Hãy mở Cài đặt, cấp quyền camera rồi thử lại");
        if (p == null || p.storageKey() == null || p.storageKey().isBlank())
            throw new BusinessException(ErrorCode.PHOTO_REQUIRED, "Cần chụp ảnh xác minh để chấm công");
        EvidenceKeys.requireOwnedAttendanceEvidence(p.storageKey(), SecurityUtils.requireEmployeeId());
        if (!storage.exists(p.storageKey()))
            throw new BusinessException(ErrorCode.PHOTO_REQUIRED, "Ảnh xác minh chưa được tải lên hoặc đã hết hạn");
        return p.storageKey();
    }

    private FaceVerificationClient.Result verifyFace(FaceVerification fv, String photoKey, Long empId) {
        FaceVerificationClient.Result res = face.verify(fv == null ? null : fv.sessionId(), photoKey, empId);
        if ("NO_MATCH".equals(res.matchStatus()) || "SPOOF".equals(res.livenessStatus()))
            throw new BusinessException(ErrorCode.FACE_VERIFICATION_FAILED, "Xác minh khuôn mặt không đạt, vui lòng thử lại");
        return res;
    }

    /** Ghi kết quả từng lần kiểm tra (SRS 7.4 AttendanceVerification): GPS, DEVICE, PHOTO, FACE_LIVENESS. */
    private void saveVerifications(Attendance a, String event, Long deviceId, String photoKey, Geo geo,
                                   FaceVerificationClient.Result fr, Instant now) {
        AttendanceVerification gps = verification(a, event, "GPS", "PASSED", now);
        gps.setLatitude(geo.lat());
        gps.setLongitude(geo.lon());
        gps.setAccuracyMeters(geo.accuracy());
        gps.setDistanceMeters(BigDecimal.valueOf(geo.distance()).setScale(2, java.math.RoundingMode.HALF_UP));
        evidences.save(gps);

        AttendanceVerification dev = verification(a, event, "DEVICE", "PASSED", now);
        dev.setDeviceId(deviceId);
        evidences.save(dev);

        AttendanceVerification photo = verification(a, event, "PHOTO", photoKey == null ? "EXEMPTED" : "PASSED", now);
        if (photoKey == null) photo.setFailureReason("Lượt chấm công này không yêu cầu ảnh theo chính sách lấy mẫu");
        photo.setEvidenceStorageKey(photoKey);
        photo.setRetainUntil(TimeUtils.today(clock).plusMonths(storeService.current().getPhotoRetentionMonths()));
        evidences.save(photo);

        String face = faceStatus(fr);
        AttendanceVerification fv = verification(a, event, "FACE_LIVENESS", face, now);
        fv.setAiProvider(fr == null ? null : fr.provider());
        if ("EXEMPTED".equals(face)) fv.setFailureReason("Chưa chạy xác minh khuôn mặt");
        if ("REVIEW_REQUIRED".equals(face)) fv.setFailureReason("Khuôn mặt cần người duyệt xem lại");
        evidences.save(fv);
    }

    private static AttendanceVerification verification(Attendance a, String event, String type, String status, Instant at) {
        AttendanceVerification v = new AttendanceVerification();
        v.setAttendanceId(a.getAttendanceId());
        v.setEventType(event);
        v.setVerificationType(type);
        v.setVerificationStatus(status);
        v.setVerifiedAt(at);
        return v;
    }

    private static String faceStatus(FaceVerificationClient.Result fr) {
        if (fr == null || fr.matchStatus() == null || "NOT_RUN".equals(fr.matchStatus())) return "EXEMPTED";
        if ("REVIEW".equals(fr.matchStatus()) || "REVIEW".equals(fr.livenessStatus())) return "REVIEW_REQUIRED";
        return "PASSED";
    }

    void assertNotLocked(Attendance a) {
        if ("LOCKED".equals(a.getPayrollStatus()))
            throw new BusinessException(ErrorCode.ATTENDANCE_LOCKED, "Công đã được chốt, không thể thay đổi");
    }

    // =============================== TRUY VẤN ===============================
    @Transactional(readOnly = true)
    public CurrentShiftView current() {
        return current(null);
    }

    @Transactional(readOnly = true)
    public CurrentShiftView current(String credential) {
        return current(credential, null);
    }

    @Transactional(readOnly = true)
    public CurrentShiftView current(String credential, Long selectedAssignmentId) {
        Long empId = SecurityUtils.requireEmployeeId();
        Employee emp = employees.findById(empId).orElseThrow();
        Instant now = clock.instant();
        LocalDate today = TimeUtils.today(clock);
        List<ShiftAssignment> cand = new ArrayList<>(schedules.findByEmployeeIdAndWorkDateBetweenOrderByPlannedStartAtAsc(empId, today.minusDays(1), today.plusDays(1))
                .stream().filter(s -> "PUBLISHED".equals(s.getScheduleStatus())).toList());
        if (flexibleTesting && selectedAssignmentId != null && cand.stream().noneMatch(s -> s.getShiftAssignmentId().equals(selectedAssignmentId))) {
            cand.add(schedules.findById(selectedAssignmentId)
                    .filter(s -> s.getEmployeeId().equals(empId) && "PUBLISHED".equals(s.getScheduleStatus()))
                    .orElseThrow(() -> BusinessException.notFound("ca được giao cho bạn")));
        }
        Map<Long, Attendance> records = new HashMap<>();
        if (!cand.isEmpty()) attendance.findByShiftAssignmentIdIn(cand.stream().map(ShiftAssignment::getShiftAssignmentId).toList())
                .forEach(a -> records.put(a.getShiftAssignmentId(), a));
        ShiftAssignment pick = null;
        int best = Integer.MAX_VALUE;
        for (ShiftAssignment s : cand) {
            Attendance ar = records.get(s.getShiftAssignmentId());
            boolean open = ar != null && ar.getCheckInAt() != null && ar.getCheckOutAt() == null;
            WorkShift workShift = shifts.findById(s.getWorkShiftId()).orElseThrow();
            boolean inWindow = !now.isBefore(s.getPlannedStartAt().minus(Duration.ofMinutes(workShift.getEarlyCheckInMinutes())))
                    && !now.isAfter(s.getPlannedEndAt());
            boolean notStarted = ar == null || ar.getCheckInAt() == null;
            int priority = open ? 0 : notStarted && (flexibleTesting || inWindow) ? 1
                    : flexibleTesting ? 2 : notStarted && s.getPlannedEndAt().isAfter(now) ? 3 : Integer.MAX_VALUE;
            if (priority < best) { best = priority; pick = s; }
        }
        if (flexibleTesting && selectedAssignmentId != null) {
            pick = cand.stream().filter(s -> s.getShiftAssignmentId().equals(selectedAssignmentId)).findFirst().orElseThrow();
        }
        if (pick == null) return null;
        WorkShift sh = shifts.findById(pick.getWorkShiftId()).orElseThrow();
        Attendance ar = attendance.findByShiftAssignmentId(pick.getShiftAssignmentId()).orElse(null);
        Instant opens = pick.getPlannedStartAt().minus(Duration.ofMinutes(sh.getEarlyCheckInMinutes()));
        TrainingService.Eligibility el = training.eligibility(emp);
        var installation = devices.current(credential);
        boolean deviceOk = installation != null && "ACTIVE".equals(installation.status());
        List<String> blockers = new ArrayList<>();
        if (!deviceOk) blockers.add("DEVICE_NOT_ACTIVE");
        if (!flexibleTesting) {
            if (!"ACTIVE".equals(emp.getEmploymentStatus())) blockers.add("ACCOUNT_NOT_ACTIVE");
            if (now.isBefore(opens) && (ar == null || ar.getCheckInAt() == null)) blockers.add("CHECK_IN_TOO_EARLY");
            if (now.isAfter(pick.getPlannedEndAt()) && (ar == null || ar.getCheckInAt() == null)) blockers.add("CHECK_IN_WINDOW_CLOSED");
            try { lockGuard.assertWorkDateOpen(pick.getWorkDate()); }
            catch (BusinessException e) { blockers.add(e.getCode().name()); }
        }
        boolean checkedIn = ar != null && ar.getCheckInAt() != null;
        boolean canIn = !checkedIn && (flexibleTesting || !now.isBefore(opens) && !now.isAfter(pick.getPlannedEndAt())) && blockers.isEmpty();
        boolean canOut = checkedIn && ar.getCheckOutAt() == null && blockers.isEmpty();
        return new CurrentShiftView(pick.getShiftAssignmentId(), sh.getShiftName(), TimeUtils.vn(pick.getPlannedStartAt()),
                TimeUtils.vn(pick.getPlannedEndAt()), TimeUtils.vn(opens), ar == null ? null : ar.getAttendanceId(),
                ar == null ? null : apiStatus(ar, false), canIn, canOut, deviceOk, el.eligible(), blockers,
                photoPolicy.required(empId, pick.getShiftAssignmentId(), checkedIn ? "CHECK_OUT" : "CHECK_IN"), flexibleTesting,
                flexibleTesting ? cand.stream().map(s -> {
                    Attendance record = records.get(s.getShiftAssignmentId());
                    String name = shifts.findById(s.getWorkShiftId()).map(WorkShift::getShiftName).orElse("Ca làm");
                    return new ShiftChoice(s.getShiftAssignmentId(), name, s.getWorkDate(), TimeUtils.vn(s.getPlannedStartAt()),
                            TimeUtils.vn(s.getPlannedEndAt()), record == null ? null : apiStatus(record, false));
                }).toList() : List.of());
    }

    @Transactional
    public CurrentShiftView nextTestSession(Long assignmentId, String credential) {
        if (!flexibleTesting) throw BusinessException.forbidden("Chế độ test thủ công chưa được bật");
        Long employeeId = SecurityUtils.requireEmployeeId();
        ShiftAssignment source = schedules.findById(assignmentId).filter(s -> s.getEmployeeId().equals(employeeId))
                .orElseThrow(() -> BusinessException.notFound("ca được giao cho bạn"));
        Attendance previous = attendance.findByShiftAssignmentId(assignmentId).orElse(null);
        if (previous == null || previous.getCheckOutAt() == null)
            throw BusinessException.invalidState("Hãy hoàn tất check-in và check-out của lượt hiện tại trước");
        LocalDate today = TimeUtils.today(clock);
        ShiftAssignment next = new ShiftAssignment();
        next.setEmployeeId(employeeId);
        next.setWorkShiftId(source.getWorkShiftId());
        next.setWorkDate(today);
        next.setPlannedStartAt(TimeUtils.startOfDay(today));
        next.setPlannedEndAt(TimeUtils.startOfDay(today.plusDays(1)));
        next.setCreatedBy(SecurityUtils.current().userId());
        next.setNote("Test thủ công - lượt mới từ phân ca #" + assignmentId);
        schedules.saveAndFlush(next);
        audit.log("ATTENDANCE_TEST_SESSION_CREATE", "ShiftAssignment", next.getShiftAssignmentId(), null,
                Map.of("sourceAssignmentId", assignmentId, "manualTest", true));
        return current(credential, next.getShiftAssignmentId());
    }

    @Transactional(readOnly = true)
    public PageResponse<AttendanceView> mine(LocalDate from, LocalDate to, Pageable p) {
        Long empId = SecurityUtils.requireEmployeeId();
        LocalDate f = from != null ? from : TimeUtils.today(clock).withDayOfMonth(1), t = to != null ? to : f.plusMonths(1);
        return PageResponse.of(attendance.searchByWorkDate(empId, "", f, t, p), this::toView);
    }

    @Transactional(readOnly = true)
    public PageResponse<AttendanceView> search(LocalDate from, LocalDate to, Long employeeId, String status, Pageable p) {
        LocalDate f = from != null ? from : TimeUtils.today(clock).withDayOfMonth(1), t = to != null ? to : f.plusMonths(1);
        return PageResponse.of(attendance.searchByWorkDate(employeeId == null ? 0L : employeeId, status == null ? "" : status, f, t, p), this::toView);
    }

    @Transactional(readOnly = true)
    public AttendanceView get(Long id) {
        Attendance a = attendance.findById(id).orElseThrow(() -> BusinessException.notFound("bản ghi chấm công"));
        assertCanView(a);
        return toView(a);
    }

    /** Kết quả xác minh theo từng lần kiểm tra. Ảnh chỉ để XEM (URL ngắn hạn); tải xuống cần quyền EVIDENCE_DOWNLOAD. Mọi lần xem ảnh được ghi audit. */
    @Transactional
    public List<VerificationView> verifications(Long id) {
        Attendance a = attendance.findById(id).orElseThrow(() -> BusinessException.notFound("bản ghi chấm công"));
        assertCanView(a);
        AuthUser u = SecurityUtils.current();
        boolean canDownload = u.hasPermission(Permissions.EVIDENCE_DOWNLOAD);
        boolean mayViewPhoto = u.employeeId() != null && u.employeeId().equals(a.getEmployeeId()) || u.hasPermission(Permissions.EVIDENCE_VIEW);
        List<VerificationView> out = new ArrayList<>();
        for (AttendanceVerification v : evidences.findByAttendanceIdOrderByVerifiedAtAsc(id)) {
            String url = null;
            if ("PHOTO".equals(v.getVerificationType()) && mayViewPhoto && v.getEvidenceStorageKey() != null
                    && !"PURGED".equals(v.getEvidenceStorageKey())) {
                url = storage.createViewUrl(v.getEvidenceStorageKey(), Duration.ofSeconds(props.storage().signedUrlTtlSeconds()), u.userId());
                audit.log("EVIDENCE_VIEW", "AttendanceVerification", v.getVerificationId(), null, Map.of("attendanceId", id));
            }
            out.add(new VerificationView(v.getVerificationType(), v.getVerificationStatus(),
                    v.getLatitude() == null ? null : v.getLatitude().doubleValue(),
                    v.getLongitude() == null ? null : v.getLongitude().doubleValue(),
                    v.getAccuracyMeters() == null ? null : v.getAccuracyMeters().doubleValue(),
                    v.getDistanceMeters() == null ? null : v.getDistanceMeters().doubleValue(),
                    url, canDownload && url != null, v.getFailureReason(), TimeUtils.vn(v.getVerifiedAt())));
        }
        return out;
    }

    void assertCanView(Attendance a) {
        AuthUser u = SecurityUtils.current();
        if (a.getEmployeeId().equals(u.employeeId()) || u.isStaffReviewer()
                || u.hasAnyPermission(Permissions.ATTENDANCE_VIEW_ALL, Permissions.ATTENDANCE_ADJUST_HR)) return;
        throw BusinessException.forbidden("Bạn không có quyền xem bản ghi chấm công này");
    }

    /** Quy đổi trạng thái lưu trong DB sang trạng thái API (SRS 8.5). */
    String apiStatus(Attendance a, boolean checkAdjustments) {
        if ("LOCKED".equals(a.getPayrollStatus())) return "FINALIZED";
        if ("EXPLANATION_PENDING".equals(a.getAttendanceStatus())) return "REVIEW_REQUIRED";
        if (checkAdjustments && adjustments.existsPending(a.getAttendanceId())) return "ADJUSTMENT_PENDING";
        return a.getCheckOutAt() == null ? "CHECKED_IN" : "CHECKED_OUT";
    }

    AttendanceView toView(Attendance a) {
        ShiftAssignment sc = schedules.findById(a.getShiftAssignmentId()).orElse(null);
        return new AttendanceView(a.getAttendanceId(), a.getShiftAssignmentId(), a.getEmployeeId(), people.nameOf(a.getEmployeeId()),
                sc == null ? null : sc.getWorkDate(), TimeUtils.vn(a.getCheckInAt()), TimeUtils.vn(a.getCheckOutAt()),
                apiStatus(a, true), a.getAttendanceStatus(), a.getLateMinutes(), a.getEarlyLeaveMinutes(), a.getWorkedMinutes(),
                a.getApprovedOTMinutes(), a.getCheckInMethod(), a.getCheckOutMethod(), a.getPayrollStatus(), a.getNote());
    }
}
