package com.hrm.coffeeshop.shared.controller;

import com.hrm.coffeeshop.shared.dto.ScheduleDto.AssignmentView;
import com.hrm.coffeeshop.shared.dto.ScheduleDto.EligibilityView;
import com.hrm.coffeeshop.shared.dto.ScheduleDto.ShiftView;
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
public class SharedScheduleController {
    private final ShiftService svc;

    public SharedScheduleController(ShiftService svc) {
        this.svc = svc;
    }

    @GetMapping("/work-shifts")
    public ApiResponse<List<ShiftView>> shifts() {
        return ApiResponse.ok(svc.listShifts(!SecurityUtils.current().hasAny(Roles.SYSTEM_ADMIN, Roles.STORE_MANAGER)));
    }

    @GetMapping("/shift-assignments/{assignmentId}")
    public ApiResponse<AssignmentView> get(@PathVariable Long assignmentId) { return ApiResponse.ok(svc.get(assignmentId)); }

    @GetMapping("/shift-assignments/{assignmentId}/eligibility")
    public ApiResponse<EligibilityView> eligibility(@PathVariable Long assignmentId) {
        return ApiResponse.ok(svc.eligibility(assignmentId));
    }
}
