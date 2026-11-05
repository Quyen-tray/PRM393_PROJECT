package com.hrm.coffeeshop.hr.controller;

import com.hrm.coffeeshop.shared.dto.EmployeeDto.CreateRequest;
import com.hrm.coffeeshop.shared.dto.EmployeeDto.EmployeeView;
import com.hrm.coffeeshop.shared.dto.EmployeeDto.StatusRequest;
import com.hrm.coffeeshop.shared.dto.EmployeeDto.UpdateRequest;
import com.hrm.coffeeshop.shared.service.EmployeeService;

import com.hrm.coffeeshop.common.*;
import jakarta.validation.Valid;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/employees")
public class HrEmployeeController {
    private final EmployeeService svc;

    public HrEmployeeController(EmployeeService svc) {
        this.svc = svc;
    }

    @PostMapping
    @PreAuthorize("hasAuthority('EMPLOYEE_MANAGE')")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<EmployeeView> create(@Valid @RequestBody CreateRequest r) { return ApiResponse.ok("Employee created", svc.create(r)); }

    @PatchMapping("/{employeeId}")
    @PreAuthorize("hasAuthority('EMPLOYEE_MANAGE')")
    public ApiResponse<EmployeeView> update(@PathVariable Long employeeId, @Valid @RequestBody UpdateRequest r) {
        return ApiResponse.ok("Employee updated", svc.update(employeeId, r));
    }

    @PatchMapping("/{employeeId}/status")
    @PreAuthorize("hasAuthority('EMPLOYEE_MANAGE')")
    public ApiResponse<EmployeeView> status(@PathVariable Long employeeId, @Valid @RequestBody StatusRequest r) {
        return ApiResponse.ok("Status updated", svc.setStatus(employeeId, r));
    }
}
