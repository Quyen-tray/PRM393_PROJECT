package com.hrm.coffeeshop.manager.controller;

import com.hrm.coffeeshop.shared.dto.MiscDto.OptionalNoteRequest;
import com.hrm.coffeeshop.shared.dto.MiscDto.ReasonRequest;
import com.hrm.coffeeshop.shared.dto.ViolationDto.DecisionRequest;
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
public class ManagerViolationController {
    private final ViolationService violations;
    private final RewardPenaltyService decisions;

    public ManagerViolationController(ViolationService violations, RewardPenaltyService decisions) {
        this.violations = violations;
        this.decisions = decisions;
    }

    @GetMapping("/violations")
    @PreAuthorize("hasAuthority('VIOLATION_REVIEW')")
    public ApiResponse<PageResponse<ViolationView>> list(@RequestParam(required = false) String status,
                                                         @RequestParam(required = false) Long employeeId,
                                                         @PageableDefault(size = 20, sort = "incidentAt", direction = Sort.Direction.DESC) Pageable p) {
        return ApiResponse.ok(violations.list(status, employeeId, p));
    }

    @PostMapping("/violations/{violationId}/confirm")
    @PreAuthorize("hasAuthority('VIOLATION_REVIEW')")
    public ApiResponse<ViolationView> confirm(@PathVariable Long violationId, @RequestBody(required = false) OptionalNoteRequest r) {
        return ApiResponse.ok("Violation confirmed", violations.confirm(violationId, r == null ? null : r.note()));
    }

    @PostMapping("/violations/{violationId}/dismiss")
    @PreAuthorize("hasAuthority('VIOLATION_REVIEW')")
    public ApiResponse<ViolationView> dismiss(@PathVariable Long violationId, @Valid @RequestBody ReasonRequest r) {
        return ApiResponse.ok("Violation dismissed", violations.dismiss(violationId, r.reason()));
    }

    @PostMapping("/rewards-penalties")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<DecisionView> create(@Valid @RequestBody DecisionRequest r) {
        return ApiResponse.ok("Decision proposed", decisions.create(r));
    }

    @GetMapping("/rewards-penalties")
    @PreAuthorize("hasAuthority('REWARD_VIEW')")
    public ApiResponse<PageResponse<DecisionView>> decisionList(@RequestParam(required = false) String type,
                                                                @RequestParam(required = false) String status,
                                                                @RequestParam(required = false) Long employeeId,
                                                                @PageableDefault(size = 20) Pageable p) {
        return ApiResponse.ok(decisions.list(type, status, employeeId, p));
    }

    @PostMapping("/rewards-penalties/{decisionId}/approve")
    @PreAuthorize("hasAuthority('REWARD_APPROVE')")
    public ApiResponse<DecisionView> approve(@PathVariable String decisionId, @RequestBody(required = false) OptionalNoteRequest r) {
        return ApiResponse.ok("Decision approved", decisions.approve(decisionId, r == null ? null : r.note()));
    }

    @PostMapping("/rewards-penalties/{decisionId}/reject")
    @PreAuthorize("hasAuthority('REWARD_APPROVE')")
    public ApiResponse<DecisionView> reject(@PathVariable String decisionId, @Valid @RequestBody ReasonRequest r) {
        return ApiResponse.ok("Decision rejected", decisions.reject(decisionId, r.reason()));
    }

    @PostMapping("/rewards-penalties/{decisionId}/cancel")
    @PreAuthorize("hasAuthority('REWARD_APPROVE')")
    public ApiResponse<DecisionView> cancel(@PathVariable String decisionId, @Valid @RequestBody ReasonRequest r) {
        return ApiResponse.ok("Decision cancelled", decisions.cancel(decisionId, r.reason()));
    }
}
