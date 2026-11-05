package com.hrm.coffeeshop.employee.controller;

import com.hrm.coffeeshop.shared.dto.ChecklistDto.AddEvidenceRequest;
import com.hrm.coffeeshop.shared.dto.ChecklistDto.CompleteItemRequest;
import com.hrm.coffeeshop.shared.dto.ChecklistDto.RunView;
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
public class EmployeeChecklistController {
    private final ChecklistService svc;

    public EmployeeChecklistController(ChecklistService svc) {
        this.svc = svc;
    }

    @GetMapping({"/checklists/me", "/checklists/tasks/me"})
    public ApiResponse<List<RunView>> mine(@RequestParam(required = false) String status) { return ApiResponse.ok(svc.myTasks(status)); }

    @PostMapping("/checklists/tasks/{taskId}/start")
    public ApiResponse<RunView> start(@PathVariable Long taskId) { return ApiResponse.ok("Checklist started", svc.start(taskId)); }

    @PostMapping("/checklists/tasks/{taskId}/items/{runItemId}/complete")
    public ApiResponse<RunView> complete(@PathVariable Long taskId, @PathVariable Long runItemId,
                                         @Valid @RequestBody(required = false) CompleteItemRequest r) {
        return ApiResponse.ok("Item completed", svc.completeItem(taskId, runItemId, r));
    }

    /** SRS 9.x: thêm minh chứng cho một mục (chưa đánh dấu hoàn thành). Ảnh tải lên trước qua /storage/uploads. */
    @PostMapping("/checklists/tasks/{taskId}/evidence")
    public ApiResponse<RunView> evidence(@PathVariable Long taskId, @Valid @RequestBody AddEvidenceRequest r) {
        return ApiResponse.ok("Evidence added", svc.addEvidence(taskId, r));
    }

    @PostMapping("/checklists/tasks/{taskId}/submit")
    public ApiResponse<RunView> submit(@PathVariable Long taskId) { return ApiResponse.ok("Checklist submitted", svc.submit(taskId)); }
}
