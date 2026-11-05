package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.common.TimeUtils;
import com.hrm.coffeeshop.domain.Attendance;
import com.hrm.coffeeshop.domain.ShiftAssignment;
import com.hrm.coffeeshop.domain.OvertimeRequest;
import com.hrm.coffeeshop.domain.WorkShift;
import com.hrm.coffeeshop.repository.AttendanceRepository;
import com.hrm.coffeeshop.repository.OvertimeRequestRepository;
import org.springframework.stereotype.Component;

import java.time.Instant;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.temporal.ChronoUnit;
import java.util.List;

/**
 * Nơi DUY NHẤT tính phút muộn / ân hạn / công / về sớm / OT được duyệt.
 * Phân biệt: hiện diện (presence) ≠ công tính (worked) ≠ OT thô ≠ OT được duyệt (BR-OT-01).
 */
@Component
public class AttendanceMetricsService {
    public record Late(int minutes, boolean graceApplied) {}

    private static final List<String> RECOMPUTABLE = List.of("IN_PROGRESS", "PRESENT", "LATE", "EARLY_LEAVE");

    private final AttendanceRepository attendance;
    private final OvertimeRequestRepository overtime;
    private final StoreService store;

    public AttendanceMetricsService(AttendanceRepository attendance, OvertimeRequestRepository overtime,
                                    StoreService store) {
        this.attendance = attendance;
        this.overtime = overtime;
        this.store = store;
    }

    /**
     * BR-TIME-02/03/04: trong ân hạn và còn lượt (≤ hạn mức/tháng) → không tính muộn, dùng 1 lượt.
     * Quá ân hạn → muộn tính từ phút đầu tiên sau khi hết ân hạn. Hết lượt → muộn tính từ giờ vào ca.
     * (Cách hiểu này cần chốt ở D-06.) Tháng xác định theo ngày của ca, reset đầu tháng.
     */
    public Late computeLate(Long employeeId, Instant checkIn, Instant plannedStart, int graceMinutes, Long excludeAttendanceId) {
        if (!checkIn.isAfter(plannedStart)) return new Late(0, false);
        YearMonth ym = YearMonth.from(TimeUtils.dateOf(plannedStart));
        Instant from = TimeUtils.startOfDay(ym.atDay(1));
        Instant to = TimeUtils.startOfDay(ym.plusMonths(1).atDay(1));
        long used = attendance.countGraceUsed(employeeId, from, to, excludeAttendanceId == null ? -1L : excludeAttendanceId);
        boolean available = used < store.current().getMonthlyGraceLimit();
        Instant graceEnd = plannedStart.plus(graceMinutes, ChronoUnit.MINUTES);
        if (available && !checkIn.isAfter(graceEnd)) return new Late(0, true);
        Instant base = available ? graceEnd : plannedStart;
        return new Late(TimeUtils.ceilMinutes(base, checkIn), false);
    }

    public int approvedOvertime(Long scheduleId, Instant plannedEnd, Instant checkOut) {
        if (checkOut == null || !checkOut.isAfter(plannedEnd)) return 0;
        long total = 0;
        for (OvertimeRequest r : overtime.findByShiftAssignmentIdAndApprovalStatus(scheduleId, "APPROVED")) {
            Instant s = r.getRequestedStartAt().isAfter(plannedEnd) ? r.getRequestedStartAt() : plannedEnd;
            Instant e = r.getRequestedEndAt().isBefore(checkOut) ? r.getRequestedEndAt() : checkOut;
            if (e.isAfter(s)) total += TimeUtils.minutes(s, e);
        }
        return (int) total;
    }

    /** Tính lại toàn bộ chỉ số của bản ghi công từ dữ liệu gốc. Gọi sau check-in/out, ngoại lệ, điều chỉnh, duyệt OT. */
    public void apply(Attendance a, ShiftAssignment s, WorkShift sh) {
        if (a.getCheckInAt() != null) {
            Late l = computeLate(a.getEmployeeId(), a.getCheckInAt(), s.getPlannedStartAt(), sh.getGraceMinutes(), a.getAttendanceId());
            a.setLateMinutes(l.minutes());
            a.setGraceApplied(l.graceApplied());
        }
        Instant out = a.getCheckOutAt();
        if (out == null) return;
        a.setEarlyLeaveMinutes(TimeUtils.ceilMinutes(out, s.getPlannedEndAt()));
        if (a.getCheckInAt() != null) {
            Instant in = a.getCheckInAt();
            Instant es = in.isAfter(s.getPlannedStartAt()) ? in : s.getPlannedStartAt();
            Instant ee = out.isBefore(s.getPlannedEndAt()) ? out : s.getPlannedEndAt();
            long inShift = ee.isAfter(es) ? TimeUtils.minutes(es, ee) : 0;
            a.setWorkedMinutes((int) Math.max(0, inShift - sh.getBreakMinutes()));
        }
        a.setApprovedOTMinutes(approvedOvertime(s.getShiftAssignmentId(), s.getPlannedEndAt(), out));
        if (RECOMPUTABLE.contains(a.getAttendanceStatus())) {
            if (a.getLateMinutes() > 0) a.setAttendanceStatus("LATE");
            else if (a.getEarlyLeaveMinutes() > 0) a.setAttendanceStatus("EARLY_LEAVE");
            else a.setAttendanceStatus("PRESENT");
        }
    }

    public long rawOvertimeMinutes(Attendance a, ShiftAssignment s) {
        return a.getCheckOutAt() != null && a.getCheckOutAt().isAfter(s.getPlannedEndAt())
                ? TimeUtils.minutes(s.getPlannedEndAt(), a.getCheckOutAt()) : 0;
    }

    public static LocalDate monthStart(LocalDate d) { return d.withDayOfMonth(1); }
}
