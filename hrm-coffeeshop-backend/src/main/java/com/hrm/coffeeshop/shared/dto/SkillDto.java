package com.hrm.coffeeshop.shared.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;

public final class SkillDto {
    private SkillDto() {}

    public record SkillView(Integer skillId, String skillCode, String skillName, String description) {}

    public record SkillRequest(@NotBlank @Size(max = 40) String skillCode, @NotBlank @Size(max = 150) String skillName,
                               @Size(max = 500) String description) {}

    /** Mức 1 (cơ bản) – 5 (thành thạo). Mỗi lần đánh giá là một dòng mới, giữ lịch sử. */
    public record AssessRequest(@NotNull Integer skillId, @NotNull @Min(1) @Max(5) Integer level, @Size(max = 500) String note) {}

    public record AssessmentView(Long assessmentId, Long employeeId, Integer skillId, String skillName, Integer level,
                                 String note, Long assessedBy, Instant assessedAt) {}
}
