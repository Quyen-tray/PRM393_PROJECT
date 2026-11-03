package com.hrm.coffeeshop.employee.controller;

import com.hrm.coffeeshop.shared.dto.ViolationDto.DecisionView;
import com.hrm.coffeeshop.shared.dto.ViolationDto.ViolationView;
import com.hrm.coffeeshop.shared.dto.ViolationExplanationDto.ExplanationRequest;
import com.hrm.coffeeshop.shared.dto.ViolationExplanationDto.ExplanationView;
import com.hrm.coffeeshop.shared.service.RewardPenaltyService;
import com.hrm.coffeeshop.shared.service.ViolationExplanationService;
import com.hrm.coffeeshop.shared.service.ViolationService;

import com.hrm.coffeeshop.common.*;
import jakarta.validation.Valid;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
public class EmployeeViolationController {
    private final ViolationService violations;
    private final RewardPenaltyService decisions;
    private final ViolationExplanationService explanations;

    public EmployeeViolationController(ViolationService violations, RewardPenaltyService decisions,
                                       ViolationExplanationService explanations) {
        this.violations = violations;
        this.decisions = decisions;
        this.explanations = explanations;
    }

    @GetMapping("/employees/me/violations")
    public ApiResponse<PageResponse<ViolationView>> myViolations(
            @PageableDefault(size = 50, sort = "occurredAt", direction = Sort.Direction.DESC) Pageable p) {
        return ApiResponse.ok(violations.list(null, SecurityUtils.requireEmployeeId(), p));
    }

    @GetMapping("/employees/me/violations/{violationId}/explanations")
    public ApiResponse<java.util.List<ExplanationView>> myExplanations(@PathVariable Long violationId) {
        return ApiResponse.ok(explanations.listMine(SecurityUtils.requireEmployeeId(), violationId));
    }

    @PostMapping("/employees/me/violations/{violationId}/explanations")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<ExplanationView> submitExplanation(@PathVariable Long violationId,
                                                           @Valid @RequestBody ExplanationRequest request) {
        return ApiResponse.ok("Đã gửi giải trình", explanations.submitMine(
                SecurityUtils.requireEmployeeId(), violationId, request));
    }

    @GetMapping("/rewards-penalties/me")
    public ApiResponse<PageResponse<DecisionView>> myDecisions(@PageableDefault(size = 20) Pageable p) {
        return ApiResponse.ok(decisions.mine(p));
    }
}
