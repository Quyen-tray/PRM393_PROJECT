package com.hrm.coffeeshop.shared.controller;

import com.hrm.coffeeshop.shared.dto.PayrollDto.PeriodView;
import com.hrm.coffeeshop.shared.dto.PayrollDto.ReadinessView;
import com.hrm.coffeeshop.shared.service.PayrollService;

import com.hrm.coffeeshop.common.ApiResponse;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping({"/payroll-periods", "/payroll/periods"})   // /payroll/periods: đường dẫn cũ, giữ tạm cho app cũ
@PreAuthorize("hasAuthority('PAYROLL_VIEW')")
public class SharedPayrollController {
    private final PayrollService svc;

    public SharedPayrollController(PayrollService svc) {
        this.svc = svc;
    }

    @GetMapping
    public ApiResponse<List<PeriodView>> list() { return ApiResponse.ok(svc.list()); }

    @GetMapping("/{periodId}/readiness")
    public ApiResponse<ReadinessView> readiness(@PathVariable Long periodId) { return ApiResponse.ok(svc.readiness(periodId)); }
}
