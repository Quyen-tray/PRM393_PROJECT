package com.hrm.coffeeshop.shared.controller;

import com.hrm.coffeeshop.shared.dto.EmployeeDto.EmployeeView;
import com.hrm.coffeeshop.shared.dto.EmployeeDto.OverviewView;
import com.hrm.coffeeshop.shared.service.EmployeeService;

import com.hrm.coffeeshop.common.*;
import jakarta.validation.Valid;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/employees")
public class SharedEmployeeController {
    private final EmployeeService svc;

    public SharedEmployeeController(EmployeeService svc) {
        this.svc = svc;
    }

    @GetMapping
    @PreAuthorize("hasAuthority('EMPLOYEE_VIEW')")
    public ApiResponse<PageResponse<EmployeeView>> list(@RequestParam(required = false) String q, @RequestParam(required = false) String status,
                                                        @RequestParam(required = false) String jobTitle,
                                                        @PageableDefault(size = 20, sort = "employeeCode") Pageable p) {
        return ApiResponse.ok(svc.list(q, status, jobTitle, p));
    }

    @GetMapping("/{employeeId}")
    public ApiResponse<EmployeeView> get(@PathVariable Long employeeId) { return ApiResponse.ok(svc.get(employeeId)); }

    @GetMapping("/{employeeId}/training")
    public ApiResponse<List<com.hrm.coffeeshop.shared.dto.TrainingDto.MyTrainingView>> training(@PathVariable Long employeeId) {
        return ApiResponse.ok(svc.trainings(employeeId));
    }

    @GetMapping("/{employeeId}/attendance-summary")
    public ApiResponse<com.hrm.coffeeshop.shared.dto.AttendanceDto.StatsView> attendanceSummary(@PathVariable Long employeeId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return ApiResponse.ok(svc.attendanceSummary(employeeId, from, to));
    }

    @GetMapping("/{employeeId}/overview")
    public ApiResponse<OverviewView> overview(@PathVariable Long employeeId) { return ApiResponse.ok(svc.overview(employeeId)); }
}
