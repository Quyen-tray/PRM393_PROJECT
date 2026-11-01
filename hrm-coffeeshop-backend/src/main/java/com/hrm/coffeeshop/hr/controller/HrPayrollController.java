package com.hrm.coffeeshop.hr.controller;

import com.hrm.coffeeshop.shared.dto.MiscDto.ReasonRequest;
import com.hrm.coffeeshop.shared.dto.PayrollDto.PeriodRequest;
import com.hrm.coffeeshop.shared.dto.PayrollDto.PeriodView;
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
public class HrPayrollController {
    private final PayrollService svc;

    public HrPayrollController(PayrollService svc) {
        this.svc = svc;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<PeriodView> create(@Valid @RequestBody PeriodRequest r) { return ApiResponse.ok("Period created", svc.create(r)); }

    /** SRS 9.13: mở lại kỳ công là quy trình đặc biệt, chỉ HR cấp cao/Admin có PAYROLL_REOPEN; service cũng kiểm tra và ghi audit. */
    @PostMapping("/{periodId}/reopen")
    @PreAuthorize("hasAuthority('PAYROLL_REOPEN')")
    public ApiResponse<PeriodView> reopen(@PathVariable Long periodId, @Valid @RequestBody ReasonRequest r) {
        return ApiResponse.ok("Period reopened", svc.reopen(periodId, r.reason()));
    }

    @PostMapping("/{periodId}/hr-finalize")
    public ApiResponse<PeriodView> finalizePeriod(@PathVariable Long periodId) {
        return ApiResponse.ok("Period finalized", svc.hrFinalize(periodId));
    }
}
