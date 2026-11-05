package com.hrm.coffeeshop.shared.controller;

import com.hrm.coffeeshop.shared.dto.AttendanceDto.AdjustmentView;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.AttendanceView;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.VerificationView;
import com.hrm.coffeeshop.shared.service.AttendanceAdjustmentService;
import com.hrm.coffeeshop.shared.service.AttendanceService;

import com.hrm.coffeeshop.common.*;
import jakarta.validation.Valid;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.time.Clock;
import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/attendance")
public class SharedAttendanceController {
    private final AttendanceService svc;
    private final AttendanceAdjustmentService adjustments;

    public SharedAttendanceController(AttendanceService svc, AttendanceAdjustmentService adjustments) {
        this.svc = svc;
        this.adjustments = adjustments;
    }

    @GetMapping("/{attendanceId}")
    public ApiResponse<AttendanceView> get(@PathVariable Long attendanceId) { return ApiResponse.ok(svc.get(attendanceId)); }

    @GetMapping("/{attendanceId}/verifications")
    public ApiResponse<List<VerificationView>> verifications(@PathVariable Long attendanceId) {
        return ApiResponse.ok(svc.verifications(attendanceId));
    }

    @GetMapping("/adjustment-requests")
    @PreAuthorize("hasAnyAuthority('ATTENDANCE_VIEW_ALL','ATTENDANCE_ADJUST_HR') or hasRole('STORE_MANAGER')")
    public ApiResponse<PageResponse<AdjustmentView>> adjustmentList(@RequestParam(required = false) String status,
                                                                    @PageableDefault(size = 20, sort = "createdAt", direction = Sort.Direction.DESC) Pageable p) {
        return ApiResponse.ok(adjustments.list(status, p));
    }

    @GetMapping("/adjustment-requests/{requestId}")
    public ApiResponse<AdjustmentView> adjustment(@PathVariable Long requestId) { return ApiResponse.ok(adjustments.get(requestId)); }
}
