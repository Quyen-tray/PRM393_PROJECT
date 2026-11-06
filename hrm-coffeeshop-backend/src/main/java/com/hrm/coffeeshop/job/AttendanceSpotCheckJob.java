package com.hrm.coffeeshop.job;

import com.hrm.coffeeshop.common.TimeUtils;
import com.hrm.coffeeshop.domain.Attendance;
import com.hrm.coffeeshop.domain.AttendanceSpotCheck;
import com.hrm.coffeeshop.repository.AttendanceRepository;
import com.hrm.coffeeshop.repository.AttendanceSpotCheckRepository;
import com.hrm.coffeeshop.shared.service.NotificationService;
import com.hrm.coffeeshop.shared.service.PersonLookup;
import com.hrm.coffeeshop.shared.service.ViolationService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.format.DateTimeFormatter;

/** Activates sampled mid-shift checks and records requests that expire without a response. */
@Component
public class AttendanceSpotCheckJob {
    private static final Logger log = LoggerFactory.getLogger(AttendanceSpotCheckJob.class);
    private static final DateTimeFormatter DEADLINE = DateTimeFormatter.ofPattern("dd/MM HH:mm");

    private final AttendanceSpotCheckRepository checks;
    private final AttendanceRepository attendances;
    private final NotificationService notifications;
    private final PersonLookup people;
    private final ViolationService violations;
    private final TransactionTemplate tx;
    private final Clock clock;
    private final int responseMinutes;

    public AttendanceSpotCheckJob(AttendanceSpotCheckRepository checks, AttendanceRepository attendances,
                                  NotificationService notifications, PersonLookup people,
                                  ViolationService violations, TransactionTemplate tx, Clock clock,
                                  @Value("${app.attendance.spot-check-response-minutes:5}") int responseMinutes) {
        this.checks = checks;
        this.attendances = attendances;
        this.notifications = notifications;
        this.people = people;
        this.violations = violations;
        this.tx = tx;
        this.clock = clock;
        this.responseMinutes = responseMinutes;
    }

    @Scheduled(fixedDelay = 10_000, initialDelay = 25_000)
    public void run() {
        try { activateDueChecks(); }
        catch (Exception e) { log.error("Activating attendance spot checks failed", e); }
        try { recordExpiredChecks(); }
        catch (Exception e) { log.error("Recording expired attendance spot checks failed", e); }
    }

    private void activateDueChecks() {
        Instant now = clock.instant();
        for (AttendanceSpotCheck candidate : checks.findDueScheduled(now)) {
            try {
                tx.executeWithoutResult(status -> {
                    Attendance record = attendances.findByIdForUpdate(candidate.getAttendanceId()).orElse(null);
                    AttendanceSpotCheck check = checks.findByIdForUpdate(candidate.getSpotCheckId()).orElse(null);
                    Instant activatedAt = clock.instant();
                    if (check == null || !"SCHEDULED".equals(check.getStatus())
                            || check.getScheduledAt() == null || check.getScheduledAt().isAfter(activatedAt)) return;
                    if (record == null || record.getCheckInAt() == null || record.getCheckOutAt() != null) {
                        check.setStatus("CANCELLED");
                        return;
                    }
                    Instant deadline = activatedAt.plus(Duration.ofMinutes(responseMinutes));
                    check.setStatus("REQUESTED");
                    check.setRequestedAt(activatedAt);
                    check.setResponseDeadlineAt(deadline);
                    String localDeadline = TimeUtils.vn(deadline).format(DEADLINE);
                    notifications.notify(people.userIdOf(check.getEmployeeId()), "ATTENDANCE_SPOT_CHECK",
                            "Yêu cầu kiểm tra giữa ca",
                            "Hãy chụp ảnh và lấy vị trí GPS để xác nhận bạn đang làm việc trước " + localDeadline + ".",
                            "ShiftAssignment", check.getShiftAssignmentId(),
                            "ATTENDANCE_SPOT_CHECK:" + check.getSpotCheckId());
                });
            } catch (Exception e) {
                log.warn("Spot-check activation skipped for {}: {}", candidate.getSpotCheckId(), e.getMessage());
            }
        }
    }

    private void recordExpiredChecks() {
        Instant now = clock.instant();
        for (AttendanceSpotCheck candidate : checks.findExpiredRequests(now)) {
            try {
                tx.executeWithoutResult(status -> {
                    attendances.findByIdForUpdate(candidate.getAttendanceId());
                    AttendanceSpotCheck check = checks.findByIdForUpdate(candidate.getSpotCheckId()).orElse(null);
                    Instant expiredAt = clock.instant();
                    if (check == null || !"REQUESTED".equals(check.getStatus())
                            || check.getResponseDeadlineAt() == null
                            || check.getResponseDeadlineAt().isAfter(expiredAt)) return;
                    check.setStatus("MISSED");
                    violations.recordAttendanceSpotCheckMissed(check.getEmployeeId(), check.getAttendanceId());
                });
            } catch (Exception e) {
                log.warn("Spot-check expiry skipped for {}: {}", candidate.getSpotCheckId(), e.getMessage());
            }
        }
    }
}
