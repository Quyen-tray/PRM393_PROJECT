package com.hrm.coffeeshop.employee.controller;

import com.hrm.coffeeshop.shared.service.DashboardService;

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
public class EmployeeDashboardController {
    private final DashboardService svc;

    public EmployeeDashboardController(DashboardService svc) {
        this.svc = svc;
    }

    @GetMapping("/dashboard/employee/overview")
    public ApiResponse<Map<String, Object>> employeeOverview() { return ApiResponse.ok(svc.employeeOverview()); }
}
