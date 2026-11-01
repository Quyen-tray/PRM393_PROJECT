package com.hrm.coffeeshop.shared.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;

public final class DocumentDto {
    private DocumentDto() {}

    /** Loại hồ sơ (danh mục). Yêu cầu bắt buộc theo chức vụ nằm ở JobPositionDto (SRS 7.4). */
    public record TypeView(Integer documentTypeId, String documentCode, String documentName, Boolean isActive) {}

    public record TypeRequest(@NotBlank @Size(max = 40) String documentCode, @NotBlank @Size(max = 150) String documentName,
                              Boolean isActive) {}

    public record SubmitRequest(@NotNull Integer documentTypeId, @NotBlank @Size(max = 900) String storageKey,
                                LocalDate issuedAt, LocalDate expiresAt) {}

    public record DocumentView(Long documentId, Long employeeId, TypeView documentType, String fileName,
                               String reviewStatus, LocalDate expiresAt, OffsetDateTime uploadedAt,
                               OffsetDateTime reviewedAt, String rejectionReason, String viewUrl, String employeeName) {}

    public record RequirementStatus(TypeView documentType, String status) {}

    public record ProfileStatusView(String profileStatus, List<RequirementStatus> requirements) {}
}
