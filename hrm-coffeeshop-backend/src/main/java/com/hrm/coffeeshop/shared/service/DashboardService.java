package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.shared.dto.AttendanceDto.StatsView;

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

/** Dashboard & báo cáo: chỉ đọc, số liệu tính từ dữ liệu gốc (không cache). */
@Service
public class DashboardService {
    private final AttendanceStatsService stats;
    private final AttendanceDeviceRepository devices;
    private final AttendanceExceptionRequestRepository exceptions;
    private final OvertimeRequestRepository overtime;
    private final AttendanceAdjustmentRequestRepository adjustments;
    private final ChecklistTaskRepository runs;
    private final EmployeeDocumentRepository docs;
    private final EmployeeRewardPenaltyRepository decisions;
    private final ViolationEventRepository violations;
    private final EmployeeRepository employees;
    private final ShiftAssignmentRepository schedules;
    private final AttendanceRepository attendance;
    private final NotificationRepository notificationRepo;
    private final DocumentService documents;
    private final TrainingService training;
    private final PersonLookup people;
    private final Clock clock;

    public DashboardService(AttendanceStatsService stats, AttendanceDeviceRepository devices,
                            AttendanceExceptionRequestRepository exceptions, OvertimeRequestRepository overtime,
                            AttendanceAdjustmentRequestRepository adjustments, ChecklistTaskRepository runs, EmployeeDocumentRepository docs,
                            EmployeeRewardPenaltyRepository decisions, ViolationEventRepository violations,
                            EmployeeRepository employees, ShiftAssignmentRepository schedules,
                            AttendanceRepository attendance, NotificationRepository notificationRepo,
                            DocumentService documents, TrainingService training, PersonLookup people, Clock clock) {
        this.stats = stats;
        this.devices = devices;
        this.exceptions = exceptions;
        this.overtime = overtime;
        this.adjustments = adjustments;
        this.runs = runs;
        this.docs = docs;
        this.decisions = decisions;
        this.violations = violations;
        this.employees = employees;
        this.schedules = schedules;
        this.attendance = attendance;
        this.notificationRepo = notificationRepo;
        this.documents = documents;
        this.training = training;
        this.people = people;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public Map<String, Object> managerOverview() {
        LocalDate today = TimeUtils.today(clock);
        Map<String, Long> pending = new LinkedHashMap<>();
        pending.put("devices", devices.countByStatus("PENDING"));
        pending.put("explanations", exceptions.countByRequestStatus("PENDING"));
        pending.put("overtime", overtime.countByApprovalStatus("PENDING"));
        pending.put("adjustmentsAwaitingManager", adjustments.countByManagerStatus("PENDING"));
        pending.put("adjustmentsAwaitingHr", adjustments.countByManagerStatusAndHrStatus("APPROVED", "PENDING"));
        pending.put("checklistReviews", runs.countByRunStatus("SUBMITTED"));
        pending.put("documents", docs.countByReviewStatus("PENDING"));
        pending.put("violations", violations.countByRecordStatus("PENDING"));
        pending.put("rewardsAndPenalties", decisions.countByDecisionStatus("PENDING"));
        List<Map<String, Object>> next = new ArrayList<>();
        pending.entrySet().stream().filter(e -> e.getValue() > 0).sorted((a, b) -> Long.compare(b.getValue(), a.getValue()))
                .forEach(e -> next.add(Map.of("queue", e.getKey(), "count", e.getValue())));
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("date", today);
        out.put("attendanceToday", stats.stats(today, today, null, null));
        out.put("pending", pending);
        out.put("nextActions", next);
        return out;
    }

    @Transactional(readOnly = true)
    public StatsView attendance(LocalDate from, LocalDate to, Integer shiftId) { return stats.stats(from, to, shiftId, null); }

    @Transactional(readOnly = true)
    public Map<String, Object> employeeStatus() {
        Map<String, Integer> byEmployment = new TreeMap<>(), byProfile = new TreeMap<>();
        int restricted = 0;
        for (Employee e : employees.findAll()) {
            byEmployment.merge(e.getEmploymentStatus(), 1, Integer::sum);
            if (!"ACTIVE".equals(e.getEmploymentStatus())) continue;
            byProfile.merge(documents.profile(e).profileStatus(), 1, Integer::sum);
            if (!training.eligibility(e).eligible()) restricted++;
        }
        return Map.of("employmentStatus", byEmployment, "profileStatus", byProfile, "shiftRestricted", restricted);
    }

    @Transactional(readOnly = true)
    public Map<String, Object> operations(LocalDate from, LocalDate to) {
        Instant f = TimeUtils.startOfDay(from), t = TimeUtils.startOfDay(to.plusDays(1));
        Map<String, Integer> byStatus = new TreeMap<>();
        int total = 0;
        for (ChecklistTask r : runs.findByDueAtBetween(f, t)) { byStatus.merge(r.getRunStatus(), 1, Integer::sum); total++; }
        int completed = byStatus.getOrDefault("APPROVED", 0);
        return Map.of("from", from, "to", to, "totalChecklists", total, "byStatus", byStatus,
                "completionRatePercent", total == 0 ? 0 : Math.round(completed * 1000.0 / total) / 10.0);
    }

    @Transactional(readOnly = true)
    public Map<String, Object> rewardsPenalties(LocalDate from, LocalDate to) {
        Instant f = TimeUtils.startOfDay(from), t = TimeUtils.startOfDay(to.plusDays(1));
        BigDecimal rw = BigDecimal.ZERO, pn = BigDecimal.ZERO;
        int rc = 0, pc = 0;
        for (EmployeeRewardPenalty r : decisions.findApprovedBetween(f, t)) {
            if ("REWARD".equals(r.getDecisionType())) { rc++; if (r.getAmount() != null) rw = rw.add(r.getAmount()); }
            else { pc++; if (r.getAmount() != null) pn = pn.add(r.getAmount()); }
        }
        return Map.of("from", from, "to", to, "approvedRewards", rc, "rewardTotal", rw, "approvedPenalties", pc, "penaltyTotal", pn,
                "pendingDecisions", decisions.countByDecisionStatus("PENDING"));
    }

    @Transactional(readOnly = true)
    public Map<String, Object> employeeOverview() {
        Long empId = SecurityUtils.requireEmployeeId();
        AuthUser u = SecurityUtils.current();
        Employee e = employees.findById(empId).orElseThrow();
        Instant now = clock.instant();
        Optional<ShiftAssignment> next = schedules
                .findByEmployeeIdAndWorkDateBetweenOrderByPlannedStartAtAsc(empId, TimeUtils.today(clock).minusDays(1), TimeUtils.today(clock).plusDays(14))
                .stream().filter(s -> "PUBLISHED".equals(s.getScheduleStatus()) && s.getPlannedEndAt().isAfter(now)).findFirst();
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("nextShift", next.map(s -> Map.of("scheduleId", s.getShiftAssignmentId(), "plannedStartAt", TimeUtils.vn(s.getPlannedStartAt()),
                "plannedEndAt", TimeUtils.vn(s.getPlannedEndAt()))).orElse(null));
        out.put("profileStatus", documents.profile(e).profileStatus());
        out.put("shiftEligibility", training.eligibility(e).eligible() ? "ELIGIBLE" : "RESTRICTED");
        out.put("openChecklists", runs.findMine(empId, List.of("PENDING", "IN_PROGRESS", "OVERDUE", "REJECTED")).size());
        out.put("unreadNotifications", notificationRepo.countByUserIdAndReadAtIsNull(u.userId()));
        return out;
    }

    /** Báo cáo chấm công theo nhân viên trong khoảng ngày. */
    @Transactional(readOnly = true)
    public List<Map<String, Object>> attendanceReport(LocalDate from, LocalDate to) {
        List<ShiftAssignment> scs = schedules.findForStats(from, to, 0, 0L);
        Map<Long, Attendance> recs = new HashMap<>();
        if (!scs.isEmpty()) attendance.findByShiftAssignmentIdIn(scs.stream().map(ShiftAssignment::getShiftAssignmentId).toList())
                .forEach(r -> recs.put(r.getShiftAssignmentId(), r));
        Instant now = clock.instant();
        Map<Long, long[]> acc = new TreeMap<>();   // 0 shifts,1 late count,2 late min,3 absent,4 worked,5 ot
        for (ShiftAssignment s : scs) {
            long[] a = acc.computeIfAbsent(s.getEmployeeId(), k -> new long[6]);
            a[0]++;
            Attendance r = recs.get(s.getShiftAssignmentId());
            if (r == null || r.getCheckInAt() == null) { if (s.getPlannedEndAt().isBefore(now)) a[3]++; continue; }
            if (r.getLateMinutes() > 0) { a[1]++; a[2] += r.getLateMinutes(); }
            a[4] += r.getWorkedMinutes() == null ? 0 : r.getWorkedMinutes();
            a[5] += r.getApprovedOTMinutes();
        }
        List<Map<String, Object>> rows = new ArrayList<>();
        acc.forEach((id, a) -> rows.add(Map.of("employeeId", id, "employeeName", String.valueOf(people.nameOf(id)),
                "scheduledShifts", a[0], "lateCount", a[1], "lateMinutes", a[2], "absentShifts", a[3],
                "workedMinutes", a[4], "approvedOvertimeMinutes", a[5])));
        return rows;
    }
}
