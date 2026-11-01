package com.hrm.coffeeshop.shared.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;

public final class PayrollDto {
    private PayrollDto() {}

    public record PeriodRequest(@NotBlank @Size(max = 20) String periodCode, @NotNull LocalDate startDate,
                                @NotNull LocalDate endDate, @Size(max = 500) String note) {}

    public record PeriodView(Long periodId, String periodCode, LocalDate startDate, LocalDate endDate, String status,
                             OffsetDateTime managerApprovedAt, OffsetDateTime hrApprovedAt, OffsetDateTime lockedAt, String note) {}

    public record Blocker(String type, int count, List<Long> ids) {}

    public record ReadinessView(Long periodId, String status, String periodStatus, int totalEmployees,
                                int pendingAdjustments, int pendingOvertimeApprovals, int unresolvedAttendanceExceptions,
                                int missingCheckOuts, int absentShifts, boolean canFinalize, List<Blocker> blockers) {
        public Map<String, Object> asDetails() {
            return Map.of("pendingAdjustments", pendingAdjustments, "pendingOvertimeApprovals", pendingOvertimeApprovals,
                    "unresolvedAttendanceExceptions", unresolvedAttendanceExceptions, "missingCheckOuts", missingCheckOuts, "blockers", blockers);
        }
    }
}
