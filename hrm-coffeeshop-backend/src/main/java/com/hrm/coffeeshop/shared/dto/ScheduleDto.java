package com.hrm.coffeeshop.shared.dto;

import jakarta.validation.constraints.*;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;

public final class ScheduleDto {
    private ScheduleDto() {}

    public record ShiftView(Integer shiftId, String shiftCode, String shiftName, LocalTime startTime, LocalTime endTime,
                            Integer breakMinutes, Integer earlyCheckInMinutes, Integer graceMinutes, Boolean isActive) {}

    public record ShiftRequest(@NotBlank @Size(max = 30) String shiftCode, @NotBlank @Size(max = 100) String shiftName,
                               @NotNull LocalTime startTime, @NotNull LocalTime endTime,
                               @Min(0) @Max(240) Integer breakMinutes, Integer earlyCheckInMinutes,
                               Integer graceMinutes, Boolean isActive) {}

    public record AssignmentRequest(@NotNull Long employeeId, @NotNull Integer workShiftId, @NotNull LocalDate workDate,
                                    @Size(max = 500) String note) {}

    public record AssignmentPatch(Integer workShiftId, LocalDate workDate, @Size(max = 500) String note) {}

    public record AssignmentView(Long assignmentId, Long employeeId, String employeeName, ShiftView workShift,
                                 LocalDate workDate, OffsetDateTime plannedStartAt, OffsetDateTime plannedEndAt,
                                 String status, String note, Long attendanceId) {}

    public record EligibilityView(boolean eligible, List<Map<String, Object>> restrictions) {}
}
