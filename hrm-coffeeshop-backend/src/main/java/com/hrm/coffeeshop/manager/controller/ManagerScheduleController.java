package com.hrm.coffeeshop.manager.controller;

import com.hrm.coffeeshop.shared.dto.MiscDto.OptionalNoteRequest;
import com.hrm.coffeeshop.shared.dto.ScheduleDto.AssignmentPatch;
import com.hrm.coffeeshop.shared.dto.ScheduleDto.AssignmentRequest;
import com.hrm.coffeeshop.shared.dto.ScheduleDto.AssignmentView;
import com.hrm.coffeeshop.shared.dto.ScheduleDto.ShiftRequest;
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
public class ManagerScheduleController {
    private final ShiftService svc;

    public ManagerScheduleController(ShiftService svc) {
        this.svc = svc;
    }

    @PostMapping("/work-shifts")
    @PreAuthorize("hasAnyRole('SYSTEM_ADMIN','STORE_MANAGER')")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<ShiftView> create(@Valid @RequestBody ShiftRequest r) {
        return ApiResponse.ok("Shift created", svc.createShift(r));
    }

    @PutMapping("/work-shifts/{shiftId}")
    @PreAuthorize("hasAnyRole('SYSTEM_ADMIN','STORE_MANAGER')")
    public ApiResponse<ShiftView> update(@PathVariable Integer shiftId, @Valid @RequestBody ShiftRequest r) {
        return ApiResponse.ok("Shift updated", svc.updateShift(shiftId, r));
    }

    @GetMapping("/shift-assignments")
    @PreAuthorize("hasRole('STORE_MANAGER')")
    public ApiResponse<PageResponse<AssignmentView>> list(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) Long employeeId,
            @PageableDefault(size = 50, sort = "plannedStartAt", direction = org.springframework.data.domain.Sort.Direction.DESC) Pageable p) {
        return ApiResponse.ok(svc.search(from, to, employeeId, p));
    }

    @PostMapping("/shift-assignments")
    @PreAuthorize("hasRole('STORE_MANAGER')")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<AssignmentView> assign(@Valid @RequestBody AssignmentRequest r) {
        return ApiResponse.ok("Shift assigned", svc.create(r));
    }

    @PatchMapping("/shift-assignments/{assignmentId}")
    @PreAuthorize("hasRole('STORE_MANAGER')")
    public ApiResponse<AssignmentView> patch(@PathVariable Long assignmentId, @Valid @RequestBody AssignmentPatch p) {
        return ApiResponse.ok("Assignment updated", svc.patch(assignmentId, p));
    }

    @PostMapping("/shift-assignments/{assignmentId}/cancel")
    @PreAuthorize("hasRole('STORE_MANAGER')")
    public ApiResponse<AssignmentView> cancel(@PathVariable Long assignmentId, @RequestBody(required = false) OptionalNoteRequest r) {
        return ApiResponse.ok("Assignment cancelled", svc.cancel(assignmentId, r == null ? null : r.note()));
    }
}
