package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.shared.dto.AttendanceDto.StatsView;

import com.hrm.coffeeshop.domain.Attendance;
import com.hrm.coffeeshop.domain.ShiftAssignment;
import com.hrm.coffeeshop.repository.AttendanceRepository;
import com.hrm.coffeeshop.repository.ShiftAssignmentRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
public class AttendanceStatsService {
    private final ShiftAssignmentRepository schedules;
    private final AttendanceRepository attendance;
    private final Clock clock;

    public AttendanceStatsService(ShiftAssignmentRepository schedules, AttendanceRepository attendance, Clock clock) {
        this.schedules = schedules;
        this.attendance = attendance;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public StatsView stats(LocalDate from, LocalDate to, Integer shiftTemplateId, Long employeeId) {
        List<ShiftAssignment> scs = schedules.findForStats(from, to, shiftTemplateId == null ? 0 : shiftTemplateId,
                employeeId == null ? 0L : employeeId);
        Map<Long, Attendance> recs = new HashMap<>();
        if (!scs.isEmpty())
            attendance.findByShiftAssignmentIdIn(scs.stream().map(ShiftAssignment::getShiftAssignmentId).toList())
                    .forEach(r -> recs.put(r.getShiftAssignmentId(), r));
        Instant now = clock.instant();
        long onTime = 0, late = 0, absent = 0, missingOut = 0, verification = 0, lateMin = 0;
        for (ShiftAssignment s : scs) {
            Attendance r = recs.get(s.getShiftAssignmentId());
            if (r == null || r.getCheckInAt() == null) {
                if (s.getPlannedEndAt().isBefore(now)) absent++;
                continue;
            }
            if (r.getLateMinutes() > 0) { late++; lateMin += r.getLateMinutes(); } else onTime++;
            if (r.getCheckOutAt() == null && s.getPlannedEndAt().isBefore(now)) missingOut++;
            if ("REVIEW".equals(r.getCheckInFaceStatus()) || "REVIEW".equals(r.getCheckOutFaceStatus())
                    || "EXPLANATION_PENDING".equals(r.getAttendanceStatus())) verification++;
        }
        return new StatsView(from, to, scs.size(), onTime, late, absent, missingOut, verification, lateMin);
    }
}
