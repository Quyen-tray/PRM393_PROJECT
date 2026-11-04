package com.hrm.coffeeshop.shared.controller;
import com.hrm.coffeeshop.common.ApiResponse;
import com.hrm.coffeeshop.shared.dto.ViolationDto.DecisionView;
import com.hrm.coffeeshop.shared.service.RewardPenaltyService;
import org.springframework.web.bind.annotation.*;

@RestController
public class DecisionDetailController {
    private final RewardPenaltyService service;
    public DecisionDetailController(RewardPenaltyService service) { this.service = service; }
    @GetMapping("/rewards-penalties/{id}")
    public ApiResponse<DecisionView> detail(@PathVariable Long id) { return ApiResponse.ok(service.get(id)); }
}
