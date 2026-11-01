package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.shared.dto.AttendanceDto.ExceptionView;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.ExplanationRequest;

import com.hrm.coffeeshop.common.*;
import com.hrm.coffeeshop.domain.*;
import com.hrm.coffeeshop.repository.*;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Map;

/** Giải trình ngoại lệ chấm công (GPS không khả dụng, quên check-in/out, hỏng camera, đi công tác...). */
@Service
public class AttendanceExceptionService {
    private static final List<String> RECOMPUTABLE = List.of("IN_PROGRESS", "PRESENT", "LATE", "EARLY_LEAVE");

    private final AttendanceExceptionRequestRepository exceptions;
    private final AttendanceRepository attendance;
    private final AttendanceVerificationRepository evidences;
    private final ShiftAssignmentRepository schedules;
    private final WorkShiftRepository shifts;
    private final AttendanceMetricsService metrics;
    private final PersonLookup people;
    private final NotificationService notifications;
    private final AuditService audit;
    private final PayrollLockGuard lockGuard;
    private final StorageGateway storage;
    private final Clock clock;

    private final StoreService storeService;

    public AttendanceExceptionService(AttendanceExceptionRequestRepository exceptions, AttendanceRepository attendance,
                                      AttendanceVerificationRepository evidences, ShiftAssignmentRepository schedules,
                                      WorkShiftRepository shifts, AttendanceMetricsService metrics, PersonLookup people,
                                      StoreService storeService, NotificationService notifications,
                                      AuditService audit, PayrollLockGuard lockGuard, StorageGateway storage, Clock clock) {
        this.storeService = storeService;
        this.exceptions = exceptions;
        this.attendance = attendance;
        this.evidences = evidences;
        this.schedules = schedules;
        this.shifts = shifts;
        this.metrics = metrics;
        this.people = people;
        this.notifications = notifications;
        this.audit = audit;
        this.lockGuard = lockGuard;
        this.storage = storage;
        this.clock = clock;
    }

    static String mapType(String code) {
        String c = code == null ? "" : code.trim().toUpperCase();
        return switch (c) {
            case "GPS_UNAVAILABLE", "NO_GPS" -> "NO_GPS";
            case "MISSED_CHECK_IN", "FORGOT_CHECK_IN" -> "MISSED_CHECK_IN";
            case "MISSED_CHECK_OUT", "FORGOT_CHECK_OUT" -> "MISSED_CHECK_OUT";
            case "BUSINESS_TRIP" -> "BUSINESS_TRIP";
            case "DEVICE_ISSUE" -> "DEVICE_ISSUE";
            case "CAMERA_ISSUE", "CAMERA_BROKEN" -> "CAMERA_ISSUE";
            default -> "OTHER";
        };
    }

    static ExceptionView view(AttendanceExceptionRequest r) {
        String st = "PENDING".equals(r.getRequestStatus()) ? "PENDING_MANAGER" : r.getRequestStatus();
        return new ExceptionView(r.getExceptionRequestId(), r.getEmployeeId(), r.getShiftAssignmentId(), r.getAttendanceId(),
                r.getRequestType(), r.getReason(), st, TimeUtils.vn(r.getRequestedCheckInAt()),
                TimeUtils.vn(r.getRequestedCheckOutAt()), TimeUtils.vn(r.getSubmittedAt()), TimeUtils.vn(r.getReviewedAt()),
                r.getReviewNote());
    }

    @Transactional
    public ExceptionView create(Long attendanceIdPath, ExplanationRequest r) {
        Long empId = SecurityUtils.requireEmployeeId();
        Attendance a = null;
        Long scheduleId = r.scheduleId();
        if (attendanceIdPath != null) {
            // Khóa kỳ theo ngày của bản ghi công TRƯỚC khi nạp bản ghi (đơn sẽ đổi trạng thái bản ghi này).
            attendance.findWorkDateOfAttendance(attendanceIdPath, empId).ifPresent(lockGuard::assertWorkDateOpen);
            a = attendance.findById(attendanceIdPath).filter(x -> x.getEmployeeId().equals(empId))
                    .orElseThrow(() -> BusinessException.notFound("bản ghi chấm công"));
            scheduleId = a.getShiftAssignmentId();
        }
        if (scheduleId == null) throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Cần scheduleId hoặc attendanceId");
        ShiftAssignment sc = schedules.findById(scheduleId).filter(s -> s.getEmployeeId().equals(empId))
                .orElseThrow(() -> new BusinessException(ErrorCode.SHIFT_NOT_FOUND, "Không tìm thấy ca làm"));
        lockGuard.assertWorkDateOpen(sc.getWorkDate());     // khóa kỳ trước khi nạp bản ghi công theo ca
        if (a == null) a = attendance.findByShiftAssignmentId(scheduleId).orElse(null);
        if (a != null && "LOCKED".equals(a.getPayrollStatus()))
            throw new BusinessException(ErrorCode.ATTENDANCE_LOCKED, "Công đã được chốt");
        String type = mapType(r.reasonCode());
        if (exceptions.existsByEmployeeIdAndShiftAssignmentIdAndRequestTypeAndRequestStatus(empId, scheduleId, type, "PENDING"))
            throw new BusinessException(ErrorCode.CONFLICT, "Đã có đơn giải trình cùng loại đang chờ duyệt");
        Instant now = clock.instant();
        Instant in = TimeUtils.instant(r.requestedCheckInAt()), out = TimeUtils.instant(r.requestedCheckOutAt());
        validateTimes(in, out, now);

        AttendanceExceptionRequest ex = new AttendanceExceptionRequest();
        ex.setEmployeeId(empId);
        ex.setShiftAssignmentId(scheduleId);
        ex.setAttendanceId(a == null ? null : a.getAttendanceId());
        ex.setRequestType(type);
        ex.setRequestedCheckInAt(in);
        ex.setRequestedCheckOutAt(out);
        ex.setReason(r.reason().trim());
        exceptions.save(ex);

        if (r.evidenceStorageKey() != null && !r.evidenceStorageKey().isBlank()) {
            String k = r.evidenceStorageKey();
            EvidenceKeys.requireOwnedAttendanceEvidence(k, empId);
            if (!storage.exists(k))
                throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Ảnh minh chứng chưa được tải lên hoặc đã bị xóa");
            ex.setEvidenceStorageKey(k);
            ex.setRetainUntil(TimeUtils.today(clock).plusMonths(storeService.current().getPhotoRetentionMonths()));
        }
        if (a != null && RECOMPUTABLE.contains(a.getAttendanceStatus())) a.setAttendanceStatus("EXPLANATION_PENDING");
        audit.log("ATTENDANCE_EXPLANATION_SUBMIT", "AttendanceExceptionRequest", ex.getExceptionRequestId(), null,
                Map.of("type", type, "scheduleId", scheduleId));
        notifications.notifyRole(Roles.STORE_MANAGER, "EXCEPTION_PENDING", "Có giải trình chấm công chờ duyệt",
                people.nameOf(empId) + " gửi giải trình " + type, "AttendanceExceptionRequest", ex.getExceptionRequestId());
        return view(ex);
    }

    /** Giải trình do chính nhân viên gửi (50 đơn gần nhất). */
    @Transactional(readOnly = true)
    public List<ExceptionView> mine() {
        return exceptions.findTop50ByEmployeeIdOrderBySubmittedAtDesc(SecurityUtils.requireEmployeeId()).stream()
                .map(AttendanceExceptionService::view).toList();
    }

    @Transactional(readOnly = true)
    public PageResponse<ExceptionView> list(String status, Pageable p) {
        String st = status == null ? "PENDING" : status.equals("PENDING_MANAGER") ? "PENDING" : status;
        return PageResponse.of(st.isBlank() ? exceptions.findAll(p) : exceptions.findByRequestStatusOrderBySubmittedAtAsc(st, p),
                AttendanceExceptionService::view);
    }

    @Transactional
    public ExceptionView approve(Long requestId, String note) {
        SecurityUtils.requireAny(Roles.STORE_MANAGER);
        AttendanceExceptionRequest ex = pending(requestId);
        ShiftAssignment sc = schedules.findById(ex.getShiftAssignmentId()).orElseThrow();
        lockGuard.assertWorkDateOpen(sc.getWorkDate());   // khóa kỳ trước khi nạp/ghi bản ghi công
        if ("ABSENCE".equals(ex.getRequestType())) {
            // DEC-ABS: đơn vắng mặt được duyệt như mọi đơn khác nhưng KHÔNG ghi bản ghi công.
            ex.setRequestStatus("APPROVED");
            exceptions.saveAndFlush(ex);
            decide(ex, note);
            audit.log("ABSENCE_APPROVE", "AttendanceExceptionRequest", requestId, null, Map.of("note", String.valueOf(note)));
            notifyEmployee(ex, "Đơn vắng mặt được duyệt", "Ca ngày " + sc.getWorkDate() + " được ghi nhận vắng mặt.");
            return view(ex);
        }
        WorkShift sh = shifts.findById(sc.getWorkShiftId()).orElseThrow();
        Attendance a = attendance.findByShiftAssignmentId(sc.getShiftAssignmentId()).orElseGet(() -> {
            Attendance n = new Attendance();
            n.setShiftAssignmentId(sc.getShiftAssignmentId());
            n.setEmployeeId(sc.getEmployeeId());
            return n;
        });
        if ("LOCKED".equals(a.getPayrollStatus()))
            throw new BusinessException(ErrorCode.ATTENDANCE_LOCKED, "Công đã được chốt");
        Map<String, Object> before = Map.of("checkIn", String.valueOf(a.getCheckInAt()), "checkOut", String.valueOf(a.getCheckOutAt()));
        if (ex.getRequestedCheckInAt() != null) {
            a.setCheckInAt(ex.getRequestedCheckInAt());
            a.setCheckInMethod("MANUAL_APPROVAL"); exemptGps(a, "CHECK_IN");
        }
        if (ex.getRequestedCheckOutAt() != null) {
            a.setCheckOutAt(ex.getRequestedCheckOutAt());
            a.setCheckOutMethod("MANUAL_APPROVAL"); exemptGps(a, "CHECK_OUT");
        }
        if (a.getCheckInAt() == null)
            throw BusinessException.rule("Đơn không có thời gian check-in đề xuất nên không thể ghi nhận công");
        if (a.getCheckOutAt() != null && a.getCheckOutAt().isBefore(a.getCheckInAt()))
            throw BusinessException.rule("Giờ check-out phải sau giờ check-in");
        a.setAttendanceStatus("IN_PROGRESS");
        metrics.apply(a, sc, sh);
        a.setAttendanceStatus("APPROVED_EXCEPTION");
        a.setManagerReviewedBy(SecurityUtils.current().userId());
        a.setManagerReviewedAt(clock.instant());
        attendance.save(a);

        ex.setAttendanceId(a.getAttendanceId());
        ex.setRequestStatus("APPROVED");
        exceptions.saveAndFlush(ex);
        decide(ex, note);
        audit.log("ATTENDANCE_EXCEPTION_APPROVE", "AttendanceExceptionRequest", requestId, before,
                Map.of("checkIn", String.valueOf(a.getCheckInAt()), "checkOut", String.valueOf(a.getCheckOutAt()), "note", String.valueOf(note)));
        notifyEmployee(ex, "Giải trình được duyệt", "Công của bạn đã được ghi nhận.");
        return view(ex);
    }

    @Transactional
    public ExceptionView reject(Long requestId, String reason) {
        SecurityUtils.requireAny(Roles.STORE_MANAGER);
        if (reason == null || reason.isBlank()) throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Phải nhập lý do từ chối");
        AttendanceExceptionRequest ex = pending(requestId);
        if (ex.getAttendanceId() != null) {
            lockGuard.assertWorkDateOpen(schedules.findById(ex.getShiftAssignmentId()).orElseThrow().getWorkDate());
            attendance.findById(ex.getAttendanceId()).ifPresent(a -> {
                if ("EXPLANATION_PENDING".equals(a.getAttendanceStatus())) {
                    a.setAttendanceStatus("IN_PROGRESS");
                    ShiftAssignment sc = schedules.findById(a.getShiftAssignmentId()).orElseThrow();
                    metrics.apply(a, sc, shifts.findById(sc.getWorkShiftId()).orElseThrow());
                }
            });
        }
        ex.setRequestStatus("REJECTED");
        exceptions.saveAndFlush(ex);
        decide(ex, reason.trim());
        audit.log("ATTENDANCE_EXCEPTION_REJECT", "AttendanceExceptionRequest", requestId, null, Map.of("reason", reason));
        notifyEmployee(ex, "Giải trình bị từ chối", reason);
        return view(ex);
    }

    private AttendanceExceptionRequest pending(Long id) {
        AttendanceExceptionRequest ex = exceptions.findById(id).orElseThrow(() -> BusinessException.notFound("đơn giải trình"));
        if (!"PENDING".equals(ex.getRequestStatus())) throw BusinessException.invalidState("Đơn không ở trạng thái chờ duyệt");
        if (people.userIdOf(ex.getEmployeeId()).equals(SecurityUtils.current().userId()))
            throw BusinessException.forbidden("Không thể tự duyệt đơn của chính mình");
        return ex;
    }

    private void decide(AttendanceExceptionRequest ex, String note) {
        ex.setReviewedBy(SecurityUtils.current().userId());
        ex.setReviewedAt(clock.instant());
        ex.setReviewNote(note);
    }

    private void notifyEmployee(AttendanceExceptionRequest ex, String title, String msg) {
        notifications.notify(people.userIdOf(ex.getEmployeeId()), "EXCEPTION_REVIEWED", title, msg,
                "AttendanceExceptionRequest", ex.getExceptionRequestId(), null);
    }

    private void validateTimes(Instant in, Instant out, Instant now) {
        if ((in != null && in.isAfter(now.plusSeconds(60))) || (out != null && out.isAfter(now.plusSeconds(60))))
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Thời gian đề xuất không được ở tương lai");
        if (in != null && out != null && !out.isAfter(in))
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Giờ check-out phải sau giờ check-in");
    }

    /** Duyệt thủ công: ghi nhận GPS EXEMPTED để kết quả xác minh phản ánh đúng cách công được duyệt (SRS 7.4). */
    private void exemptGps(Attendance a, String event) {
        AttendanceVerification v = new AttendanceVerification();
        v.setAttendanceId(a.getAttendanceId());
        v.setEventType(event);
        v.setVerificationType("GPS");
        v.setVerificationStatus("EXEMPTED");
        v.setFailureReason("Duyệt thủ công qua giải trình");
        v.setVerifiedAt(clock.instant());
        evidences.save(v);
    }
}
