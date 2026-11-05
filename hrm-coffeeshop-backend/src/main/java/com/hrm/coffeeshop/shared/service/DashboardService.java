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
    private final EmployeeSkillRepository skills;

    public DashboardService(AttendanceStatsService stats, AttendanceDeviceRepository devices,
                            AttendanceExceptionRequestRepository exceptions, OvertimeRequestRepository overtime,
                            AttendanceAdjustmentRequestRepository adjustments, ChecklistTaskRepository runs, EmployeeDocumentRepository docs,
                            EmployeeRewardPenaltyRepository decisions, ViolationEventRepository violations,
                            EmployeeRepository employees, ShiftAssignmentRepository schedules,
                            AttendanceRepository attendance, NotificationRepository notificationRepo,
                            DocumentService documents, TrainingService training, PersonLookup people, Clock clock,
                            EmployeeSkillRepository skills) {
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
        this.skills = skills;
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
        filterQueues(pending);
        List<Map<String, Object>> next = actions(pending);
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("date", today);
        out.put("attendanceToday", stats.stats(today, today, null, null));
        out.put("pending", pending);
        out.put("nextActions", next);
        return out;
    }

    private void filterQueues(Map<String, Long> pending) {
        AuthUser user = SecurityUtils.current();
        Map<String, String> permissions = Map.of("devices", Permissions.DEVICE_APPROVE,
                "adjustmentsAwaitingHr", Permissions.ATTENDANCE_ADJUST_HR, "checklistReviews", Permissions.CHECKLIST_REVIEW,
                "documents", Permissions.DOCUMENT_REVIEW, "violations", Permissions.VIOLATION_REVIEW,
                "rewardsAndPenalties", Permissions.REWARD_VIEW);
        pending.entrySet().removeIf(e -> permissions.containsKey(e.getKey()) ? !user.hasPermission(permissions.get(e.getKey()))
                : !user.hasAny(Roles.STORE_MANAGER));
        if (user.hasPermission(Permissions.TRAINING_MANAGE) || user.hasAny(Roles.SYSTEM_ADMIN))
            pending.put("trainingReviews", (long) training.pendingCompletionReviews().size());
    }

    private static List<Map<String, Object>> actions(Map<String, Long> pending) {
        // Stable operational order; no unapproved SLA/urgency thresholds.
        List<String> order = List.of("devices", "explanations", "adjustmentsAwaitingManager", "adjustmentsAwaitingHr",
                "overtime", "checklistReviews", "trainingReviews", "documents", "violations", "rewardsAndPenalties");
        List<Map<String, Object>> result = new ArrayList<>();
        for (String queue : order) if (pending.getOrDefault(queue, 0L) > 0)
            result.add(Map.of("queue", queue, "count", pending.get(queue), "unit", queue.startsWith("adjustments") ? "field" : "record"));
        return result;
    }

    @Transactional(readOnly = true)
    public Map<String, Object> tasks() {
        Map<String, Long> pending = new LinkedHashMap<>();
        AuthUser u = SecurityUtils.current();
        if (u.hasPermission(Permissions.DEVICE_APPROVE)) pending.put("devices", devices.countByStatus("PENDING"));
        if (u.hasAny(Roles.STORE_MANAGER)) {
            pending.put("explanations", exceptions.countByRequestStatus("PENDING"));
            pending.put("overtime", overtime.countByApprovalStatus("PENDING"));
            pending.put("adjustmentsAwaitingManager", adjustments.countByManagerStatus("PENDING"));
        }
        if (u.hasPermission(Permissions.ATTENDANCE_ADJUST_HR)) pending.put("adjustmentsAwaitingHr", adjustments.countByManagerStatusAndHrStatus("APPROVED", "PENDING"));
        if (u.hasPermission(Permissions.CHECKLIST_REVIEW)) pending.put("checklistReviews", runs.countByRunStatus("SUBMITTED"));
        if (u.hasPermission(Permissions.DOCUMENT_REVIEW)) pending.put("documents", docs.countByReviewStatus("PENDING"));
        if (u.hasPermission(Permissions.VIOLATION_REVIEW)) pending.put("violations", violations.countByRecordStatus("PENDING"));
        if (u.hasPermission(Permissions.REWARD_VIEW)) pending.put("rewardsAndPenalties", decisions.countByDecisionStatus("PENDING"));
        filterQueues(pending);
        return Map.of("pending", pending, "nextActions", actions(pending), "updatedAt", TimeUtils.vn(clock.instant()));
    }

    @Transactional(readOnly = true)
    public StatsView attendance(LocalDate from, LocalDate to, Integer shiftId) { return stats.stats(from, to, shiftId, null); }

    @Transactional(readOnly = true)
    public Map<String, Object> employeeStatus() {
        Map<String, Integer> byEmployment = new TreeMap<>(), byProfile = new TreeMap<>();
        Map<String, Integer> byTraining = new LinkedHashMap<>(Map.of("COMPLETE", 0, "MISSING", 0));
        Map<String, Integer> bySkills = new LinkedHashMap<>(Map.of("ASSESSED", 0, "NOT_ASSESSED", 0));
        Set<Long> assessed = new HashSet<>();
        skills.findAll().forEach(s -> assessed.add(s.getEmployeeId()));
        int restricted = 0;
        for (Employee e : employees.findAll()) {
            byEmployment.merge(e.getEmploymentStatus(), 1, Integer::sum);
            if (!"ACTIVE".equals(e.getEmploymentStatus())) continue;
            byProfile.merge(documents.profile(e).profileStatus(), 1, Integer::sum);
            TrainingService.Eligibility progress = training.eligibility(e);
            byTraining.merge(progress.completed() >= progress.required() ? "COMPLETE" : "MISSING", 1, Integer::sum);
            bySkills.merge(assessed.contains(e.getEmployeeId()) ? "ASSESSED" : "NOT_ASSESSED", 1, Integer::sum);
            if (!progress.eligible()) restricted++;
        }
        return Map.of("employmentStatus", byEmployment, "profileStatus", byProfile, "shiftRestricted", restricted,
                "trainingStatus", byTraining, "skillAssessmentStatus", bySkills);
    }

    @Transactional(readOnly = true)
    public Map<String, Object> operations(LocalDate from, LocalDate to) {
        Instant f = TimeUtils.startOfDay(from), t = TimeUtils.startOfDay(to.plusDays(1));
        Map<String, Integer> byStatus = new TreeMap<>();
        int total = 0;
        for (ChecklistTask r : runs.findByDueAtGreaterThanEqualAndDueAtLessThan(f, t)) { byStatus.merge(r.getRunStatus(), 1, Integer::sum); total++; }
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
