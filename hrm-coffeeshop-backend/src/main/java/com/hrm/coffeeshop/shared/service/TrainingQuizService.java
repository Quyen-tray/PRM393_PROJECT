package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.common.*;
import com.hrm.coffeeshop.domain.EmployeeTraining;
import com.hrm.coffeeshop.domain.TrainingAttempt;
import com.hrm.coffeeshop.domain.TrainingCourse;
import com.hrm.coffeeshop.domain.TrainingQuestion;
import com.hrm.coffeeshop.repository.EmployeeTrainingRepository;
import com.hrm.coffeeshop.repository.TrainingAttemptRepository;
import com.hrm.coffeeshop.repository.TrainingCourseRepository;
import com.hrm.coffeeshop.repository.TrainingQuestionRepository;
import com.hrm.coffeeshop.shared.dto.TrainingDto.QuizAdminQuestionView;
import com.hrm.coffeeshop.shared.dto.TrainingDto.QuizAnswerRequest;
import com.hrm.coffeeshop.shared.dto.TrainingDto.QuizAnswerResultView;
import com.hrm.coffeeshop.shared.dto.TrainingDto.QuizOptionView;
import com.hrm.coffeeshop.shared.dto.TrainingDto.QuizQuestionListRequest;
import com.hrm.coffeeshop.shared.dto.TrainingDto.QuizQuestionRequest;
import com.hrm.coffeeshop.shared.dto.TrainingDto.QuizQuestionView;
import com.hrm.coffeeshop.shared.dto.TrainingDto.QuizResultView;
import com.hrm.coffeeshop.shared.dto.TrainingDto.QuizSubmissionRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Clock;
import java.time.Instant;
import java.time.ZonedDateTime;
import java.util.*;

@Service
public class TrainingQuizService {
    private final TrainingCourseRepository courses;
    private final TrainingQuestionRepository questions;
    private final EmployeeTrainingRepository trainings;
    private final TrainingAttemptRepository attempts;
    private final AuditService audit;
    private final Clock clock;

    public TrainingQuizService(TrainingCourseRepository courses,
                               TrainingQuestionRepository questions,
                               EmployeeTrainingRepository trainings,
                               TrainingAttemptRepository attempts,
                               AuditService audit,
                               Clock clock) {
        this.courses = courses;
        this.questions = questions;
        this.trainings = trainings;
        this.attempts = attempts;
        this.audit = audit;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public List<QuizQuestionView> quiz(Integer courseId) {
        Long employeeId = SecurityUtils.requireEmployeeId();
        TrainingCourse course = activeTestCourse(courseId);
        requireEnrollment(employeeId, courseId);
        return activeQuestions(courseId).stream().map(this::employeeQuestion).toList();
    }

    @Transactional
    public QuizResultView submit(Integer courseId, QuizSubmissionRequest request) {
        Long employeeId = SecurityUtils.requireEmployeeId();
        TrainingCourse course = activeTestCourse(courseId);
        EmployeeTraining enrollment = requireEnrollment(employeeId, courseId);
        Instant now = clock.instant();
        if (isValidPass(enrollment, now)) {
            throw BusinessException.invalidState("Bạn đã đạt khóa học này và còn hiệu lực");
        }

        List<TrainingQuestion> courseQuestions = activeQuestions(courseId);
        if (courseQuestions.isEmpty()) {
            throw BusinessException.invalidState("Khóa học chưa có câu hỏi trắc nghiệm");
        }
        Map<Long, String> selected = new HashMap<>();
        for (QuizAnswerRequest answer : request.answers()) {
            String option = answer.selectedOption().trim().toUpperCase(Locale.ROOT);
            if (selected.putIfAbsent(answer.questionId(), option) != null) {
                throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Không được trả lời trùng câu hỏi");
            }
        }
        Set<Long> expectedIds = new HashSet<>();
        courseQuestions.forEach(question -> expectedIds.add(question.getQuestionId()));
        if (!selected.keySet().equals(expectedIds)) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Hãy trả lời đầy đủ các câu hỏi của bài kiểm tra");
        }

        int correctAnswers = 0;
        List<QuizAnswerResultView> answerResults = new ArrayList<>();
        for (TrainingQuestion question : courseQuestions) {
            String selectedOption = selected.get(question.getQuestionId());
            boolean correct = question.getCorrectOption().equals(selectedOption);
            if (correct) correctAnswers++;
            answerResults.add(new QuizAnswerResultView(question.getQuestionId(), question.getQuestionText(),
                    selectedOption, question.getCorrectOption(), correct));
        }
        BigDecimal score = BigDecimal.valueOf(correctAnswers)
                .multiply(BigDecimal.valueOf(100))
                .divide(BigDecimal.valueOf(courseQuestions.size()), 2, RoundingMode.HALF_UP);
        boolean passed = score.compareTo(course.getPassingScore()) >= 0;
        int attemptNo = (int) attempts.countByEmployeeIdAndCourseId(employeeId, courseId) + 1;

        TrainingAttempt attempt = new TrainingAttempt();
        attempt.setEmployeeId(employeeId);
        attempt.setCourseId(courseId);
        attempt.setAttemptNo(attemptNo);
        attempt.setScore(score);
        attempt.setIsPassed(passed);
        attempt.setSource("QUIZ");
        attempt.setRecordedBy(SecurityUtils.current().userId());
        attempt.setRecordedAt(now);
        attempts.save(attempt);

        Map<String, Object> before = new LinkedHashMap<>();
        before.put("status", enrollment.getTrainingStatus());
        before.put("score", enrollment.getTestScore());
        enrollment.setTestScore(score);
        enrollment.setTrainingStatus(passed ? "PASSED" : "FAILED");
        if (passed) {
            enrollment.setCompletedAt(now);
            enrollment.setExpiresAt(course.getValidityMonths() == null ? null
                    : ZonedDateTime.ofInstant(now, TimeUtils.ZONE).plusMonths(course.getValidityMonths()).toInstant());
        } else {
            enrollment.setCompletedAt(null);
            enrollment.setExpiresAt(null);
        }
        trainings.save(enrollment);

        Map<String, Object> after = new LinkedHashMap<>();
        after.put("source", "QUIZ");
        after.put("attemptNo", attemptNo);
        after.put("score", score);
        after.put("passed", passed);
        audit.log("TRAINING_QUIZ_SUBMIT", "TrainingAttempt", attempt.getAttemptId(), before, after);
        return new QuizResultView(courseId, course.getCourseName(), courseQuestions.size(), correctAnswers,
                score, course.getPassingScore(), passed, attemptNo, enrollment.getTrainingStatus(), answerResults);
    }

    @Transactional(readOnly = true)
    public List<QuizAdminQuestionView> adminQuestions(Integer courseId) {
        courses.findById(courseId).orElseThrow(() -> BusinessException.notFound("khóa học"));
        return questions.findByCourseIdOrderBySortOrderAscQuestionIdAsc(courseId).stream()
                .map(TrainingQuizService::adminQuestion)
                .toList();
    }

    @Transactional
    public List<QuizAdminQuestionView> replaceQuestions(Integer courseId, QuizQuestionListRequest request) {
        courses.findById(courseId).orElseThrow(() -> BusinessException.notFound("khóa học"));
        List<Integer> orders = request.questions().stream().map(QuizQuestionRequest::sortOrder).toList();
        if (new HashSet<>(orders).size() != orders.size()) {
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Thứ tự câu hỏi không được trùng");
        }
        List<QuizAdminQuestionView> before = adminQuestions(courseId);
        questions.deleteByCourseId(courseId);
        questions.flush();
        List<TrainingQuestion> replacements = new ArrayList<>();
        for (QuizQuestionRequest source : request.questions()) {
            TrainingQuestion question = new TrainingQuestion();
            question.setCourseId(courseId);
            question.setQuestionText(source.questionText().trim());
            question.setOptionA(source.optionA().trim());
            question.setOptionB(source.optionB().trim());
            question.setOptionC(source.optionC().trim());
            question.setOptionD(source.optionD().trim());
            question.setCorrectOption(source.correctOption().trim().toUpperCase(Locale.ROOT));
            question.setSortOrder(source.sortOrder());
            question.setIsActive(true);
            replacements.add(question);
        }
        questions.saveAll(replacements);
        questions.flush();
        List<QuizAdminQuestionView> after = adminQuestions(courseId);
        audit.log("TRAINING_QUIZ_QUESTIONS_UPDATE", "TrainingCourse", courseId, before,
                Map.of("questionCount", after.size()));
        return after;
    }

    private TrainingCourse activeTestCourse(Integer courseId) {
        TrainingCourse course = courses.findById(courseId)
                .filter(value -> Boolean.TRUE.equals(value.getIsActive()))
                .orElseThrow(() -> BusinessException.notFound("khóa học"));
        if (Boolean.FALSE.equals(course.getIsMandatoryTest())) {
            throw BusinessException.invalidState("Khóa học này không có bài kiểm tra");
        }
        return course;
    }

    private EmployeeTraining requireEnrollment(Long employeeId, Integer courseId) {
        return trainings.findByEmployeeIdAndCourseId(employeeId, courseId)
                .orElseThrow(() -> BusinessException.invalidState("Hãy ghi danh khóa học trước khi làm bài kiểm tra"));
    }

    private List<TrainingQuestion> activeQuestions(Integer courseId) {
        List<TrainingQuestion> result = questions.findByCourseIdAndIsActiveTrueOrderBySortOrderAscQuestionIdAsc(courseId);
        if (result.isEmpty()) throw BusinessException.invalidState("Khóa học chưa có câu hỏi trắc nghiệm");
        return result;
    }

    private static boolean isValidPass(EmployeeTraining training, Instant now) {
        return "PASSED".equals(training.getTrainingStatus())
                && (training.getExpiresAt() == null || training.getExpiresAt().isAfter(now));
    }

    private QuizQuestionView employeeQuestion(TrainingQuestion question) {
        return new QuizQuestionView(question.getQuestionId(), question.getQuestionText(), List.of(
                new QuizOptionView("A", question.getOptionA()),
                new QuizOptionView("B", question.getOptionB()),
                new QuizOptionView("C", question.getOptionC()),
                new QuizOptionView("D", question.getOptionD())));
    }

    private static QuizAdminQuestionView adminQuestion(TrainingQuestion question) {
        return new QuizAdminQuestionView(question.getQuestionId(), question.getQuestionText(),
                question.getOptionA(), question.getOptionB(), question.getOptionC(), question.getOptionD(),
                question.getCorrectOption(), question.getSortOrder());
    }
}
