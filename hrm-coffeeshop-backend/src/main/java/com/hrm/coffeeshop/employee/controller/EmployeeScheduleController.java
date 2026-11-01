package com.hrm.coffeeshop.employee.controller;

import com.hrm.coffeeshop.shared.dto.ScheduleDto.AssignmentView;
import com.hrm.coffeeshop.shared.service.ShiftService;

import com.hrm.coffeeshop.common.*;
import jakarta.validation.Valid;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.time.LocalDate;
import java.util.List;

@RestController
public class EmployeeScheduleController {
    private final ShiftService svc;

    public EmployeeScheduleController(ShiftService svc) {
        this.svc = svc;
    }

    @GetMapping("/shift-assignments/me")
    public ApiResponse<List<AssignmentView>> mine(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return ApiResponse.ok(svc.mine(from, to));
    }
}
