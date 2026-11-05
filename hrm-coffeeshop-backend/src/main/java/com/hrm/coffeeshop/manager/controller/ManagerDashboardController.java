package com.hrm.coffeeshop.manager.controller;

import com.hrm.coffeeshop.shared.dto.AttendanceDto.StatsView;
import com.hrm.coffeeshop.shared.service.DashboardService;
import com.hrm.coffeeshop.shared.service.PayrollService;

import com.hrm.coffeeshop.common.ApiResponse;
import com.hrm.coffeeshop.common.TimeUtils;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.time.Clock;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;

@RestController
public class ManagerDashboardController {
    private final DashboardService svc;
    private final PayrollService payroll;
    private final Clock clock;

    public ManagerDashboardController(DashboardService svc, PayrollService payroll, Clock clock) {
        this.svc = svc;
        this.payroll = payroll;
        this.clock = clock;
    }

    private LocalDate f(LocalDate from) { return from != null ? from : TimeUtils.today(clock).withDayOfMonth(1); }

    private LocalDate t(LocalDate from, LocalDate to) { return to != null ? to : f(from).plusMonths(1).minusDays(1); }

    @GetMapping("/dashboard/manager/overview")
    @PreAuthorize("hasAuthority('DASHBOARD_MANAGER')")
    public ApiResponse<Map<String, Object>> overview() { return ApiResponse.ok(svc.managerOverview()); }

    @GetMapping("/dashboard/manager/attendance")
    @PreAuthorize("hasAuthority('DASHBOARD_MANAGER')")
    public ApiResponse<StatsView> attendance(@RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
                                             @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
                                             @RequestParam(required = false) Integer shiftId) {
        LocalDate d = from != null ? from : TimeUtils.today(clock);
        return ApiResponse.ok(svc.attendance(d, to != null ? to : d, shiftId));
    }

    @GetMapping("/dashboard/manager/employee-status")
    @PreAuthorize("hasAuthority('DASHBOARD_MANAGER')")
    public ApiResponse<Map<String, Object>> employeeStatus() { return ApiResponse.ok(svc.employeeStatus()); }

    @GetMapping("/dashboard/manager/operations")
    @PreAuthorize("hasAuthority('DASHBOARD_MANAGER')")
    public ApiResponse<Map<String, Object>> operations(@RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
                                                       @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return ApiResponse.ok(svc.operations(f(from), t(from, to)));
    }

    @GetMapping("/dashboard/manager/rewards-penalties")
    @PreAuthorize("hasAuthority('REWARD_VIEW')")
    public ApiResponse<Map<String, Object>> rewards(@RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
                                                    @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return ApiResponse.ok(svc.rewardsPenalties(f(from), t(from, to)));
    }

    @GetMapping("/reports/attendance")
    @PreAuthorize("hasAuthority('DASHBOARD_MANAGER')")
    public ApiResponse<List<Map<String, Object>>> attendanceReport(@RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
                                                                   @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return ApiResponse.ok(svc.attendanceReport(f(from), t(from, to)));
    }

    @GetMapping("/reports/payroll-readiness")
    @PreAuthorize("hasAuthority('DASHBOARD_MANAGER')")
    public ApiResponse<?> payrollReadiness(@RequestParam Long periodId) { return ApiResponse.ok(payroll.readiness(periodId)); }

    @GetMapping("/reports/operations")
    @PreAuthorize("hasAuthority('DASHBOARD_MANAGER')")
    public ApiResponse<Map<String, Object>> operationsReport(@RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
                                                             @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return ApiResponse.ok(svc.operations(f(from), t(from, to)));
    }
}
