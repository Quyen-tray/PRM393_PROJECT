package com.hrm.coffeeshop.employee.controller;

import com.hrm.coffeeshop.common.*;
import com.hrm.coffeeshop.shared.dto.ViolationDto.ViolationView;
import com.hrm.coffeeshop.shared.service.*;
import jakarta.validation.Valid;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
public class EmployeeViolationController {
    private final ViolationService violations;
    private final ViolationExplanationService explanations;
    public EmployeeViolationController(ViolationService violations, ViolationExplanationService explanations) {
        this.violations = violations; this.explanations = explanations;
    }
    @GetMapping("/employees/me/violations")
    public ApiResponse<PageResponse<ViolationView>> mine(@PageableDefault(size = 20) Pageable page) {
        return ApiResponse.ok(violations.list(null, SecurityUtils.requireEmployeeId(), page));
    }
    @GetMapping("/violations/{id}/explanations")
    public ApiResponse<List<ViolationExplanationService.View>> explanations(@PathVariable Long id) { return ApiResponse.ok(explanations.list(id)); }
    @PostMapping("/violations/{id}/explanations")
    @ResponseStatus(org.springframework.http.HttpStatus.CREATED)
    public ApiResponse<ViolationExplanationService.View> explain(@PathVariable Long id, @Valid @RequestBody ViolationExplanationService.Request request) {
        return ApiResponse.ok("Đã gửi giải trình", explanations.submit(id, request));
    }
}
