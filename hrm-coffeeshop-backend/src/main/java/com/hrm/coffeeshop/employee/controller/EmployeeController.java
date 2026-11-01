package com.hrm.coffeeshop.employee.controller;

import com.hrm.coffeeshop.shared.dto.EmployeeDto.EmployeeView;
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
public class EmployeeController {
    private final EmployeeService svc;

    public EmployeeController(EmployeeService svc) {
        this.svc = svc;
    }

    @GetMapping("/me")
    public ApiResponse<EmployeeView> me() { return ApiResponse.ok(svc.me()); }
}
