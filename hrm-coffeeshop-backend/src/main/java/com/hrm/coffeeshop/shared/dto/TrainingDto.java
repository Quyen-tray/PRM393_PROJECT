package com.hrm.coffeeshop.shared.dto;

import jakarta.validation.constraints.*;
import jakarta.validation.Valid;
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
                                 OffsetDateTime expiresAt, OffsetDateTime completionSubmittedAt,
                                 String completionRequestNote, OffsetDateTime completionReviewedAt,
                                 String completionReviewNote) {}

    /**
     * Khóa được theo dõi theo chức vụ, kể cả khóa chưa ghi danh.
     * status: NOT_ENROLLED hoặc trạng thái đào tạo (NOT_STARTED, IN_PROGRESS, PASSED, FAILED, EXPIRED).
     * satisfied: đã đạt và còn hiệu lực. blocksShiftAssignment được giữ tương thích, hiện luôn false.
     */
    public record RequirementView(Integer courseId, String courseName, boolean blocksShiftAssignment,
                                  String status, boolean satisfied) {}

    public record EnrollRequest(Long employeeId, OffsetDateTime dueAt) {}

    public record CompletionReviewView(Long employeeTrainingId, Long employeeId, String employeeCode,
                                       String employeeName, Integer courseId, String courseName,
                                       OffsetDateTime enrolledAt, String reviewNote) {}

    /** score bắt buộc khi khóa có IsMandatoryTest = true (kiểm tra ở service). */
    public record AttemptRequest(@NotNull Long employeeId, @DecimalMin("0") @DecimalMax("100") BigDecimal score) {}

    public record QuizOptionView(String key, String text) {}

    public record QuizQuestionView(Long questionId, String questionText, List<QuizOptionView> options) {}

    public record QuizAdminQuestionView(Long questionId, String questionText, String optionA,
                                        String optionB, String optionC, String optionD,
                                        String correctOption, Integer sortOrder) {}

    public record QuizQuestionRequest(
            @NotBlank @Size(max = 1000) String questionText,
            @NotBlank @Size(max = 300) String optionA,
            @NotBlank @Size(max = 300) String optionB,
            @NotBlank @Size(max = 300) String optionC,
            @NotBlank @Size(max = 300) String optionD,
            @NotBlank @Pattern(regexp = "A|B|C|D") String correctOption,
            @NotNull @Min(1) Integer sortOrder) {}

    public record QuizQuestionListRequest(@NotEmpty @Valid List<QuizQuestionRequest> questions) {}

    public record QuizAnswerRequest(
            @NotNull Long questionId,
            @NotBlank @Pattern(regexp = "A|B|C|D") String selectedOption) {}

    public record QuizSubmissionRequest(@NotEmpty @Valid List<QuizAnswerRequest> answers) {}

    public record QuizAnswerResultView(Long questionId, String questionText, String selectedOption,
                                       String correctOption, boolean correct) {}

    public record QuizResultView(Integer courseId, String courseName, int totalQuestions,
                                 int correctAnswers, BigDecimal score, BigDecimal passScore,
                                 boolean passed, int attemptNo, String trainingStatus,
                                 List<QuizAnswerResultView> answers) {}

    public record ProgressView(Long employeeId, int requiredCourses, int completedCourses, int missingCourses,
                               String shiftEligibility, List<Map<String, Object>> restrictions) {}
}
