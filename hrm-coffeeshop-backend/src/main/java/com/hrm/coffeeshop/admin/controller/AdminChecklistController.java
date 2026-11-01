package com.hrm.coffeeshop.admin.controller;

import com.hrm.coffeeshop.shared.dto.ChecklistDto.TemplateRequest;
import com.hrm.coffeeshop.shared.dto.ChecklistDto.TemplateView;
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
public class AdminChecklistController {
    private final ChecklistService svc;

    public AdminChecklistController(ChecklistService svc) {
        this.svc = svc;
    }

    @GetMapping("/admin/checklist-templates")
    @PreAuthorize("hasAnyRole('SYSTEM_ADMIN','STORE_MANAGER')")
    public ApiResponse<List<TemplateView>> templates() { return ApiResponse.ok(svc.listTemplates(false)); }

    @PostMapping("/admin/checklist-templates")
    @PreAuthorize("hasRole('SYSTEM_ADMIN')")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<TemplateView> create(@Valid @RequestBody TemplateRequest r) {
        return ApiResponse.ok("Template created", svc.createTemplate(r));
    }

    @PostMapping("/admin/checklist-templates/{templateId}/activate")
    @PreAuthorize("hasRole('SYSTEM_ADMIN')")
    public ApiResponse<TemplateView> activate(@PathVariable Integer templateId) {
        return ApiResponse.ok("Template activated", svc.activateTemplate(templateId));
    }

    @PutMapping("/admin/checklist-templates/{templateId}")
    @PreAuthorize("hasRole('SYSTEM_ADMIN')")
    public ApiResponse<TemplateView> update(@PathVariable Integer templateId, @Valid @RequestBody TemplateRequest r) {
        return ApiResponse.ok("Template updated", svc.updateTemplate(templateId, r));
    }
}
