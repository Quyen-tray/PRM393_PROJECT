package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.common.AuthUser;
import com.hrm.coffeeshop.common.BusinessException;
import com.hrm.coffeeshop.common.ErrorCode;
import com.hrm.coffeeshop.common.Permissions;
import com.hrm.coffeeshop.domain.ViolationEvent;
import com.hrm.coffeeshop.domain.ViolationExplanation;
import com.hrm.coffeeshop.repository.ViolationEventRepository;
import com.hrm.coffeeshop.repository.ViolationExplanationRepository;
import com.hrm.coffeeshop.shared.dto.ViolationExplanationDto.ExplanationRequest;
import com.hrm.coffeeshop.shared.dto.ViolationExplanationDto.ExplanationView;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
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
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ViolationExplanationServiceTest {
    private static final long EMPLOYEE_ID = 42L;
    private static final long VIOLATION_ID = 70L;
    private static final String OWN_KEY = "private-documents/employee-42/evidence.png";

    @Mock ViolationEventRepository violations;
    @Mock ViolationExplanationRepository explanations;
    @Mock StorageGateway storage;
    @Mock AuditService audit;

    private ViolationExplanationService service;
    private ViolationEvent violation;

    @BeforeEach
    void setUp() {
        service = new ViolationExplanationService(violations, explanations, storage, audit,
                Clock.fixed(Instant.parse("2031-03-01T12:00:00Z"), ZoneOffset.UTC));
        violation = new ViolationEvent();
        violation.setViolationEventId(VIOLATION_ID);
        violation.setEmployeeId(EMPLOYEE_ID);
        violation.setRecordStatus("PENDING");
        lenient().when(violations.findById(VIOLATION_ID)).thenReturn(Optional.of(violation));
        lenient().when(violations.findByIdForUpdate(VIOLATION_ID)).thenReturn(Optional.of(violation));
        login(500L, EMPLOYEE_ID, Set.of());
    }

    @AfterEach
    void clearAuthentication() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void submissionSavesTrimmedAppendOnlyRecordWithoutChangingViolationOrReviewNote() {
        when(explanations.save(any(ViolationExplanation.class))).thenAnswer(invocation -> {
            ViolationExplanation saved = invocation.getArgument(0);
            saved.setViolationExplanationId(900L);
            return saved;
        });

        ExplanationView result = service.submitMine(EMPLOYEE_ID, VIOLATION_ID,
                new ExplanationRequest("  I followed the closing checklist.  ", null));

        ArgumentCaptor<ViolationExplanation> saved = ArgumentCaptor.forClass(ViolationExplanation.class);
        verify(explanations).save(saved.capture());
        assertEquals(900L, result.explanationId());
        assertEquals("I followed the closing checklist.", saved.getValue().getExplanation());
        assertEquals(EMPLOYEE_ID, saved.getValue().getEmployeeId());
        assertEquals(VIOLATION_ID, saved.getValue().getViolationEventId());
        assertEquals(Instant.parse("2031-03-01T12:00:00Z"), saved.getValue().getSubmittedAt());
        assertEquals("PENDING", violation.getRecordStatus());
        assertNull(violation.getReviewNote());
        verify(audit).log(eq("VIOLATION_EXPLANATION_SUBMITTED"), eq("ViolationEvent"),
                eq(VIOLATION_ID), isNull(), anyMap());
    }

    @Test
    void rejectsAnotherEmployeesViolationWithoutLookingUpOrSavingExplanation() {
        BusinessException error = assertThrows(BusinessException.class,
                () -> service.submitMine(EMPLOYEE_ID + 1, VIOLATION_ID,
                        new ExplanationRequest("Not mine", null)));

        assertEquals(ErrorCode.NOT_FOUND, error.getCode());
        verify(explanations, never()).save(any());
        verify(explanations, never()).findByViolationEventIdOrderBySubmittedAtAscViolationExplanationIdAsc(anyLong());
    }

    @Test
    void rejectsClosedViolationWithoutSavingExplanation() {
        violation.setRecordStatus("APPROVED");

        BusinessException error = assertThrows(BusinessException.class,
                () -> service.submitMine(EMPLOYEE_ID, VIOLATION_ID,
                        new ExplanationRequest("Too late", null)));

        assertEquals(ErrorCode.INVALID_STATE, error.getCode());
        verify(explanations, never()).save(any());
    }

    @Test
    void evidenceMustExistInTheAuthenticatedEmployeesPrivateNamespaceAndIsNeverReturnedAsKey() {
        login(500L, EMPLOYEE_ID, Set.of());
        when(storage.exists(OWN_KEY)).thenReturn(true);
        when(storage.createViewUrl(eq(OWN_KEY), any(), eq(500L))).thenReturn("https://signed.example/evidence");
        when(explanations.save(any(ViolationExplanation.class))).thenAnswer(invocation -> {
            ViolationExplanation saved = invocation.getArgument(0);
            saved.setViolationExplanationId(901L);
            return saved;
        });

        ExplanationView result = service.submitMine(EMPLOYEE_ID, VIOLATION_ID,
                new ExplanationRequest("See attached evidence", OWN_KEY));

        assertEquals("https://signed.example/evidence", result.evidenceViewUrl());
        assertFalse(List.of(result.getClass().getRecordComponents()).stream()
                .anyMatch(component -> component.getName().equals("evidenceStorageKey")));

        BusinessException wrongOwner = assertThrows(BusinessException.class,
                () -> service.submitMine(EMPLOYEE_ID, VIOLATION_ID,
                        new ExplanationRequest("Wrong owner", "private-documents/employee-43/other.png")));
        assertEquals(ErrorCode.VALIDATION_ERROR, wrongOwner.getCode());
        verify(explanations, times(1)).save(any(ViolationExplanation.class));
    }

    @Test
    void reviewerReadRequiresViolationReviewPermission() {
        BusinessException error = assertThrows(BusinessException.class,
                () -> service.listForReview(VIOLATION_ID));
        assertEquals(ErrorCode.PERMISSION_DENIED, error.getCode());
        verify(explanations, never()).findByViolationEventIdOrderBySubmittedAtAscViolationExplanationIdAsc(anyLong());

        login(501L, null, Set.of(Permissions.VIOLATION_REVIEW));
        when(explanations.findByViolationEventIdOrderBySubmittedAtAscViolationExplanationIdAsc(VIOLATION_ID))
                .thenReturn(List.of());
        assertTrue(service.listForReview(VIOLATION_ID).isEmpty());
    }

    private static void login(long userId, Long employeeId, Set<String> permissions) {
        AuthUser user = new AuthUser(userId, "it-user@hrm.test", Set.of(), permissions, employeeId);
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(user, null, List.of()));
    }
}
