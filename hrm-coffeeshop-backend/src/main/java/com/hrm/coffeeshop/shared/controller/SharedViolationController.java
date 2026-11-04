package com.hrm.coffeeshop.shared.controller;

import com.hrm.coffeeshop.shared.dto.ViolationDto.ViolationView;
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
public class SharedViolationController {
    private final ViolationService violations;

    public SharedViolationController(ViolationService violations) {
        this.violations = violations;
    }

    @GetMapping("/violations/{violationId}")
    public ApiResponse<ViolationView> get(@PathVariable Long violationId) { return ApiResponse.ok(violations.get(violationId)); }
}
