package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.common.AuthUser;
import com.hrm.coffeeshop.common.BusinessException;
import com.hrm.coffeeshop.common.ErrorCode;
import com.hrm.coffeeshop.domain.EmployeeTraining;
import com.hrm.coffeeshop.domain.TrainingAttempt;
import com.hrm.coffeeshop.domain.TrainingCourse;
import com.hrm.coffeeshop.domain.TrainingQuestion;
import com.hrm.coffeeshop.repository.EmployeeTrainingRepository;
import com.hrm.coffeeshop.repository.TrainingAttemptRepository;
import com.hrm.coffeeshop.repository.TrainingCourseRepository;
import com.hrm.coffeeshop.repository.TrainingQuestionRepository;
import com.hrm.coffeeshop.shared.dto.TrainingDto.QuizAnswerRequest;
import com.hrm.coffeeshop.shared.dto.TrainingDto.QuizQuestionView;
import com.hrm.coffeeshop.shared.dto.TrainingDto.QuizSubmissionRequest;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class TrainingQuizServiceTest {
    private static final long EMPLOYEE_ID = 42L;
    private static final int COURSE_ID = 1;
    private static final long QUESTION_ID = 501L;
    private static final Instant NOW = Instant.parse("2031-03-01T12:00:00Z");

    @Mock TrainingCourseRepository courses;
    @Mock TrainingQuestionRepository questions;
    @Mock EmployeeTrainingRepository trainings;
    @Mock TrainingAttemptRepository attempts;
    @Mock AuditService audit;

    private TrainingQuizService service;
    private EmployeeTraining enrollment;
    private TrainingQuestion question;

    @BeforeEach
    void setUp() {
        service = new TrainingQuizService(courses, questions, trainings, attempts, audit,
                Clock.fixed(NOW, ZoneOffset.UTC));

        TrainingCourse course = new TrainingCourse();
        course.setCourseId(COURSE_ID);
        course.setCourseName("Food safety");
        course.setIsActive(true);
        course.setIsMandatoryTest(true);
        course.setPassingScore(new BigDecimal("70"));
        course.setValidityMonths(12);
        when(courses.findById(COURSE_ID)).thenReturn(Optional.of(course));

        enrollment = new EmployeeTraining();
        enrollment.setEmployeeId(EMPLOYEE_ID);
        enrollment.setCourseId(COURSE_ID);
        enrollment.setTrainingStatus("IN_PROGRESS");
        when(trainings.findByEmployeeIdAndCourseId(EMPLOYEE_ID, COURSE_ID))
                .thenReturn(Optional.of(enrollment));

        question = new TrainingQuestion();
        question.setQuestionId(QUESTION_ID);
        question.setCourseId(COURSE_ID);
        question.setQuestionText("What should the employee check first?");
        question.setOptionA("The shift handover");
        question.setOptionB("The menu prices");
        question.setOptionC("The weather");
        question.setOptionD("The delivery route");
        question.setCorrectOption("A");
        question.setSortOrder(1);
        question.setIsActive(true);
        when(questions.findByCourseIdAndIsActiveTrueOrderBySortOrderAscQuestionIdAsc(COURSE_ID))
                .thenReturn(List.of(question));

        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(
                        new AuthUser(500L, "employee@example.test", Set.of("EMPLOYEE"), Set.of(), EMPLOYEE_ID),
                        null, List.of()));
    }

    @AfterEach
    void clearAuthentication() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void employeeQuestionListDoesNotExposeCorrectOption() {
        List<QuizQuestionView> result = service.quiz(COURSE_ID);

        assertEquals(1, result.size());
        assertEquals(QUESTION_ID, result.get(0).questionId());
        assertEquals(List.of("A", "B", "C", "D"),
                result.get(0).options().stream().map(option -> option.key()).toList());
        assertFalse(List.of(result.get(0).getClass().getRecordComponents()).stream()
                .anyMatch(component -> component.getName().equalsIgnoreCase("correctOption")));
        assertEquals("A", question.getCorrectOption());
    }

    @Test
    void scoreAtOrAbovePassThresholdMarksTrainingPassedAndSetsValidity() {
        when(attempts.countByEmployeeIdAndCourseId(EMPLOYEE_ID, COURSE_ID)).thenReturn(0L);
        var result = service.submit(COURSE_ID,
                new QuizSubmissionRequest(List.of(new QuizAnswerRequest(QUESTION_ID, "a"))));

        assertTrue(result.passed());
        assertEquals(new BigDecimal("100.00"), result.score());
        assertEquals("PASSED", result.trainingStatus());
        assertEquals(NOW, enrollment.getCompletedAt());
        assertEquals(Instant.parse("2032-03-01T12:00:00Z"), enrollment.getExpiresAt());

        ArgumentCaptor<TrainingAttempt> savedAttempt = ArgumentCaptor.forClass(TrainingAttempt.class);
        verify(attempts).save(savedAttempt.capture());
        assertEquals("QUIZ", savedAttempt.getValue().getSource());
        assertEquals(500L, savedAttempt.getValue().getRecordedBy());
        verify(audit).log(eq("TRAINING_QUIZ_SUBMIT"), eq("TrainingAttempt"), any(), anyMap(), anyMap());
    }

    @Test
    void scoreBelowPassThresholdMarksTrainingFailedAndAllowsRetake() {
        when(attempts.countByEmployeeIdAndCourseId(EMPLOYEE_ID, COURSE_ID)).thenReturn(0L);
        var result = service.submit(COURSE_ID,
                new QuizSubmissionRequest(List.of(new QuizAnswerRequest(QUESTION_ID, "B"))));

        assertFalse(result.passed());
        assertEquals(BigDecimal.ZERO.setScale(2), result.score());
        assertEquals("FAILED", result.trainingStatus());
        assertEquals("FAILED", enrollment.getTrainingStatus());
        assertNull(enrollment.getCompletedAt());
        assertNull(enrollment.getExpiresAt());
        verify(attempts).save(any(TrainingAttempt.class));
    }

    @Test
    void submissionRejectsAnswersForAnotherQuestionWithoutRecordingAttempt() {
        BusinessException error = assertThrows(BusinessException.class,
                () -> service.submit(COURSE_ID,
                        new QuizSubmissionRequest(List.of(new QuizAnswerRequest(999L, "A")))));

        assertEquals(ErrorCode.VALIDATION_ERROR, error.getCode());
        verify(attempts, never()).save(any(TrainingAttempt.class));
        verify(trainings, never()).save(any(EmployeeTraining.class));
    }
}
