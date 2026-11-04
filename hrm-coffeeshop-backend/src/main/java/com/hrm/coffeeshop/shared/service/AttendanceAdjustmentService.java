package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.shared.dto.AttendanceDto.AdjustmentRequest;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.AdjustmentView;

import com.hrm.coffeeshop.common.*;
import com.hrm.coffeeshop.domain.*;
import com.hrm.coffeeshop.repository.*;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * Điều chỉnh công sau khi đã ghi nhận: Nhân viên đề xuất → Quản lý duyệt nghiệp vụ → HR duyệt tổng hợp → áp dụng.
 * Mỗi trường (CHECK_IN/CHECK_OUT) là một dòng AttendanceAdjustmentRequest; giá trị cũ/mới được giữ nguyên để audit.
 */
@Service
public class AttendanceAdjustmentService {
    private final AttendanceAdjustmentRequestRepository adjustments;
    private final AttendanceAdjustmentHistoryRepository history;
    private final AttendanceVerificationRepository verifications;
    private final AttendanceRepository attendance;
    private final ShiftAssignmentRepository schedules;
    private final WorkShiftRepository shifts;
    private final AttendanceMetricsService metrics;
    private final PersonLookup people;
    private final NotificationService notifications;
    private final AuditService audit;
    private final PayrollLockGuard lockGuard;
    private final StorageGateway storage;
    private final Clock clock;

    public AttendanceAdjustmentService(AttendanceAdjustmentRequestRepository adjustments, AttendanceAdjustmentHistoryRepository history, AttendanceVerificationRepository verifications, AttendanceRepository attendance,
                                       ShiftAssignmentRepository schedules, WorkShiftRepository shifts,
                                       AttendanceMetricsService metrics, PersonLookup people,
                                       NotificationService notifications, AuditService audit, PayrollLockGuard lockGuard, StorageGateway storage, Clock clock) {
        this.adjustments = adjustments;
        this.history = history;
        this.verifications = verifications;
        this.attendance = attendance;
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

    public static String status(AttendanceAdjustmentRequest a) {
        if ("REJECTED".equals(a.getManagerStatus()) || "REJECTED".equals(a.getHrStatus())) return "REJECTED";
        if ("PENDING".equals(a.getManagerStatus())) return "PENDING_MANAGER";
        if ("PENDING".equals(a.getHrStatus())) return "PENDING_HR";
        return "APPROVED";
    }

    AdjustmentView view(AttendanceAdjustmentRequest a) {
        Attendance record = attendance.findById(a.getAttendanceId()).orElseThrow(() -> BusinessException.notFound("bản ghi chấm công"));
        LocalDate workDate = schedules.findById(record.getShiftAssignmentId()).map(ShiftAssignment::getWorkDate).orElse(null);
        return new AdjustmentView(a.getAttendanceAdjustmentRequestId(), a.getAttendanceId(), a.getFieldName(), a.getOldValue(), a.getNewValue(),
                a.getReason(), status(a), a.getManagerStatus(), a.getHrStatus(), TimeUtils.vn(a.getCreatedAt()),
                record.getEmployeeId(), people.nameOf(record.getEmployeeId()), workDate);
    }

    @Transactional
    public List<AdjustmentView> create(AdjustmentRequest r) {
        AuthUser u = SecurityUtils.current();
        Long empId = SecurityUtils.requireEmployeeId();
        Attendance a = attendance.findById(r.attendanceId()).filter(x -> x.getEmployeeId().equals(empId))
                .orElseThrow(() -> BusinessException.notFound("bản ghi chấm công"));
        if ("LOCKED".equals(a.getPayrollStatus()))
            throw new BusinessException(ErrorCode.ATTENDANCE_LOCKED, "Công đã được chốt, không thể điều chỉnh");
        lockGuard.assertWorkDateOpen(schedules.findById(a.getShiftAssignmentId())
                .orElseThrow(() -> BusinessException.notFound("ca làm")).getWorkDate());
        Instant in = TimeUtils.instant(r.requestedCheckInAt()), out = TimeUtils.instant(r.requestedCheckOutAt());
        if (in == null && out == null)
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Cần ít nhất một giờ đề xuất (check-in hoặc check-out)");
        Instant now = clock.instant();
        if ((in != null && in.isAfter(now)) || (out != null && out.isAfter(now)))
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Thời gian đề xuất không được ở tương lai");
        Instant effIn = in != null ? in : a.getCheckInAt(), effOut = out != null ? out : a.getCheckOutAt();
        if (effIn != null && effOut != null && !effOut.isAfter(effIn))
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Giờ check-out phải sau giờ check-in");
        String key = r.evidenceStorageKey();
        if (key != null && !key.isBlank())
            EvidenceKeys.requireOwnedAttendanceEvidence(key, empId);
        if (key != null && !key.isBlank() && !storage.exists(key))
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Ảnh minh chứng chưa được tải lên hoặc đã bị xóa");

        List<AdjustmentView> res = new ArrayList<>();
        if (in != null) res.add(view(createRow(a, u, "CHECK_IN", a.getCheckInAt(), in, r, key)));
        if (out != null) res.add(view(createRow(a, u, "CHECK_OUT", a.getCheckOutAt(), out, r, key)));
        notifications.notifyRole(Roles.STORE_MANAGER, "ADJUSTMENT_PENDING", "Có yêu cầu điều chỉnh công chờ duyệt",
                people.nameOf(empId) + " đề nghị điều chỉnh công", "Attendance", a.getAttendanceId());
        return res;
    }

    private AttendanceAdjustmentRequest createRow(Attendance a, AuthUser u, String field, Instant old, Instant nw,
                                           AdjustmentRequest r, String evidenceKey) {
        if (adjustments.existsPendingField(a.getAttendanceId(), field))
            throw new BusinessException(ErrorCode.ATTENDANCE_ADJUSTMENT_PENDING, "Đã có yêu cầu điều chỉnh " + field + " đang chờ xử lý");
        AttendanceAdjustmentRequest adj = new AttendanceAdjustmentRequest();
        adj.setAttendanceId(a.getAttendanceId());
        adj.setFieldName(field);
        adj.setOldValue(old == null ? null : old.toString());
        adj.setNewValue(nw.toString());
        String reason = r.reasonCode().trim() + ": " + r.reason().trim();
        adj.setReason(reason.substring(0, Math.min(reason.length(), 1000)));
        adj.setEvidenceStorageKey(evidenceKey == null || evidenceKey.isBlank() ? null : evidenceKey);
        adj.setRequestedBy(u.userId());
        adjustments.save(adj);
        audit.log("ATTENDANCE_ADJUST_REQUEST", "AttendanceAdjustmentRequest", adj.getAttendanceAdjustmentRequestId(), null,
                Map.of("field", field, "old", String.valueOf(old), "new", nw.toString()));
        return adj;
    }

    @Transactional(readOnly = true)
    public PageResponse<AdjustmentView> list(String status, Pageable p) {
        Page<AttendanceAdjustmentRequest> page;
        String s = status == null ? "" : status;
        page = switch (s) {
            case "PENDING_MANAGER" -> adjustments.findByManagerStatus("PENDING", p);
            case "PENDING_HR" -> adjustments.findByManagerStatusAndHrStatus("APPROVED", "PENDING", p);
            case "APPROVED" -> adjustments.findByManagerStatusAndHrStatus("APPROVED", "APPROVED", p);
            case "REJECTED" -> adjustments.findRejected(p);
            default -> adjustments.findAll(p);
        };
        return PageResponse.of(page, this::view);
    }

    @Transactional(readOnly = true)
    public PageResponse<AdjustmentView> mine(Pageable p) {
        return PageResponse.of(adjustments.findByRequestedBy(SecurityUtils.current().userId(), p), this::view);
    }

    @Transactional(readOnly = true)
    public AdjustmentView get(Long id) {
        AttendanceAdjustmentRequest a = find(id);
        AuthUser u = SecurityUtils.current();
        if (!a.getRequestedBy().equals(u.userId()) && !u.isStaffReviewer() && !u.hasAny(Roles.STORE_MANAGER)
                && !u.hasAnyPermission(Permissions.ATTENDANCE_ADJUST_HR, Permissions.ATTENDANCE_VIEW_ALL))
            throw BusinessException.forbidden("Bạn không có quyền xem yêu cầu này");
        return view(a);
    }

    @Transactional
    public AdjustmentView managerApprove(Long id, String note) {
        SecurityUtils.requireAny(Roles.STORE_MANAGER);
        AttendanceAdjustmentRequest a = find(id);
        requireNotSelf(a);
        if (!"PENDING".equals(a.getManagerStatus())) throw BusinessException.invalidState("Yêu cầu không ở bước chờ quản lý");
        a.setManagerStatus("APPROVED");
        a.setManagerReviewedBy(SecurityUtils.current().userId());
        a.setManagerReviewedAt(clock.instant());
        adjustments.saveAndFlush(a);   // khóa lạc quan: người duyệt thứ hai nhận 409
        audit.log("ATTENDANCE_ADJUST_MANAGER_APPROVE", "AttendanceAdjustmentRequest", id, null, Map.of("note", String.valueOf(note)));
        notifications.notifyPermission(Permissions.ATTENDANCE_ADJUST_HR, "ADJUSTMENT_PENDING_HR", "Yêu cầu điều chỉnh công chờ HR",
                "Đã được quản lý duyệt, cần HR duyệt tổng hợp", "AttendanceAdjustmentRequest", id);
        return view(a);
    }

    @Transactional
    public AdjustmentView managerReject(Long id, String reason) {
        SecurityUtils.requireAny(Roles.STORE_MANAGER);
        needReason(reason);
        AttendanceAdjustmentRequest a = find(id);
        requireNotSelf(a);
        if (!"PENDING".equals(a.getManagerStatus())) throw BusinessException.invalidState("Yêu cầu không ở bước chờ quản lý");
        a.setManagerStatus("REJECTED");
        a.setManagerReviewedBy(SecurityUtils.current().userId());
        a.setManagerReviewedAt(clock.instant());
        adjustments.saveAndFlush(a);
        audit.log("ATTENDANCE_ADJUST_MANAGER_REJECT", "AttendanceAdjustmentRequest", id, null, Map.of("reason", reason));
        notifications.notify(a.getRequestedBy(), "ADJUSTMENT_REVIEWED", "Yêu cầu điều chỉnh công bị từ chối", reason, "AttendanceAdjustmentRequest", id, null);
        return view(a);
    }

    @Transactional
    public AdjustmentView hrApprove(Long id, String note) {
        SecurityUtils.requirePermission(Permissions.ATTENDANCE_ADJUST_HR);
        AttendanceAdjustmentRequest adj = find(id);
        requireNotSelf(adj);
        if (!"APPROVED".equals(adj.getManagerStatus()) || !"PENDING".equals(adj.getHrStatus()))
            throw BusinessException.invalidState("Yêu cầu chưa được quản lý duyệt hoặc đã được HR xử lý");
        // Khóa kỳ công trước khi nạp bản ghi công để ghi (tránh ghi đè bằng trạng thái đọc trước khi có khóa).
        lockGuard.assertWorkDateOpen(attendance.findWorkDateOfAttendance(adj.getAttendanceId(), 0L)
                .orElseThrow(() -> BusinessException.notFound("bản ghi chấm công")));
        Attendance a = attendance.findById(adj.getAttendanceId()).orElseThrow();
        if ("LOCKED".equals(a.getPayrollStatus()))
            throw new BusinessException(ErrorCode.ATTENDANCE_LOCKED, "Công đã được chốt, cần mở lại kỳ công trước");
        ShiftAssignment sc = schedules.findById(a.getShiftAssignmentId()).orElseThrow();
        Map<String, Object> before = Map.of("checkIn", String.valueOf(a.getCheckInAt()), "checkOut", String.valueOf(a.getCheckOutAt()),
                "worked", String.valueOf(a.getWorkedMinutes()), "late", a.getLateMinutes());
        Instant nv = Instant.parse(adj.getNewValue());
        boolean checkIn = "CHECK_IN".equals(adj.getFieldName());
        Instant oldAt = checkIn ? a.getCheckInAt() : a.getCheckOutAt();
        if (checkIn) { a.setCheckInAt(nv); a.setCheckInMethod("MANUAL_APPROVAL"); }
        else { a.setCheckOutAt(nv); a.setCheckOutMethod("MANUAL_APPROVAL"); }
        // Lịch sử giá trị trước/sau (SRS 7.4 AttendanceAdjustmentHistory)
        AttendanceAdjustmentHistory h = new AttendanceAdjustmentHistory();
        h.setAttendanceAdjustmentRequestId(adj.getAttendanceAdjustmentRequestId());
        h.setAttendanceId(a.getAttendanceId());
        h.setFieldName(adj.getFieldName());
        h.setOldValue(oldAt == null ? null : oldAt.toString());
        h.setNewValue(nv.toString());
        h.setChangedBy(SecurityUtils.current().userId());
        h.setChangedAt(clock.instant());
        history.save(h);
        exemptGps(a, checkIn ? "CHECK_IN" : "CHECK_OUT");
        if (a.getCheckInAt() != null && a.getCheckOutAt() != null && !a.getCheckOutAt().isAfter(a.getCheckInAt()))
            throw BusinessException.rule("Sau điều chỉnh, giờ check-out phải sau giờ check-in");
        metrics.apply(a, sc, shifts.findById(sc.getWorkShiftId()).orElseThrow());
        adj.setHrStatus("APPROVED");
        adj.setHrReviewedBy(SecurityUtils.current().userId());
        adj.setHrReviewedAt(clock.instant());
        adjustments.saveAndFlush(adj);
        audit.log("ATTENDANCE_ADJUST_HR_APPROVE", "AttendanceAdjustmentRequest", id, before,
                Map.of("checkIn", String.valueOf(a.getCheckInAt()), "checkOut", String.valueOf(a.getCheckOutAt()),
                        "worked", String.valueOf(a.getWorkedMinutes()), "late", a.getLateMinutes()));
        notifications.notify(adj.getRequestedBy(), "ADJUSTMENT_REVIEWED", "Điều chỉnh công đã được áp dụng",
                "Công của bạn đã được cập nhật.", "AttendanceAdjustmentRequest", id, null);
        return view(adj);
    }

    @Transactional
    public AdjustmentView hrReject(Long id, String reason) {
        SecurityUtils.requirePermission(Permissions.ATTENDANCE_ADJUST_HR);
        needReason(reason);
        AttendanceAdjustmentRequest adj = find(id);
        requireNotSelf(adj);
        if (!"APPROVED".equals(adj.getManagerStatus()) || !"PENDING".equals(adj.getHrStatus()))
            throw BusinessException.invalidState("Yêu cầu không ở bước chờ HR");
        adj.setHrStatus("REJECTED");
        adj.setHrReviewedBy(SecurityUtils.current().userId());
        adj.setHrReviewedAt(clock.instant());
        adjustments.saveAndFlush(adj);
        audit.log("ATTENDANCE_ADJUST_HR_REJECT", "AttendanceAdjustmentRequest", id, null, Map.of("reason", reason));
        notifications.notify(adj.getRequestedBy(), "ADJUSTMENT_REVIEWED", "Yêu cầu điều chỉnh công bị từ chối", reason, "AttendanceAdjustmentRequest", id, null);
        return view(adj);
    }

    private AttendanceAdjustmentRequest find(Long id) {
        return adjustments.findById(id).orElseThrow(() -> BusinessException.notFound("yêu cầu điều chỉnh"));
    }

    private void requireNotSelf(AttendanceAdjustmentRequest a) {
        if (a.getRequestedBy().equals(SecurityUtils.current().userId()))
            throw BusinessException.forbidden("Không thể tự duyệt yêu cầu của chính mình");
    }

    private static void needReason(String r) {
        if (r == null || r.isBlank()) throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Phải nhập lý do từ chối");
    }

    /** Điều chỉnh thủ công: GPS EXEMPTED để kết quả xác minh phản ánh cách công được duyệt (SRS 7.4). */
    private void exemptGps(Attendance a, String event) {
        AttendanceVerification v = new AttendanceVerification();
        v.setAttendanceId(a.getAttendanceId());
        v.setEventType(event);
        v.setVerificationType("GPS");
        v.setVerificationStatus("EXEMPTED");
        v.setFailureReason("Điều chỉnh thủ công qua đơn điều chỉnh");
        v.setVerifiedAt(clock.instant());
        verifications.save(v);
    }
}
