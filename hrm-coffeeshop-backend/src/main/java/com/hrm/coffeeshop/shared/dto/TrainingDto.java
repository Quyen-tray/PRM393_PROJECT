package com.hrm.coffeeshop.shared.dto;

import jakarta.validation.constraints.*;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;

public final class TrainingDto {
    private TrainingDto() {}

    public record CourseView(Integer courseId, String courseCode, String courseName, String description,
                             BigDecimal passScore, Integer validityMonths, Boolean isMandatoryTest, Boolean isActive) {}

    /** Khóa học không còn cờ bắt buộc/chức vụ: cấu hình qua PUT /admin/job-positions/{id}/training-requirements. */
    public record CourseRequest(@NotBlank @Size(max = 40) String courseCode, @NotBlank @Size(max = 200) String courseName,
                                @Size(max = 1000) String description,
                                @DecimalMin("0") @DecimalMax("100") BigDecimal passScore,
                                @Min(1) @Max(120) Integer validityMonths, Boolean isMandatoryTest, Boolean isActive) {}

    public record MyTrainingView(Integer courseId, String courseName, Boolean isMandatory, String status,
                                 BigDecimal testScore, OffsetDateTime dueAt, OffsetDateTime completedAt,
                                 OffsetDateTime expiresAt) {}

    /**
     * Khóa bắt buộc của chức vụ, kể cả khóa chưa ghi danh.
     * status: NOT_ENROLLED hoặc trạng thái đào tạo (NOT_STARTED, IN_PROGRESS, PASSED, FAILED, EXPIRED).
     * satisfied: đã đạt và còn hiệu lực. blocksShiftAssignment: khóa này chặn nhận ca.
     */
    public record RequirementView(Integer courseId, String courseName, boolean blocksShiftAssignment,
                                  String status, boolean satisfied) {}

    public record EnrollRequest(Long employeeId, OffsetDateTime dueAt) {}

    /** score bắt buộc khi khóa có IsMandatoryTest = true (kiểm tra ở service). */
    public record AttemptRequest(@NotNull Long employeeId, @DecimalMin("0") @DecimalMax("100") BigDecimal score) {}

    public record ProgressView(Long employeeId, int requiredCourses, int completedCourses, int missingCourses,
                               String shiftEligibility, List<Map<String, Object>> restrictions) {}
}
