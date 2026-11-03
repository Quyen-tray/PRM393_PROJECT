package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.common.BusinessException;
import com.hrm.coffeeshop.common.ErrorCode;
import com.hrm.coffeeshop.common.AuthUser;
import com.hrm.coffeeshop.common.Permissions;
import com.hrm.coffeeshop.domain.DocumentType;
import com.hrm.coffeeshop.domain.Employee;
import com.hrm.coffeeshop.domain.EmployeeDocument;
import com.hrm.coffeeshop.domain.PositionDocumentRequirement;
import com.hrm.coffeeshop.repository.AppUserRepository;
import com.hrm.coffeeshop.repository.DocumentTypeRepository;
import com.hrm.coffeeshop.repository.EmployeeDocumentRepository;
import com.hrm.coffeeshop.repository.EmployeeRepository;
import com.hrm.coffeeshop.repository.PositionDocumentRequirementRepository;
import com.hrm.coffeeshop.shared.dto.DocumentDto.SubmitRequest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import java.lang.reflect.Method;
import java.util.Set;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class DocumentServiceTest {
    private static final long EMPLOYEE_ID = 42L;
    private static final int TYPE_ID = 8;
    private static final LocalDate TODAY = LocalDate.of(2031, 3, 1);
    private static final String NEW_KEY = "private-documents/employee-42/new.pdf";

    @Mock DocumentTypeRepository types;
    @Mock PositionDocumentRequirementRepository requirements;
    @Mock EmployeeDocumentRepository docs;
    @Mock EmployeeRepository employees;
    @Mock AppUserRepository users;
    @Mock StorageGateway storage;
    @Mock NotificationService notifications;
    @Mock AuditService audit;

    private DocumentService service;
    private DocumentType type;
    private Employee employee;

    @BeforeEach
    void setUp() {
        Clock clock = Clock.fixed(Instant.parse("2031-03-01T12:00:00Z"), ZoneOffset.UTC);
        service = new DocumentService(types, requirements, docs, employees, users, storage,
                notifications, audit, clock);
        type = new DocumentType();
        type.setDocumentTypeId(TYPE_ID);
        type.setDocumentCode("IT_DOC");
        type.setDocumentName("Integration document");
        type.setIsActive(true);
        employee = new Employee();
        employee.setEmployeeId(EMPLOYEE_ID);
        employee.setUserId(11L);
        employee.setPositionId(null);
        org.mockito.Mockito.lenient()
                .when(employees.findById(EMPLOYEE_ID)).thenReturn(Optional.of(employee));
    }

    @AfterEach
    void clearSecurityContext() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void employeeViewAloneCannotReadAnotherEmployeesDocumentOrCreateItsViewUrl() {
        EmployeeDocument document = new EmployeeDocument();
        document.setEmployeeDocumentId(100L);
        document.setEmployeeId(EMPLOYEE_ID);
        document.setDocumentTypeId(TYPE_ID);
        when(docs.findById(100L)).thenReturn(Optional.of(document));
        authenticate(new AuthUser(99L, "viewer@hrm.test", Set.of(),
                Set.of(Permissions.EMPLOYEE_VIEW), 99L));

        assertThrows(BusinessException.class, () -> service.list(EMPLOYEE_ID));
        assertThrows(BusinessException.class, () -> service.get(100L));
        verify(storage, never()).createViewUrl(anyString(), any(), any());
    }

    @Test
    void documentReviewPermissionAloneCanApproveAnotherEmployeesPendingDocument() {
        EmployeeDocument document = new EmployeeDocument();
        document.setEmployeeDocumentId(100L);
        document.setEmployeeId(EMPLOYEE_ID);
        document.setDocumentTypeId(TYPE_ID);
        document.setReviewStatus("PENDING");
        when(docs.findById(100L)).thenReturn(Optional.of(document));
        when(types.findById(TYPE_ID)).thenReturn(Optional.of(type));
        when(types.findAll()).thenReturn(List.of(type));
        when(docs.findByEmployeeId(EMPLOYEE_ID)).thenReturn(List.of());
        authenticate(new AuthUser(99L, "reviewer@hrm.test", Set.of(),
                Set.of(Permissions.DOCUMENT_REVIEW), null));

        service.approve(100L);

        assertEquals("APPROVED", document.getReviewStatus());
    }

    @Test
    void submitBlocksAnApprovedDocumentWithNoExpiryOrExpiryToday() {
        when(types.findById(TYPE_ID)).thenReturn(Optional.of(type));
        when(storage.exists(NEW_KEY)).thenReturn(true);
        for (LocalDate expiry : new LocalDate[]{null, TODAY}) {
            EmployeeDocument approved = new EmployeeDocument();
            approved.setEmployeeId(EMPLOYEE_ID);
            approved.setDocumentTypeId(TYPE_ID);
            approved.setReviewStatus("APPROVED");
            approved.setExpiresAt(expiry);
            when(docs.findByEmployeeId(EMPLOYEE_ID)).thenReturn(List.of(approved));

            BusinessException error = assertThrows(BusinessException.class,
                    () -> service.submit(EMPLOYEE_ID, new SubmitRequest(TYPE_ID, NEW_KEY, null, null)));

            assertEquals(ErrorCode.CONFLICT, error.getCode());
            verify(docs, never()).save(any(EmployeeDocument.class));
        }
    }

    @Test
    void catalogShowsActiveTypesAndEffectivePositionRequirements() throws Exception {
        employee.setPositionId(21);
        DocumentType required = type(20, "REQUIRED", true);
        DocumentType optional = type(21, "OPTIONAL", true);
        type(22, "INACTIVE", false);
        PositionDocumentRequirement requirement = new PositionDocumentRequirement();
        requirement.setPositionId(21);
        requirement.setDocumentTypeId(20);
        requirement.setIsMandatory(true);
        EmployeeDocument pending = new EmployeeDocument();
        pending.setEmployeeId(EMPLOYEE_ID);
        pending.setDocumentTypeId(20);
        pending.setReviewStatus("PENDING");
        when(types.findByIsActiveTrue()).thenReturn(List.of(required, optional));
        when(docs.findByEmployeeIdOrderByUploadedAtDesc(EMPLOYEE_ID)).thenReturn(List.of(pending));
        when(requirements.findEffective(21, TODAY)).thenReturn(List.of(requirement));

        Method catalogMethod = assertDoesNotThrow(() -> DocumentService.class.getMethod("catalog", Long.class));
        Object catalog = catalogMethod.invoke(service, EMPLOYEE_ID);
        int positionId = (int) catalog.getClass().getMethod("positionId").invoke(catalog);
        @SuppressWarnings("unchecked")
        List<Object> items = (List<Object>) catalog.getClass().getMethod("documents").invoke(catalog);

        assertEquals(21, positionId);
        assertEquals(2, items.size());
        assertEquals(true, item(items, 20).getClass().getMethod("required").invoke(item(items, 20)));
        assertEquals(false, item(items, 21).getClass().getMethod("required").invoke(item(items, 21)));
        assertEquals("PENDING", item(items, 20).getClass().getMethod("latestStatus").invoke(item(items, 20)));
        assertEquals(false, item(items, 20).getClass().getMethod("canSubmit").invoke(item(items, 20)));
        assertEquals(true, item(items, 21).getClass().getMethod("canSubmit").invoke(item(items, 21)));
        assertFalse(items.stream().anyMatch(i -> invokeInt(i, "documentTypeId") == 22));
        assertFalse(java.util.Arrays.stream(items.get(0).getClass().getRecordComponents())
                .anyMatch(component -> component.getName().toLowerCase().contains("storagekey")));
    }

    @Test
    void submitAllowsRejectedExpiredAndPastExpiryApprovedDocumentsWithoutReplacingHistory() {
        when(types.findById(TYPE_ID)).thenReturn(Optional.of(type));
        when(storage.exists(NEW_KEY)).thenReturn(true);
        when(types.findAll()).thenReturn(List.of(type));
        when(docs.save(any(EmployeeDocument.class))).thenAnswer(invocation -> invocation.getArgument(0));

        for (String status : new String[]{"REJECTED", "EXPIRED", "APPROVED"}) {
            EmployeeDocument previous = new EmployeeDocument();
            previous.setEmployeeDocumentId(100L);
            previous.setEmployeeId(EMPLOYEE_ID);
            previous.setDocumentTypeId(TYPE_ID);
            previous.setReviewStatus(status);
            previous.setExpiresAt("APPROVED".equals(status) ? TODAY.minusDays(1) : null);
            when(docs.findByEmployeeId(EMPLOYEE_ID)).thenReturn(List.of(previous));
            clearInvocations(docs);

            var submitted = service.submit(EMPLOYEE_ID, new SubmitRequest(TYPE_ID, NEW_KEY, null, null));

            assertNotNull(submitted);
            assertEquals(status, previous.getReviewStatus());
            verify(docs).save(argThat(saved -> saved.getEmployeeId().equals(EMPLOYEE_ID)
                    && saved.getDocumentTypeId().equals(TYPE_ID)
                    && "PENDING".equals(saved.getReviewStatus())));
        }
    }

    private DocumentType type(int id, String code, boolean active) {
        DocumentType value = new DocumentType();
        value.setDocumentTypeId(id);
        value.setDocumentCode(code);
        value.setDocumentName(code);
        value.setIsActive(active);
        return value;
    }

    private Object item(List<Object> items, int typeId) {
        return items.stream().filter(i -> invokeInt(i, "documentTypeId") == typeId).findFirst().orElseThrow();
    }

    private int invokeInt(Object target, String methodName) {
        try {
            return (int) target.getClass().getMethod(methodName).invoke(target);
        } catch (ReflectiveOperationException e) {
            throw new AssertionError(e);
        }
    }

    private void authenticate(AuthUser user) {
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(user, null, List.of()));
    }
}
