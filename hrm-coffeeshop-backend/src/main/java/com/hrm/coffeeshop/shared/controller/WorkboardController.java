package com.hrm.coffeeshop.shared.controller;

import com.hrm.coffeeshop.common.ApiResponse;
import com.hrm.coffeeshop.shared.service.DashboardService;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.util.Map;

@RestController
public class WorkboardController {
    private final DashboardService dashboard;
    private final JdbcTemplate jdbc;
    public WorkboardController(DashboardService dashboard, JdbcTemplate jdbc) { this.dashboard = dashboard; this.jdbc = jdbc; }
    @GetMapping("/dashboard/tasks")
    public ApiResponse<Map<String, Object>> tasks() { return ApiResponse.ok(dashboard.tasks()); }
    @GetMapping("/dashboard/admin/overview")
    @PreAuthorize("hasRole('SYSTEM_ADMIN')")
    public ApiResponse<Map<String, Object>> admin() {
        return ApiResponse.ok(Map.of("totalAccounts", count("SELECT COUNT_BIG(*) FROM dbo.AppUser"),
                "activeAccounts", count("SELECT COUNT_BIG(*) FROM dbo.AppUser WHERE UserStatus='ACTIVE'"),
                "employees", count("SELECT COUNT_BIG(*) FROM dbo.Employee"),
                "courses", count("SELECT COUNT_BIG(*) FROM dbo.TrainingCourse"),
                "checklistTemplates", count("SELECT COUNT_BIG(*) FROM dbo.ChecklistTemplate"),
                "stores", count("SELECT COUNT_BIG(*) FROM dbo.Store")));
    }
    private Long count(String sql) { return jdbc.queryForObject(sql, Long.class); }
}
