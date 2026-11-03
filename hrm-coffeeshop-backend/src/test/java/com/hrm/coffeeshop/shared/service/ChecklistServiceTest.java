package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.common.AuthUser;
import com.hrm.coffeeshop.common.PageResponse;
import com.hrm.coffeeshop.domain.ChecklistReview;
import com.hrm.coffeeshop.domain.ChecklistTask;
import com.hrm.coffeeshop.domain.ChecklistTemplate;
import com.hrm.coffeeshop.repository.*;
import com.hrm.coffeeshop.shared.dto.ChecklistDto.RunView;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class ChecklistServiceTest {
    private static final long EMPLOYEE_ID = 42L;

    private final ChecklistTemplateRepository templates = mock(ChecklistTemplateRepository.class);
    private final ChecklistTemplateItemRepository templateItems = mock(ChecklistTemplateItemRepository.class);
    private final ChecklistTaskRepository runs = mock(ChecklistTaskRepository.class);
    private final ChecklistTaskItemRepository runItems = mock(ChecklistTaskItemRepository.class);
    private final ShiftAssignmentRepository schedules = mock(ShiftAssignmentRepository.class);
    private final com.hrm.coffeeshop.repository.EmployeeRepository employees =
            mock(com.hrm.coffeeshop.repository.EmployeeRepository.class);
    private final StoreService storeService = mock(StoreService.class);
    private final PersonLookup people = mock(PersonLookup.class);
    private final NotificationService notifications = mock(NotificationService.class);
    private final AuditService audit = mock(AuditService.class);
    private final ChecklistInstanceRepository instances = mock(ChecklistInstanceRepository.class);
    private final ChecklistEvidenceRepository evidences = mock(ChecklistEvidenceRepository.class);
    private final ChecklistReviewRepository reviews = mock(ChecklistReviewRepository.class);
    private final StorageGateway storage = mock(StorageGateway.class);

    private ChecklistService service;

    @BeforeEach
    void setUp() {
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(
                        new AuthUser(501L, "employee@hrm.test", Set.of(), Set.of(), EMPLOYEE_ID),
                        null,
                        List.of()));
        service = new ChecklistService(
                templates,
                templateItems,
                runs,
                runItems,
                schedules,
                employees,
                storeService,
                people,
                notifications,
                audit,
                Clock.fixed(Instant.parse("2026-11-03T00:00:00Z"), ZoneOffset.UTC),
                instances,
                evidences,
                reviews,
                storage);
    }

    @AfterEach
    void tearDown() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void employeeListReturnsAllRunStatusesAsSummariesWithoutLoadingItemDetails() {
        ChecklistTemplate template = new ChecklistTemplate();
        template.setChecklistTemplateId(21);
        template.setChecklistName("Opening checklist");
        template.setChecklistType("OPENING");
        when(templates.findById(21)).thenReturn(Optional.of(template));
        when(runs.findByEmployeeIdOrderByDueAtDesc(EMPLOYEE_ID)).thenReturn(List.of(
                run(101L, "SUBMITTED"),
                run(100L, "APPROVED")));

        List<RunView> result = service.myTasks(null);

        assertEquals(List.of("SUBMITTED", "APPROVED"),
                result.stream().map(RunView::status).toList());
        assertTrue(result.stream().allMatch(run -> run.items().isEmpty()));
        assertTrue(result.stream().allMatch(run -> run.employeeName() == null));
        assertTrue(result.stream().allMatch(run -> run.reviewNote() == null));
        verify(runs).findByEmployeeIdOrderByDueAtDesc(EMPLOYEE_ID);
        verify(runs, never()).findMine(anyLong(), anyCollection());
        verify(runItems, never()).findByChecklistTaskIdOrderByChecklistTaskItemIdAsc(anyLong());
        verify(evidences, never()).findByChecklistTaskId(anyLong());
        verify(reviews, never()).findFirstByChecklistTaskIdOrderByReviewedAtDesc(anyLong());
        verify(reviews, never()).findByChecklistTaskIdInOrderByReviewedAtDesc(anyCollection());
        verify(people, never()).namesOf(anyCollection());
    }

    @Test
    void managerChecklistQueueKeepsEmployeeNameAndLatestReviewReasonInSummary() {
        ChecklistTemplate template = new ChecklistTemplate();
        template.setChecklistTemplateId(21);
        template.setChecklistName("Opening checklist");
        template.setChecklistType("OPENING");
        when(templates.findById(21)).thenReturn(Optional.of(template));

        ChecklistTask rejected = run(99L, "REJECTED");
        PageRequest pageable = PageRequest.of(0, 10);
        when(runs.searchByStatus("REJECTED", pageable))
                .thenReturn(new PageImpl<>(List.of(rejected), pageable, 1));
        when(people.namesOf(anyCollection())).thenReturn(Map.of(EMPLOYEE_ID, "Employee Forty Two"));
        ChecklistReview latestReview = new ChecklistReview();
        latestReview.setChecklistTaskId(99L);
        latestReview.setReason("Please redo the espresso station.");
        ChecklistReview olderReview = new ChecklistReview();
        olderReview.setChecklistTaskId(99L);
        olderReview.setReason("Older review note.");
        when(reviews.findByChecklistTaskIdInOrderByReviewedAtDesc(anyCollection()))
                .thenReturn(List.of(latestReview, olderReview));

        PageResponse<RunView> response = service.list("REJECTED", pageable);

        RunView item = response.items().get(0);
        assertEquals("Employee Forty Two", item.employeeName());
        assertEquals("Please redo the espresso station.", item.reviewNote());
        assertTrue(item.items().isEmpty());
        verify(people).namesOf(anyCollection());
        verify(reviews).findByChecklistTaskIdInOrderByReviewedAtDesc(anyCollection());
        verify(runItems, never()).findByChecklistTaskIdOrderByChecklistTaskItemIdAsc(99L);
        verify(evidences, never()).findByChecklistTaskId(99L);
    }

    private static ChecklistTask run(long taskId, String status) {
        ChecklistTask run = new ChecklistTask();
        run.setChecklistTaskId(taskId);
        run.setChecklistTemplateId(21);
        run.setEmployeeId(EMPLOYEE_ID);
        run.setDueAt(Instant.parse("2026-11-03T08:00:00Z"));
        run.setRunStatus(status);
        return run;
    }
}
