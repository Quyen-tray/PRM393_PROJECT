package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.shared.dto.PayrollDto.Blocker;
import com.hrm.coffeeshop.shared.dto.PayrollDto.PeriodRequest;
import com.hrm.coffeeshop.shared.dto.PayrollDto.PeriodView;
import com.hrm.coffeeshop.shared.dto.PayrollDto.ReadinessView;

import com.hrm.coffeeshop.common.*;
import com.hrm.coffeeshop.domain.*;
import com.hrm.coffeeshop.repository.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.util.*;
import java.util.stream.Collectors;

/**
 * Kỳ công: OPEN → (Quản lý xác nhận) HR_REVIEW → (HR chốt) LOCKED. Mở lại chỉ SYSTEM_ADMIN/OPERATIONS_DIRECTOR kèm lý do.
 * Chốt bị chặn khi còn điều chỉnh / OT / giải trình chờ xử lý hoặc quên check-out (BR-PAY-01).
 */
@Service
public class PayrollService {
    private final PayrollPeriodRepository periods;
    private final ShiftAssignmentRepository schedules;
    private final WorkShiftRepository shifts;
    private final AttendanceRepository attendance;
    private final AttendanceAdjustmentRequestRepository adjustments;
    private final OvertimeRequestRepository overtime;
    private final AttendanceExceptionRequestRepository exceptions;
    private final EmployeeRewardPenaltyRepository decisions;
    private final PersonLookup people;
    private final NotificationService notifications;
    private final AuditService audit;
    private final StoreService storeService;
    private final Clock clock;

    public PayrollService(PayrollPeriodRepository periods, ShiftAssignmentRepository schedules,
                          WorkShiftRepository shifts, AttendanceRepository attendance,
                          AttendanceAdjustmentRequestRepository adjustments, OvertimeRequestRepository overtime,
                          AttendanceExceptionRequestRepository exceptions, EmployeeRewardPenaltyRepository decisions,
                          PersonLookup people,
                          NotificationService notifications, AuditService audit, StoreService storeService, Clock clock) {
        this.periods = periods;
        this.schedules = schedules;
        this.shifts = shifts;
        this.attendance = attendance;
        this.adjustments = adjustments;
        this.overtime = overtime;
        this.exceptions = exceptions;
        this.decisions = decisions;
        this.people = people;
        this.notifications = notifications;
        this.audit = audit;
        this.storeService = storeService;
        this.clock = clock;
    }

    /** Trạng thái kỳ công theo SRS 8.5: DRAFT, REVIEWING, READY, FINALIZED, REOPENED (NOT_READY nằm ở readiness). */
    static String apiStatus(PayrollPeriod p) {
        return switch (p.getPeriodStatus()) {
            case "LOCKED" -> "FINALIZED";
            case "APPROVED" -> "READY";
            case "MANAGER_REVIEW", "HR_REVIEW" -> "REVIEWING";
            default -> p.getReopenedAt() != null ? "REOPENED" : "DRAFT";
        };
    }

    static PeriodView view(PayrollPeriod p) {
        return new PeriodView(p.getPayrollPeriodId(), p.getPeriodCode(), p.getStartDate(), p.getEndDate(), apiStatus(p),
                TimeUtils.vn(p.getManagerApprovedAt()), TimeUtils.vn(p.getHrApprovedAt()), TimeUtils.vn(p.getLockedAt()), p.getNote());
    }

    @Transactional(readOnly = true)
    public List<PeriodView> list() { return periods.findAllByOrderByStartDateDesc().stream().map(PayrollService::view).toList(); }

    @Transactional
    public PeriodView create(PeriodRequest r) {
        SecurityUtils.requirePermission(Permissions.PAYROLL_PERIOD_MANAGE);
        storeService.lockCurrentForUpdate();    // khóa TRƯỚC khi kiểm tra trùng mã và trùng ngày
        if (r.endDate().isBefore(r.startDate())) throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Ngày kết thúc phải sau ngày bắt đầu");
        if (periods.findByPeriodCode(r.periodCode()).isPresent()) throw new BusinessException(ErrorCode.CONFLICT, "Mã kỳ công đã tồn tại");
        if (periods.existsOverlap(r.startDate(), r.endDate())) throw new BusinessException(ErrorCode.CONFLICT, "Kỳ công trùng với kỳ đã có");
        PayrollPeriod p = new PayrollPeriod();
        p.setPeriodCode(r.periodCode().trim());
        p.setStartDate(r.startDate());
        p.setEndDate(r.endDate());
        p.setNote(r.note());
        p.setCreatedBy(SecurityUtils.current().userId());
        periods.save(p);
        audit.log("PAYROLL_PERIOD_CREATE", "PayrollPeriod", p.getPayrollPeriodId(), null, view(p));
        return view(p);
    }

    @Transactional(readOnly = true)
    public ReadinessView readiness(Long periodId) { return readiness(find(periodId)); }

    public ReadinessView readiness(PayrollPeriod p) {
        List<ShiftAssignment> scs = schedules.findForStats(p.getStartDate(), p.getEndDate(), 0, 0L);
        List<Long> scheduleIds = scs.stream().map(ShiftAssignment::getShiftAssignmentId).toList();
        Map<Long, Attendance> recs = new HashMap<>();
        if (!scheduleIds.isEmpty()) attendance.findByShiftAssignmentIdIn(scheduleIds).forEach(r -> recs.put(r.getShiftAssignmentId(), r));
        Instant now = clock.instant();

        List<Long> missing = new ArrayList<>(), unattendedEnded = new ArrayList<>();
        int absent = 0;
        for (ShiftAssignment s : scs) {
            Attendance r = recs.get(s.getShiftAssignmentId());
            boolean ended = s.getPlannedEndAt().isBefore(now);
            if (r == null || r.getCheckInAt() == null) {
                if (ended) { absent++; unattendedEnded.add(s.getShiftAssignmentId()); }
            } else if (r.getCheckOutAt() == null && ended) missing.add(r.getAttendanceId());
        }

        // DEC-ABS: ca đã kết thúc không có chấm công chỉ được chốt khi có đơn ABSENCE ĐÃ DUYỆT.
        Map<Long, String> absenceStatus = latestAbsenceStatus(unattendedEnded);
        List<Long> noAbsenceRequest = new ArrayList<>(), pendingAbsence = new ArrayList<>(), rejectedAbsence = new ArrayList<>();
        for (Long sid : unattendedEnded) {
            String st = absenceStatus.get(sid);
            if (st == null || "CANCELLED".equals(st)) noAbsenceRequest.add(sid);
            else if ("PENDING".equals(st)) pendingAbsence.add(sid);
            else if ("REJECTED".equals(st)) rejectedAbsence.add(sid);
            // APPROVED: đã được quản lý xác nhận, không chặn
        }

        List<Long> attIds = recs.values().stream().map(Attendance::getAttendanceId).toList();
        List<Long> adj = attIds.isEmpty() ? List.of() : adjustments.findByAttendanceIdIn(attIds).stream()
                .filter(a -> AttendanceAdjustmentService.status(a).startsWith("PENDING")).map(AttendanceAdjustmentRequest::getAttendanceAdjustmentRequestId).toList();
        List<Long> ot = scheduleIds.isEmpty() ? List.of() : overtime.findByShiftAssignmentIdInAndApprovalStatus(scheduleIds, "PENDING").stream()
                .map(OvertimeRequest::getOvertimeRequestId).toList();
        // Đơn ABSENCE chờ duyệt được tính qua blocker riêng, không đếm lẫn với giải trình thường.
        List<Long> ex = scheduleIds.isEmpty() ? List.of() : exceptions.findByShiftAssignmentIdInAndRequestStatus(scheduleIds, "PENDING").stream()
                .filter(x -> !"ABSENCE".equals(x.getRequestType()))
                .map(AttendanceExceptionRequest::getExceptionRequestId).toList();

        List<Blocker> blockers = new ArrayList<>();
        addBlocker(blockers, "PENDING_ADJUSTMENT", adj);
        addBlocker(blockers, "PENDING_OVERTIME", ot);
        addBlocker(blockers, "UNRESOLVED_EXCEPTION", ex);
        addBlocker(blockers, "MISSING_CHECK_OUT", missing);
        addBlocker(blockers, "MISSING_ABSENCE_REQUEST", noAbsenceRequest);   // id là id phân ca
        addBlocker(blockers, "PENDING_ABSENCE", pendingAbsence);             // id là id phân ca
        addBlocker(blockers, "REJECTED_ABSENCE", rejectedAbsence);           // id là id phân ca
        boolean can = blockers.isEmpty();
        String status = "LOCKED".equals(p.getPeriodStatus()) ? "FINALIZED" : can ? "READY" : "NOT_READY";
        int emps = (int) scs.stream().map(ShiftAssignment::getEmployeeId).distinct().count();
        return new ReadinessView(p.getPayrollPeriodId(), status, p.getPeriodStatus(), emps, adj.size(), ot.size(), ex.size(),
                missing.size(), absent, can, blockers);
    }

    /** Trạng thái của đơn ABSENCE mới nhất cho từng ca (nếu có). */
    private Map<Long, String> latestAbsenceStatus(List<Long> shiftIds) {
        if (shiftIds.isEmpty()) return Map.of();
        Map<Long, AttendanceExceptionRequest> latest = new HashMap<>();
        for (AttendanceExceptionRequest e : exceptions.findByShiftAssignmentIdInAndRequestType(shiftIds, "ABSENCE"))
            latest.merge(e.getShiftAssignmentId(), e,
                    (x, y) -> x.getExceptionRequestId() >= y.getExceptionRequestId() ? x : y);
        Map<Long, String> out = new HashMap<>();
        latest.forEach((k, v) -> out.put(k, v.getRequestStatus()));
        return out;
    }

    /**
     * DEC-ABS: tạo đơn ABSENCE ở trạng thái PENDING cho mỗi ca đã kết thúc không có chấm công
     * mà chưa có đơn đang chờ hoặc đã duyệt. Đơn bị từ chối có thể được tạo lại.
     */
    @Transactional
    public Map<String, Object> generateAbsenceRequests(Long periodId) {
        SecurityUtils.requireAny(Roles.STORE_MANAGER);
        PayrollPeriod p = lockForUpdate(periodId);
        if ("LOCKED".equals(p.getPeriodStatus()))
            throw new BusinessException(ErrorCode.PAYROLL_PERIOD_LOCKED, "Kỳ công đã được chốt");
        List<ShiftAssignment> scs = schedules.findForStats(p.getStartDate(), p.getEndDate(), 0, 0L);
        List<Long> ids = scs.stream().map(ShiftAssignment::getShiftAssignmentId).toList();
        Set<Long> withCheckIn = new HashSet<>();
        if (!ids.isEmpty())
            attendance.findByShiftAssignmentIdIn(ids).forEach(r -> { if (r.getCheckInAt() != null) withCheckIn.add(r.getShiftAssignmentId()); });
        Instant now = clock.instant();
        List<ShiftAssignment> unattended = scs.stream()
                .filter(s -> !withCheckIn.contains(s.getShiftAssignmentId()) && s.getPlannedEndAt().isBefore(now))
                .toList();
        Map<Long, String> latest = latestAbsenceStatus(unattended.stream().map(ShiftAssignment::getShiftAssignmentId).toList());
        int created = 0;
        for (ShiftAssignment s : unattended) {
            String st = latest.get(s.getShiftAssignmentId());
            if (st != null && !"REJECTED".equals(st) && !"CANCELLED".equals(st)) continue;   // đã có đơn PENDING/APPROVED
            AttendanceExceptionRequest ex = new AttendanceExceptionRequest();
            ex.setEmployeeId(s.getEmployeeId());
            ex.setShiftAssignmentId(s.getShiftAssignmentId());
            ex.setRequestType("ABSENCE");
            ex.setReason("Ca ngày " + s.getWorkDate() + " không có chấm công, chờ quản lý xác nhận");
            ex.setRequestStatus("PENDING");
            exceptions.save(ex);
            audit.log("ABSENCE_REQUEST_GENERATE", "AttendanceExceptionRequest", ex.getExceptionRequestId(), null,
                    Map.of("scheduleId", s.getShiftAssignmentId(), "periodId", periodId));
            created++;
        }
        return Map.<String, Object>of("created", created);
    }

    private static void addBlocker(List<Blocker> out, String type, List<Long> ids) {
        if (!ids.isEmpty()) out.add(new Blocker(type, ids.size(), ids.subList(0, Math.min(ids.size(), 50))));
    }

    @Transactional
    public PeriodView managerConfirm(Long periodId) {
        SecurityUtils.requireAny(Roles.STORE_MANAGER);
        PayrollPeriod p = lockForUpdate(periodId);
        if (!List.of("OPEN", "MANAGER_REVIEW").contains(p.getPeriodStatus()))
            throw new BusinessException(ErrorCode.INVALID_STATE, "Kỳ công không ở bước quản lý xác nhận");
        for (ShiftAssignment s : schedules.findForStats(p.getStartDate(), p.getEndDate(), 0, 0L))
            attendance.findByShiftAssignmentId(s.getShiftAssignmentId()).ifPresent(a -> { if ("OPEN".equals(a.getPayrollStatus())) a.setPayrollStatus("MANAGER_APPROVED"); });
        p.setPeriodStatus("HR_REVIEW");
        p.setManagerApprovedBy(SecurityUtils.current().userId());
        p.setManagerApprovedAt(clock.instant());
        audit.log("PAYROLL_MANAGER_CONFIRM", "PayrollPeriod", periodId, null, Map.of("status", "HR_REVIEW"));
        notifications.notifyPermission(Permissions.PAYROLL_FINALIZE, "PAYROLL_HR_REVIEW", "Kỳ công " + p.getPeriodCode() + " chờ HR chốt",
                "Quản lý đã xác nhận.", "PayrollPeriod", periodId);
        return view(p);
    }

    @Transactional
    public PeriodView hrFinalize(Long periodId) {
        SecurityUtils.requirePermission(Permissions.PAYROLL_FINALIZE);
        // Khóa kỳ TRƯỚC khi đọc readiness và ghi LOCKED: check-in đang chạy trên cùng kỳ phải commit xong
        // (để bản ghi của nó được tính vào readiness và khóa), hoặc chờ đến khi kỳ đã LOCKED rồi bị từ chối.
        PayrollPeriod p = lockForUpdate(periodId);
        if ("LOCKED".equals(p.getPeriodStatus())) throw new BusinessException(ErrorCode.PAYROLL_PERIOD_LOCKED, "Kỳ công đã được chốt");
        if (!"HR_REVIEW".equals(p.getPeriodStatus()))
            throw new BusinessException(ErrorCode.INVALID_STATE, "Cần Quản lý xác nhận trước khi HR chốt");
        if (!p.getEndDate().isBefore(TimeUtils.today(clock)))
            throw new BusinessException(ErrorCode.INVALID_STATE, "Chỉ chốt kỳ công sau khi kỳ đã kết thúc");
        ReadinessView rd = readiness(p);
        if (!rd.canFinalize())
            throw new BusinessException(ErrorCode.PAYROLL_NOT_READY, "Kỳ công chưa sẵn sàng để chốt", rd.asDetails());
        for (ShiftAssignment s : schedules.findForStats(p.getStartDate(), p.getEndDate(), 0, 0L))
            attendance.findByShiftAssignmentId(s.getShiftAssignmentId()).ifPresent(a -> a.setPayrollStatus("LOCKED"));
        Instant now = clock.instant();
        Long uid = SecurityUtils.current().userId();
        p.setHrApprovedBy(uid);
        p.setHrApprovedAt(now);
        p.setLockedBy(uid);
        p.setLockedAt(now);
        p.setPeriodStatus("LOCKED");
        audit.log("PAYROLL_FINALIZE", "PayrollPeriod", periodId, Map.of("status", "HR_REVIEW"),
                Map.of("status", "LOCKED", "employees", rd.totalEmployees()));
        return view(p);
    }

    @Transactional
    public PeriodView reopen(Long periodId, String reason) {
        SecurityUtils.requirePermission(Permissions.PAYROLL_REOPEN);
        if (reason == null || reason.isBlank()) throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Phải nhập lý do mở lại kỳ công");
        PayrollPeriod p = lockForUpdate(periodId);
        if (!"LOCKED".equals(p.getPeriodStatus())) throw new BusinessException(ErrorCode.INVALID_STATE, "Chỉ mở lại kỳ công đã chốt");
        for (ShiftAssignment s : schedules.findForStats(p.getStartDate(), p.getEndDate(), 0, 0L))
            attendance.findByShiftAssignmentId(s.getShiftAssignmentId()).ifPresent(a -> a.setPayrollStatus("OPEN"));
        p.setPeriodStatus("OPEN");
        p.setReopenedAt(clock.instant());
        p.setManagerApprovedBy(null); p.setManagerApprovedAt(null);
        p.setHrApprovedBy(null); p.setHrApprovedAt(null);
        p.setLockedBy(null); p.setLockedAt(null);
        String note = "Reopened: " + reason.trim();
        p.setNote(note.substring(0, Math.min(note.length(), 500)));
        audit.log("PAYROLL_REOPEN", "PayrollPeriod", periodId, Map.of("status", "LOCKED"), Map.of("status", "OPEN", "reason", reason));
        notifications.notifyPermission(Permissions.PAYROLL_FINALIZE, "PAYROLL_REOPENED", "Kỳ công " + p.getPeriodCode() + " đã được mở lại", reason, "PayrollPeriod", periodId);
        return view(p);
    }

    private PayrollPeriod find(Long id) { return periods.findById(id).orElseThrow(() -> BusinessException.notFound("kỳ công")); }

    /** Khóa dòng kỳ công (xem PayrollPeriodRepository.findByIdForUpdate). Dùng cho mọi thao tác đổi trạng thái kỳ. */
    private PayrollPeriod lockForUpdate(Long id) {
        return periods.findByIdForUpdate(id).orElseThrow(() -> BusinessException.notFound("kỳ công"));
    }
}
