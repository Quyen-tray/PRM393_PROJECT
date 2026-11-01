package com.hrm.coffeeshop.shared.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;

public final class ChecklistDto {
    private ChecklistDto() {}

    public record ItemView(Integer itemId, String itemName, String instructions, Boolean isRequired,
                           Boolean requiresEvidence, Integer sortOrder, Boolean requiresManagerApproval) {}

    public record TemplateView(Integer templateId, String checklistCode, String checklistName, String checklistType,
                               Boolean managerApprovalRequired, Boolean isActive, List<ItemView> items,
                               Integer version) {}

    public record ItemRequest(@NotBlank @Size(max = 200) String itemName, @Size(max = 500) String instructions,
                              Boolean isRequired, Boolean requiresEvidence, Integer sortOrder,
                              Boolean requiresManagerApproval) {}

    public record TemplateRequest(@NotBlank @Size(max = 40) String checklistCode, @NotBlank @Size(max = 150) String checklistName,
                                  @NotBlank @Pattern(regexp = "OPENING|CLOSING|HANDOVER|SERVICE|INVENTORY") String checklistType,
                                  Boolean managerApprovalRequired, Boolean isActive,
                                  @NotEmpty @Valid List<ItemRequest> items) {}

    public record GenerateRequest(@NotNull Integer templateId, Long scheduleId, Long employeeId, LocalDate workDate) {}

    public record RunItemView(Long runItemId, Integer itemId, String itemName, String instructions, Boolean isRequired,
                              Boolean requiresEvidence, Boolean isCompleted, OffsetDateTime completedAt,
                              boolean hasEvidence, String note) {}

    public record RunView(Long taskId, Integer templateId, String checklistName, String checklistType, Long scheduleId,
                          Long employeeId, String employeeName, OffsetDateTime dueAt, OffsetDateTime startedAt,
                          OffsetDateTime submittedAt, String status, String managerStatus, String reviewNote,
                          List<RunItemView> items) {}

    public record AddEvidenceRequest(@NotNull Long runItemId, @NotBlank @Size(max = 500) String evidenceStorageKey) {}

    public record CompleteItemRequest(@Size(max = 500) String note, @Size(max = 500) String evidenceStorageKey) {}
}
