package com.hrm.coffeeshop.shared.controller;

import com.hrm.coffeeshop.common.ApiResponse;
import com.hrm.coffeeshop.shared.dto.SkillDto.AssessRequest;
import com.hrm.coffeeshop.shared.dto.SkillDto.AssessmentView;
import com.hrm.coffeeshop.shared.dto.SkillDto.SkillRequest;
import com.hrm.coffeeshop.shared.dto.SkillDto.SkillView;
import com.hrm.coffeeshop.shared.service.SkillService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
public class SharedSkillController {
    private final SkillService svc;

    public SharedSkillController(SkillService svc) { this.svc = svc; }

    @GetMapping("/skills")
    public ApiResponse<List<SkillView>> list(@RequestParam(defaultValue="false") boolean includeInactive) { return ApiResponse.ok(includeInactive ? svc.listIncludingInactive() : svc.list()); }

    @PostMapping("/admin/skills")
    @PreAuthorize("hasRole('SYSTEM_ADMIN')")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<SkillView> create(@Valid @RequestBody SkillRequest r) {
        return ApiResponse.ok("Skill created", svc.create(r));
    }

    @PostMapping("/employees/{employeeId}/skills/assessments")
    @PreAuthorize("hasAuthority('TRAINING_MANAGE')")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<AssessmentView> assess(@PathVariable Long employeeId, @Valid @RequestBody AssessRequest r) {
        return ApiResponse.ok("Skill assessed", svc.assess(employeeId, r));
    }

    @GetMapping("/employees/{employeeId}/skills")
    public ApiResponse<List<AssessmentView>> history(@PathVariable Long employeeId) {
        return ApiResponse.ok(svc.history(employeeId));
    }
}
