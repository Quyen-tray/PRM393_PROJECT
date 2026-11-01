package com.hrm.coffeeshop.shared.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.time.LocalDate;
import java.util.List;

/** Chức vụ và các yêu cầu theo chức vụ (SRS 7.3, 7.4, 9.3, 9.4, 9.7). */
public final class JobPositionDto {
    private JobPositionDto() {}

    public record PositionView(Integer positionId, String positionCode, String positionName, String description,
                               Boolean isActive) {}

    public record PositionRequest(@NotBlank @Size(max = 40) String positionCode,
                                  @NotBlank @Size(max = 100) String positionName,
                                  @Size(max = 500) String description, Boolean isActive) {}

    public record DocRequirementItem(@NotNull Integer documentTypeId, Boolean isMandatory,
                                     @NotNull LocalDate effectiveFrom, LocalDate effectiveTo) {}

    public record DocRequirementsRequest(@NotNull @Valid List<DocRequirementItem> requirements) {}

    public record DocRequirementView(Integer requirementId, DocumentDto.TypeView documentType, Boolean isMandatory,
                                     LocalDate effectiveFrom, LocalDate effectiveTo) {}

    public record TrainingRequirementItem(@NotNull Integer courseId, Boolean isMandatory, Boolean blocksShiftAssignment,
                                          @NotNull LocalDate effectiveFrom, LocalDate effectiveTo) {}

    public record TrainingRequirementsRequest(@NotNull @Valid List<TrainingRequirementItem> requirements) {}

    public record TrainingRequirementView(Integer requirementId, Integer courseId, String courseName,
                                          Boolean isMandatory, Boolean blocksShiftAssignment,
                                          LocalDate effectiveFrom, LocalDate effectiveTo) {}
}
