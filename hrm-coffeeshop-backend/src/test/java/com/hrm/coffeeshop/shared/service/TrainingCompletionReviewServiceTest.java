package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.common.AuthUser;
import com.hrm.coffeeshop.common.BusinessException;
import com.hrm.coffeeshop.common.ErrorCode;
import com.hrm.coffeeshop.common.Permissions;
import com.hrm.coffeeshop.common.Roles;
import com.hrm.coffeeshop.domain.Employee;
import com.hrm.coffeeshop.domain.EmployeeTraining;
import com.hrm.coffeeshop.domain.TrainingCourse;
import com.hrm.coffeeshop.repository.AppUserRepository;
import com.hrm.coffeeshop.repository.EmployeeRepository;
import com.hrm.coffeeshop.repository.EmployeeTrainingRepository;
import com.hrm.coffeeshop.repository.PositionTrainingRequirementRepository;
import com.hrm.coffeeshop.repository.TrainingAttemptRepository;
import com.hrm.coffeeshop.repository.TrainingCourseRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class TrainingCompletionReviewServiceTest {
    private static final long EMPLOYEE_ID = 42L;
    private static final long EMPLOYEE_TRAINING_ID = 900L;
    private static final long MANAGER_ID = 7L;
    private static final int COURSE_ID = 4;
    private static final Instant NOW = Instant.parse("2031-03-01T12:00:00Z");

    @Mock TrainingCourseRepository courses;
    @Mock EmployeeTrainingRepository trainings;
    @Mock EmployeeRepository employees;
    @Mock AppUserRepository users;
    @Mock PositionTrainingRequirementRepository requirements;
    @Mock TrainingAttemptRepository attempts;
    @Mock AuditService audit;

    private TrainingService service;
    private TrainingCourse course;
    private Employee employee;
    private EmployeeTraining enrollment;

    @BeforeEach
    void setUp() {
        service = new TrainingService(courses, trainings, employees, users, requirements, attempts,
                audit, Clock.fixed(NOW, ZoneOffset.UTC));

        course = new TrainingCourse();
        course.setCourseId(COURSE_ID);
        course.setCourseName("Food safety practical");
        course.setIsActive(true);
        course.setIsMandatoryTest(false);
        course.setValidityMonths(12);
        lenient().when(courses.findById(COURSE_ID)).thenReturn(Optional.of(course));

        employee = new Employee();
        employee.setEmployeeId(EMPLOYEE_ID);
        employee.setUserId(EMPLOYEE_ID);
        employee.setEmployeeCode("EMP-42");
        lenient().when(employees.findById(EMPLOYEE_ID)).thenReturn(Optional.of(employee));

        enrollment = new EmployeeTraining();
        enrollment.setEmployeeTrainingId(EMPLOYEE_TRAINING_ID);
        enrollment.setEmployeeId(EMPLOYEE_ID);
        enrollment.setCourseId(COURSE_ID);
        enrollment.setTrainingStatus("IN_PROGRESS");
        lenient().when(trainings.findByEmployeeIdAndCourseId(EMPLOYEE_ID, COURSE_ID))
                .thenReturn(Optional.of(enrollment));

        authenticate(Set.of(), EMPLOYEE_ID, EMPLOYEE_ID);
    }

    @AfterEach
    void clearAuthentication() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void enrolledPracticalCourseAppearsInManagerReviewQueue() {
        enrollment.setAssignedAt(NOW);
        when(trainings.findAll()).thenReturn(List.of(enrollment));
        when(courses.findAll()).thenReturn(List.of(course));
        authenticate(Set.of(Permissions.TRAINING_MANAGE), MANAGER_ID, null);

        var result = service.pendingCompletionReviews();

        assertEquals(1, result.size());
        assertEquals(EMPLOYEE_TRAINING_ID, result.get(0).employeeTrainingId());
        assertEquals(NOW.atOffset(ZoneOffset.ofHours(7)), result.get(0).enrolledAt());
        assertNull(result.get(0).reviewNote());
    }

    @Test
    void quizCourseDoesNotAppearInManualReviewQueue() {
        course.setIsMandatoryTest(true);
        when(trainings.findAll()).thenReturn(List.of(enrollment));
        when(courses.findAll()).thenReturn(List.of(course));
        authenticate(Set.of(Permissions.TRAINING_MANAGE), MANAGER_ID, null);

        assertTrue(service.pendingCompletionReviews().isEmpty());
    }

    @Test
    void managerApprovalMarksCoursePassedAndSetsValidity() {
        enrollment.setTrainingStatus("NOT_STARTED");
        when(trainings.findById(EMPLOYEE_TRAINING_ID)).thenReturn(Optional.of(enrollment));
        authenticate(Set.of(Permissions.TRAINING_MANAGE), MANAGER_ID, null);

        var result = service.approveCompletion(EMPLOYEE_TRAINING_ID, "Đã kiểm tra");

        assertEquals("PASSED", result.status());
        assertEquals(NOW, enrollment.getCompletedAt());
        assertEquals(Instant.parse("2032-03-01T12:00:00Z"), enrollment.getExpiresAt());
        assertEquals(MANAGER_ID, enrollment.getCompletionReviewedBy());
        assertEquals("Đã kiểm tra", enrollment.getCompletionReviewNote());
        verify(trainings).save(enrollment);
    }

    @Test
    void managerRejectionReturnsCourseToInProgressAndKeepsFeedbackForEmployee() {
        enrollment.setTrainingStatus("NOT_STARTED");
        enrollment.setCompletionRequestNote("Completed practice");
        when(trainings.findById(EMPLOYEE_TRAINING_ID)).thenReturn(Optional.of(enrollment));
        authenticate(Set.of(Permissions.TRAINING_MANAGE), MANAGER_ID, null);

        var result = service.markNotComplete(EMPLOYEE_TRAINING_ID, "Vui lòng thực hành thêm");

        assertEquals("IN_PROGRESS", result.status());
        assertNull(result.completionRequestNote());
        assertEquals("Vui lòng thực hành thêm", result.completionReviewNote());
        assertEquals(MANAGER_ID, enrollment.getCompletionReviewedBy());
        verify(trainings).save(enrollment);
    }

    @Test
    void managerActionsRequireTrainingManagePermission() {
        authenticate(Set.of(), MANAGER_ID, null);

        BusinessException error = assertThrows(BusinessException.class,
                () -> service.approveCompletion(EMPLOYEE_TRAINING_ID, null));

        assertEquals(ErrorCode.PERMISSION_DENIED, error.getCode());
        verify(trainings, never()).save(any(EmployeeTraining.class));
    }

    @Test
    void systemAdminCanApprovePracticalCompletionWithoutTrainingPermission() {
        when(trainings.findById(EMPLOYEE_TRAINING_ID)).thenReturn(Optional.of(enrollment));
        authenticate(Set.of(Roles.SYSTEM_ADMIN), Set.of(), MANAGER_ID, null);

        var result = service.approveCompletion(EMPLOYEE_TRAINING_ID, null);

        assertEquals("PASSED", result.status());
        assertEquals(MANAGER_ID, enrollment.getCompletionReviewedBy());
        verify(trainings).save(enrollment);
    }

    private void authenticate(Set<String> permissions, Long userId, Long employeeId) {
        authenticate(Set.of(), permissions, userId, employeeId);
    }

    private void authenticate(Set<String> roles, Set<String> permissions, Long userId, Long employeeId) {
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(
                        new AuthUser(userId, "user@example.test", roles, permissions, employeeId),
                        null, List.of()));
    }
}
