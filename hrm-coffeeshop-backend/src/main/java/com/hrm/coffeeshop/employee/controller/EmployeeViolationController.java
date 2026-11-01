package com.hrm.coffeeshop.employee.controller;

import com.hrm.coffeeshop.shared.dto.ViolationDto.DecisionView;
import com.hrm.coffeeshop.shared.dto.ViolationDto.ViolationView;
import com.hrm.coffeeshop.shared.service.RewardPenaltyService;
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

    public EmployeeViolationController(ViolationService violations, RewardPenaltyService decisions) {
        this.violations = violations;
        this.decisions = decisions;
    }

    @GetMapping("/rewards-penalties/me")
    public ApiResponse<PageResponse<DecisionView>> myDecisions(@PageableDefault(size = 20) Pageable p) {
        return ApiResponse.ok(decisions.mine(p));
    }
}
