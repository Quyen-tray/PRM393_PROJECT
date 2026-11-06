package com.hrm.coffeeshop.job;

import com.hrm.coffeeshop.shared.service.NotificationService;
import com.hrm.coffeeshop.shared.service.PersonLookup;
import com.hrm.coffeeshop.shared.service.StoreService;
import com.hrm.coffeeshop.shared.service.ViolationService;

import com.hrm.coffeeshop.common.TimeUtils;
import com.hrm.coffeeshop.domain.ChecklistTask;
import com.hrm.coffeeshop.domain.Notification;
import com.hrm.coffeeshop.domain.ShiftAssignment;
import com.hrm.coffeeshop.repository.AttendanceRepository;
import com.hrm.coffeeshop.repository.ReminderRuleRepository;
import com.hrm.coffeeshop.repository.ChecklistTaskRepository;
import com.hrm.coffeeshop.repository.ChecklistReviewRepository;
import com.hrm.coffeeshop.repository.NotificationRepository;
import com.hrm.coffeeshop.repository.ShiftAssignmentRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;

/**
 * Nhắc ca / checklist (BR-REM-01..03). Idempotent nhờ DedupKey: chạy lại không gửi trùng.
 * Đơn node. Nếu chạy nhiều instance cần khóa phân tán (ShedLock) để tránh xử lý song song.
 */
@Component
public class ReminderJob {
    private static final Logger log = LoggerFactory.getLogger(ReminderJob.class);
    private static final List<String> OPEN = List.of("PENDING", "IN_PROGRESS", "OVERDUE", "REJECTED");

    private final ShiftAssignmentRepository schedules;
    private final AttendanceRepository attendance;
    private final ChecklistTaskRepository runs;
    private final NotificationService notifications;
    private final ViolationService violations;
    private final ReminderRuleRepository rules;
    private final PersonLookup people;
    private final TransactionTemplate tx;
    private final Clock clock;
    private final ChecklistReviewRepository reviews;
    private final NotificationRepository notificationRecords;

    public ReminderJob(ShiftAssignmentRepository schedules, AttendanceRepository attendance, ChecklistTaskRepository runs,
                       NotificationService notifications, ViolationService violations, ReminderRuleRepository rules,
                       PersonLookup people, TransactionTemplate tx, Clock clock, ChecklistReviewRepository reviews,
                       NotificationRepository notificationRecords) {
        this.schedules = schedules;
        this.attendance = attendance;
        this.runs = runs;
        this.notifications = notifications;
        this.violations = violations;
        this.rules = rules;
        this.people = people;
        this.tx = tx;
        this.clock = clock;
        this.reviews = reviews;
        this.notificationRecords = notificationRecords;
    }

    @Scheduled(fixedDelay = 60_000, initialDelay = 30_000)
    public void run() {
        try { shiftReminders(); } catch (Exception e) { log.error("shiftReminders failed", e); }
        try { checklistReminders(); } catch (Exception e) { log.error("checklistReminders failed", e); }
    }

    /** Cấu hình nhắc đọc từ ReminderRule (SRS 7.4); thiếu bản ghi thì dùng mặc định. */
    private int leadOf(String code, int fallback) {
        return rules.findByRuleCode(code).map(r -> r.getLeadMinutes() == null ? fallback : r.getLeadMinutes()).orElse(fallback);
    }

    private int intervalOf(String code, int fallback) {
        return rules.findByRuleCode(code).map(r -> r.getIntervalMinutes() == null ? fallback : r.getIntervalMinutes()).orElse(fallback);
    }

    private int maxOf(String code, int fallback) {
        return rules.findByRuleCode(code).map(r -> r.getMaxAttempts() == null ? fallback : r.getMaxAttempts()).orElse(fallback);
    }

    private boolean enabled(String code) { return rules.findByRuleCode(code).map(r -> !Boolean.FALSE.equals(r.getIsActive())).orElse(true); }

    void shiftReminders() {
        if(!enabled("SHIFT_REMINDER")) return;
        Instant now = clock.instant();
        int lead = leadOf("SHIFT_REMINDER", 15);
        for (ShiftAssignment s : schedules.findStartingBetween(now, now.plus(Duration.ofMinutes(lead)))) {
            try {
                tx.executeWithoutResult(st -> {
                    boolean checkedIn = attendance.findByShiftAssignmentId(s.getShiftAssignmentId()).map(a -> a.getCheckInAt() != null).orElse(false);
                    if (checkedIn) return;
                    notifications.notify(people.userIdOf(s.getEmployeeId()), "SHIFT_REMINDER", "Sắp đến giờ vào ca",
                            "Ca làm của bạn bắt đầu lúc " + TimeUtils.vn(s.getPlannedStartAt()).toLocalTime(),
                            "ShiftAssignment", s.getShiftAssignmentId(), "SHIFT_REMINDER:" + s.getShiftAssignmentId());
                });
            } catch (Exception e) { log.warn("shift reminder skipped for {}: {}", s.getShiftAssignmentId(), e.getMessage()); }
        }
    }

    void checklistReminders() {
        Instant now = clock.instant();
        int soon = leadOf("CHECKLIST_DUE_SOON", 15);
        int interval = Math.max(1, intervalOf("CHECKLIST_OVERDUE", 5));
        int max = Math.max(1, maxOf("CHECKLIST_OVERDUE", 3));

        if(enabled("CHECKLIST_DUE_SOON")) for (ChecklistTask r : runs.findDueBetween(now, now.plus(Duration.ofMinutes(soon)), List.of("PENDING", "IN_PROGRESS", "REJECTED"))) {
            try {
                tx.executeWithoutResult(st -> notifications.notify(people.userIdOf(r.getEmployeeId()), "CHECKLIST_DUE_SOON",
                        "Checklist sắp đến hạn", "Checklist #" + r.getChecklistTaskId() + " sắp đến hạn.", "ChecklistTask",
                        r.getChecklistTaskId(), "CHECKLIST_DUE_SOON:" + r.getChecklistTaskId() + reviewCycle(r)));
            } catch (Exception e) { log.warn("due-soon skipped for {}: {}", r.getChecklistTaskId(), e.getMessage()); }
        }

        for (ChecklistTask r : runs.findOverdue(now, now.minus(Duration.ofHours(48)), OPEN)) {
            try {
                tx.executeWithoutResult(st -> {
                    ChecklistTask run = runs.findById(r.getChecklistTaskId()).orElseThrow();
                    if (!"OVERDUE".equals(run.getRunStatus())) run.setRunStatus("OVERDUE");
                    if (!enabled("CHECKLIST_OVERDUE")) return;

                    String cycle = reviewCycle(run);
                    int nextAttempt = 1;
                    Notification lastReminder = null;
                    while (nextAttempt <= max) {
                        String key = overdueReminderKey(run, cycle, nextAttempt);
                        var sent = notificationRecords.findByDedupKey(key);
                        if (sent.isEmpty()) break;
                        lastReminder = sent.get();
                        nextAttempt++;
                    }

                    if (nextAttempt > max) {
                        violations.recordChecklistMissed(run.getEmployeeId(), run.getChecklistTaskId());
                        return;
                    }
                    Instant nextReminderAt = nextAttempt == 1
                            ? run.getDueAt().plus(Duration.ofMinutes(interval))
                            : lastReminder.getCreatedAt().plus(Duration.ofMinutes(interval));
                    if (now.isBefore(nextReminderAt)) return;

                    notifications.notify(people.userIdOf(run.getEmployeeId()), "CHECKLIST_OVERDUE", "Checklist đã quá hạn",
                            "Nhắc lần " + nextAttempt + "/" + max + " cho checklist #" + run.getChecklistTaskId(), "ChecklistTask",
                            run.getChecklistTaskId(), overdueReminderKey(run, cycle, nextAttempt));
                    // Chỉ ghi nhận vi phạm sau khi lời nhắc cuối cùng đã được gửi.
                    if (nextAttempt == max)
                        violations.recordChecklistMissed(run.getEmployeeId(), run.getChecklistTaskId());
                });
            } catch (Exception e) { log.warn("overdue handling skipped for {}: {}", r.getChecklistTaskId(), e.getMessage()); }
        }
    }

    private String overdueReminderKey(ChecklistTask run, String cycle, int attempt) {
        return "CHECKLIST_OVERDUE:" + run.getChecklistTaskId() + cycle + ":" + attempt;
    }

    private String reviewCycle(ChecklistTask run) {
        return reviews.findFirstByChecklistTaskIdOrderByReviewedAtDesc(run.getChecklistTaskId())
                .filter(r -> "REJECTED".equals(r.getDecision()))
                .map(r -> ":review:" + r.getChecklistReviewId()).orElse("");
    }
}
