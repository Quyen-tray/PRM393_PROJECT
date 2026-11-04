package com.hrm.coffeeshop.manager.controller;

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
public class ManagerPayrollController {
    private final PayrollService svc;

    public ManagerPayrollController(PayrollService svc) {
        this.svc = svc;
    }

    @PostMapping("/{periodId}/manager-confirm")
    public ApiResponse<PeriodView> managerConfirm(@PathVariable Long periodId) {
        return ApiResponse.ok("Confirmed by manager", svc.managerConfirm(periodId));
    }

    /** DEC-ABS: hệ thống tạo đơn ABSENCE chờ duyệt cho các ca đã kết thúc không có chấm công. Idempotent. */
    @PostMapping("/{periodId}/absence-requests")
    @PreAuthorize("hasRole('STORE_MANAGER')")
    public ApiResponse<java.util.Map<String, Object>> generateAbsence(@PathVariable Long periodId) {
        return ApiResponse.ok("Absence requests generated", svc.generateAbsenceRequests(periodId));
    }
}
