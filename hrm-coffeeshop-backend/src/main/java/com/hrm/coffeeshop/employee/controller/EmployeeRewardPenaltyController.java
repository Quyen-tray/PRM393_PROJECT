package com.hrm.coffeeshop.employee.controller;

import com.hrm.coffeeshop.common.ApiResponse;
import com.hrm.coffeeshop.common.PageResponse;
import com.hrm.coffeeshop.shared.dto.ViolationDto.DecisionView;
import com.hrm.coffeeshop.shared.service.RewardPenaltyService;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class EmployeeRewardPenaltyController {
    private final RewardPenaltyService decisions;
    public EmployeeRewardPenaltyController(RewardPenaltyService decisions) { this.decisions = decisions; }

    @GetMapping("/rewards-penalties/me")
    public ApiResponse<PageResponse<DecisionView>> mine(@PageableDefault(size = 20) Pageable page) {
        // The service resolves the current employee; no client-supplied employee ID.
        return ApiResponse.ok(decisions.mine(page));
    }
}
