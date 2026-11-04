package com.hrm.coffeeshop.shared.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;

public final class TrainingDto {
    private TrainingDto() {}
    public record CourseView(Integer courseId, String courseCode, String courseName, String description,
                             BigDecimal passScore, Integer validityMonths, Boolean isMandatoryTest, Boolean isActive) {}
    public record CourseRequest(@NotBlank @Size(max=40) String courseCode, @NotBlank @Size(max=200) String courseName,
                                @Size(max=1000) String description, @DecimalMin("0") @DecimalMax("100") BigDecimal passScore,
                                @Min(1) @Max(120) Integer validityMonths, Boolean isMandatoryTest, Boolean isActive) {}
    public record MyTrainingView(Long employeeTrainingId, Integer courseId, String courseName, Boolean isMandatory,
                                 String status, BigDecimal testScore, OffsetDateTime dueAt, OffsetDateTime completedAt,
                                 OffsetDateTime expiresAt, OffsetDateTime completionReviewedAt, String completionReviewNote) {}
    public record RequirementView(Integer courseId, String courseName, boolean blocksShiftAssignment,
                                  String status, boolean satisfied) {}
    public record EnrollRequest(Long employeeId, OffsetDateTime dueAt) {}
    public record AttemptRequest(@NotNull Long employeeId, @DecimalMin("0") @DecimalMax("100") BigDecimal score,
                                 @Size(max=500) String note) {
        public AttemptRequest(Long employeeId, BigDecimal score) { this(employeeId, score, null); }
    }
    public record ProgressView(Long employeeId, int requiredCourses, int completedCourses, int missingCourses,
                               String shiftEligibility, List<Map<String,Object>> restrictions) {}
    public record CompletionReviewView(Long employeeTrainingId, Long employeeId, String employeeCode,
                                       String employeeName, Integer courseId, String courseName,
                                       OffsetDateTime enrolledAt, String status, String reviewNote) {}
    public record QuizOptionView(String key, String text) {}
    public record QuizQuestionView(Long questionId, String questionText, List<QuizOptionView> options) {}
    public record QuizAdminQuestionView(Long questionId, String questionText, String optionA, String optionB,
                                        String optionC, String optionD, String correctOption, Integer sortOrder) {}
    public record QuizQuestionRequest(@NotBlank @Size(max=1000) String questionText,
                                      @NotBlank @Size(max=300) String optionA, @NotBlank @Size(max=300) String optionB,
                                      @NotBlank @Size(max=300) String optionC, @NotBlank @Size(max=300) String optionD,
                                      @NotBlank @Pattern(regexp="A|B|C|D") String correctOption,
                                      @NotNull @Min(1) Integer sortOrder) {}
    public record QuizQuestionListRequest(@NotEmpty @Valid List<QuizQuestionRequest> questions) {}
    public record QuizAnswerRequest(@NotNull Long questionId, @NotBlank @Pattern(regexp="A|B|C|D") String selectedOption) {}
    public record QuizSubmissionRequest(@NotEmpty @Valid List<QuizAnswerRequest> answers) {}
    public record QuizAnswerResultView(Long questionId, String questionText, String selectedOption,
                                       String correctOption, boolean correct) {}
    public record QuizResultView(Long attemptId, Integer courseId, String courseName, int totalQuestions,
                                 int correctAnswers, BigDecimal score, BigDecimal passScore, boolean passed,
                                 int attemptNo, String trainingStatus, List<QuizAnswerResultView> answers) {}
    public record AttemptView(Long attemptId, Integer courseId, int attemptNo, BigDecimal score, boolean passed,
                              String source, OffsetDateTime recordedAt, String answerSnapshot) {}
}
