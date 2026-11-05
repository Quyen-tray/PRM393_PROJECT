package com.hrm.coffeeshop.manager.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;

public final class ManagerChecklistDto {
    private ManagerChecklistDto() {}

    public record ReassignRequest(@NotNull Long employeeId) {}
}
