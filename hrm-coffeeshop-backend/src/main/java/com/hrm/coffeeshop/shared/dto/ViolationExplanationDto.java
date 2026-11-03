package com.hrm.coffeeshop.shared.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.OffsetDateTime;

public final class ViolationExplanationDto {
    private ViolationExplanationDto() {}

    public record ExplanationRequest(
            @NotBlank @Size(max = 2000) String explanation,
            @Size(max = 900) String evidenceStorageKey) {}

    public record ExplanationView(
            Long explanationId,
            Long violationId,
            String explanation,
            OffsetDateTime submittedAt,
            String evidenceViewUrl) {}
}
