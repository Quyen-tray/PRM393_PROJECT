package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.shared.dto.AttendanceDto.OvertimeRequestDto;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.OvertimeView;

import com.hrm.coffeeshop.common.*;
import com.hrm.coffeeshop.domain.*;
import com.hrm.coffeeshop.repository.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Map;

/** OT: giờ ra muộn KHÔNG tự thành OT; chỉ OT có yêu cầu và được duyệt mới được tính (BR-OT-01). */
@Service
public class OvertimeService {
    private final OvertimeRequestRepository requests;
    private final AttendanceRepository attendance;
    private final ShiftAssignmentRepository schedules;
    private final WorkShiftRepository shifts;
    private final AttendanceMetricsService metrics;
    private final PersonLookup people;
    private final NotificationService notifications;
    private final AuditService audit;
    private final PayrollLockGuard lockGuard;
    private final Clock clock;
    private final long maxOtMinutes;

    public OvertimeService(OvertimeRequestRepository requests, AttendanceRepository attendance,
                           ShiftAssignmentRepository schedules, WorkShiftRepository shifts,
                           AttendanceMetricsService metrics, PersonLookup people, NotificationService notifications,
                           AuditService audit, PayrollLockGuard lockGuard, Clock clock,
                           @Value("${app.overtime.max-minutes:240}") long maxOtMinutes) {
        this.requests = requests;
        this.attendance = attendance;
        this.schedules = schedules;
        this.shifts = shifts;
        this.metrics = metrics;
        this.people = people;
        this.notifications = notifications;
        this.audit = audit;
        this.lockGuard = lockGuard;
        this.clock = clock;
        this.maxOtMinutes = maxOtMinutes;
    }

    /**
     * DEC-OT: OT chỉ hợp lệ khi bắt đầu từ plannedEndAt của ca trở đi; giờ kết thúc phải sau giờ bắt đầu;
     * thời lượng không vượt giới hạn chính sách. Hàm thuần để kiểm thử đơn vị.
     */
    public static void requireValidInterval(Instant plannedEnd, Instant start, Instant end, long maxMinutes) {
        if (start.isBefore(plannedEnd))
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "OT chỉ được bắt đầu sau khi ca kết thúc");
        if (!end.isAfter(start))
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Khoảng OT không hợp lệ: giờ kết thúc phải sau giờ bắt đầu");
        long minutes = java.time.Duration.between(start, end).toMinutes();
        if (minutes > maxMinutes)
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Thời lượng OT vượt giới hạn " + maxMinutes + " phút");
    }

    static OvertimeView view(OvertimeRequest r) {
        return new OvertimeView(r.getOvertimeRequestId(), r.getShiftAssignmentId(), r.getEmployeeId(), TimeUtils.vn(r.getRequestedStartAt()),
                TimeUtils.vn(r.getRequestedEndAt()), r.getReason(), r.getApprovalStatus(), TimeUtils.vn(r.getReviewedAt()), r.getReviewNote());
    }

    @Transactional
    public OvertimeView create(Long attendanceId, OvertimeRequestDto d) {
        Long empId = SecurityUtils.requireEmployeeId();
        Attendance a = attendance.findById(attendanceId).filter(x -> x.getEmployeeId().equals(empId))
                .orElseThrow(() -> BusinessException.notFound("bản ghi chấm công"));
        if ("LOCKED".equals(a.getPayrollStatus()))
            throw new BusinessException(ErrorCode.ATTENDANCE_LOCKED, "Công đã được chốt");
        // Khóa dòng phân ca: hai yêu cầu OT cùng ca phải xếp hàng, nếu không cả hai có thể cùng qua kiểm tra trùng khoảng.
        ShiftAssignment sc = schedules.findByIdForUpdate(a.getShiftAssignmentId()).orElseThrow();
        lockGuard.assertWorkDateOpen(sc.getWorkDate());
        Instant s = d.requestedStartAt().toInstant(), e = d.requestedEndAt().toInstant();
        requireValidInterval(sc.getPlannedEndAt(), s, e, maxOtMinutes);
        for (OvertimeRequest o : requests.findByShiftAssignmentIdAndApprovalStatusIn(sc.getShiftAssignmentId(), List.of("PENDING", "APPROVED")))
            if (s.isBefore(o.getRequestedEndAt()) && e.isAfter(o.getRequestedStartAt()))
                throw new BusinessException(ErrorCode.CONFLICT, "Khoảng OT trùng với yêu cầu OT khác");
        OvertimeRequest r = new OvertimeRequest();
        r.setShiftAssignmentId(sc.getShiftAssignmentId());
        r.setEmployeeId(empId);
        r.setRequestedStartAt(s);
        r.setRequestedEndAt(e);
        r.setReason(d.reason().trim());
        requests.save(r);
        audit.log("OVERTIME_REQUEST", "OvertimeRequest", r.getOvertimeRequestId(), null, Map.of("scheduleId", sc.getShiftAssignmentId()));
        notifications.notifyRole(Roles.STORE_MANAGER, "OVERTIME_PENDING", "Có yêu cầu OT chờ duyệt",
                people.nameOf(empId) + " xin làm thêm giờ", "OvertimeRequest", r.getOvertimeRequestId());
        return view(r);
    }

    /** Yêu cầu OT do chính nhân viên gửi (50 đơn gần nhất). */
    @Transactional(readOnly = true)
    public List<OvertimeView> mine() {
        return requests.findTop50ByEmployeeIdOrderByRequestedAtDesc(SecurityUtils.requireEmployeeId()).stream()
                .map(OvertimeService::view).toList();
    }

    @Transactional(readOnly = true)
    public PageResponse<OvertimeView> list(String status, Pageable p) {
        String st = status == null || status.isBlank() ? "PENDING" : status;
        return PageResponse.of(requests.findByApprovalStatusOrderByRequestedAtAsc(st, p), OvertimeService::view);
    }

    @Transactional
    public OvertimeView approve(Long id, String note) { return decide(id, "APPROVED", note); }

    @Transactional
    public OvertimeView reject(Long id, String reason) {
        if (reason == null || reason.isBlank()) throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Phải nhập lý do từ chối");
        return decide(id, "REJECTED", reason.trim());
    }

    private OvertimeView decide(Long id, String status, String note) {
        SecurityUtils.requireAny(Roles.STORE_MANAGER);
        OvertimeRequest r = requests.findById(id).orElseThrow(() -> BusinessException.notFound("yêu cầu OT"));
        // Khóa kỳ công trước khi nạp/ghi bản ghi công (metrics.apply bên dưới). Trạng thái yêu cầu được bảo vệ thêm bởi RowVersion.
        lockGuard.assertWorkDateOpen(schedules.findById(r.getShiftAssignmentId()).orElseThrow().getWorkDate());
        if (!"PENDING".equals(r.getApprovalStatus())) throw BusinessException.invalidState("Yêu cầu không ở trạng thái chờ duyệt");
        if (people.userIdOf(r.getEmployeeId()).equals(SecurityUtils.current().userId()))
            throw BusinessException.forbidden("Không thể tự duyệt OT của chính mình");
        Attendance a = attendance.findByShiftAssignmentId(r.getShiftAssignmentId()).orElse(null);
        if (a != null && "LOCKED".equals(a.getPayrollStatus()))
            throw new BusinessException(ErrorCode.ATTENDANCE_LOCKED, "Công đã được chốt");
        r.setApprovalStatus(status);
        r.setReviewedBy(SecurityUtils.current().userId());
        r.setReviewedAt(clock.instant());
        r.setReviewNote(note);
        requests.saveAndFlush(r);
        if (a != null && a.getCheckOutAt() != null) {
            ShiftAssignment sc = schedules.findById(a.getShiftAssignmentId()).orElseThrow();
            metrics.apply(a, sc, shifts.findById(sc.getWorkShiftId()).orElseThrow());
        }
        audit.log("OVERTIME_" + status, "OvertimeRequest", id, null, Map.of("note", String.valueOf(note)));
        notifications.notify(people.userIdOf(r.getEmployeeId()), "OVERTIME_REVIEWED", "Kết quả duyệt OT",
                "APPROVED".equals(status) ? "Yêu cầu OT đã được duyệt." : "Yêu cầu OT bị từ chối: " + note,
                "OvertimeRequest", id, null);
        return view(r);
    }
}
