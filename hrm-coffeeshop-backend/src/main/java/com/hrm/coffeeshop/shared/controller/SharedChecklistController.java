package com.hrm.coffeeshop.shared.controller;

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
public class SharedChecklistController {
    private final ChecklistService svc;

    public SharedChecklistController(ChecklistService svc) {
        this.svc = svc;
    }

    @GetMapping("/checklists/tasks/{taskId}")
    public ApiResponse<RunView> get(@PathVariable Long taskId) { return ApiResponse.ok(svc.get(taskId)); }
}
