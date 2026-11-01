package com.hrm.coffeeshop.manager.controller;

import com.hrm.coffeeshop.manager.dto.ManagerChecklistDto.ReassignRequest;
import com.hrm.coffeeshop.shared.dto.ChecklistDto.GenerateRequest;
import com.hrm.coffeeshop.shared.dto.ChecklistDto.RunView;
import com.hrm.coffeeshop.shared.dto.MiscDto.OptionalNoteRequest;
import com.hrm.coffeeshop.shared.dto.MiscDto.ReasonRequest;
import com.hrm.coffeeshop.shared.service.ChecklistService;

import com.hrm.coffeeshop.common.*;
import jakarta.validation.Valid;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
public class ManagerChecklistController {
    private final ChecklistService svc;

    public ManagerChecklistController(ChecklistService svc) {
        this.svc = svc;
    }

    @PostMapping("/checklists/instances/generate")
    @PreAuthorize("hasRole('STORE_MANAGER')")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<RunView> generate(@Valid @RequestBody GenerateRequest r) {
        return ApiResponse.ok("Checklist created", svc.generate(r));
    }

    @PostMapping("/checklists/tasks/{taskId}/reassign")
    @PreAuthorize("hasRole('STORE_MANAGER')")
    public ApiResponse<RunView> reassign(@PathVariable Long taskId, @Valid @RequestBody ReassignRequest r) {
        return ApiResponse.ok("Checklist reassigned", svc.reassign(taskId, r.employeeId()));
    }

    @GetMapping({"/checklists/instances", "/checklists/tasks"})
    @PreAuthorize("hasAuthority('CHECKLIST_VIEW')")
    public ApiResponse<PageResponse<RunView>> list(@RequestParam(required = false) String status,
                                                   @PageableDefault(size = 20, sort = "dueAt", direction = Sort.Direction.DESC) Pageable p) {
        return ApiResponse.ok(svc.list(status, p));
    }

    /** SRS: danh sách checklist chờ Quản lý duyệt (đã nộp, ManagerStatus=PENDING). */
    @GetMapping("/checklists/reviews/pending")
    @PreAuthorize("hasAuthority('CHECKLIST_REVIEW')")
    public ApiResponse<PageResponse<RunView>> pendingReviews(
            @PageableDefault(size = 20, sort = "dueAt", direction = Sort.Direction.ASC) Pageable p) {
        return ApiResponse.ok(svc.list("SUBMITTED", p));
    }

    @PostMapping("/checklists/tasks/{taskId}/approve")
    @PreAuthorize("hasRole('STORE_MANAGER')")
    public ApiResponse<RunView> approve(@PathVariable Long taskId, @RequestBody(required = false) OptionalNoteRequest r) {
        return ApiResponse.ok("Checklist approved", svc.approve(taskId, r == null ? null : r.note()));
    }

    @PostMapping("/checklists/tasks/{taskId}/reject")
    @PreAuthorize("hasRole('STORE_MANAGER')")
    public ApiResponse<RunView> reject(@PathVariable Long taskId, @Valid @RequestBody ReasonRequest r) {
        return ApiResponse.ok("Checklist rejected", svc.reject(taskId, r.reason()));
    }
}
