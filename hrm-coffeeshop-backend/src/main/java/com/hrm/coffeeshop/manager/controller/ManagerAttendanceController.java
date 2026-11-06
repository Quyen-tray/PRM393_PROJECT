package com.hrm.coffeeshop.manager.controller;

import com.hrm.coffeeshop.shared.dto.AttendanceDto.AdjustmentView;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.AttendanceView;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.ExceptionView;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.OvertimeView;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.StatsView;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.SpotCheckView;
import com.hrm.coffeeshop.shared.dto.MiscDto.OptionalNoteRequest;
import com.hrm.coffeeshop.shared.dto.MiscDto.ReasonRequest;
import com.hrm.coffeeshop.shared.service.AttendanceAdjustmentService;
import com.hrm.coffeeshop.shared.service.AttendanceExceptionService;
import com.hrm.coffeeshop.shared.service.AttendanceService;
import com.hrm.coffeeshop.shared.service.AttendanceStatsService;
import com.hrm.coffeeshop.shared.service.AttendanceSpotCheckService;
import com.hrm.coffeeshop.shared.service.OvertimeService;

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
public class ManagerAttendanceController {
    private final AttendanceService svc;
    private final AttendanceExceptionService exceptions;
    private final OvertimeService overtime;
    private final AttendanceAdjustmentService adjustments;
    private final AttendanceStatsService stats;
    private final AttendanceSpotCheckService spotChecks;
    private final Clock clock;

    public ManagerAttendanceController(AttendanceService svc, AttendanceExceptionService exceptions, OvertimeService overtime,
                                       AttendanceAdjustmentService adjustments, AttendanceStatsService stats,
                                       AttendanceSpotCheckService spotChecks, Clock clock) {
        this.svc = svc;
        this.exceptions = exceptions;
        this.overtime = overtime;
        this.adjustments = adjustments;
        this.stats = stats;
        this.spotChecks = spotChecks;
        this.clock = clock;
    }

    @GetMapping
    @PreAuthorize("hasAuthority('ATTENDANCE_VIEW_ALL')")
    public ApiResponse<PageResponse<AttendanceView>> search(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) Long employeeId, @RequestParam(required = false) String status,
            @PageableDefault(size = 50, sort = "attendanceId", direction = Sort.Direction.DESC) Pageable p) {
        return ApiResponse.ok(svc.search(from, to, employeeId, status, p));
    }

    @PostMapping("/{attendanceId}/spot-check")
    @PreAuthorize("hasAuthority('ATTENDANCE_REVIEW')")
    public ApiResponse<SpotCheckView> requestSpotCheck(@PathVariable Long attendanceId) {
        return ApiResponse.ok("Mid-shift attendance check requested", spotChecks.requestNow(attendanceId));
    }

    @GetMapping("/summary")
    @PreAuthorize("hasAuthority('ATTENDANCE_VIEW_ALL')")
    public ApiResponse<StatsView> summary(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) Integer shiftId, @RequestParam(required = false) Long employeeId) {
        LocalDate f = from != null ? from : TimeUtils.today(clock), t = to != null ? to : f;
        return ApiResponse.ok(stats.stats(f, t, shiftId, employeeId));
    }

    @GetMapping("/explanation-requests")
    @PreAuthorize("hasRole('STORE_MANAGER')")
    public ApiResponse<PageResponse<ExceptionView>> explanations(@RequestParam(required = false) String status,
                                                                 @PageableDefault(size = 20) Pageable p) {
        return ApiResponse.ok(exceptions.list(status, p));
    }

    @PostMapping("/explanation-requests/{requestId}/approve")
    @PreAuthorize("hasRole('STORE_MANAGER')")
    public ApiResponse<ExceptionView> approveExplanation(@PathVariable Long requestId, @RequestBody(required = false) OptionalNoteRequest r) {
        return ApiResponse.ok("Explanation approved", exceptions.approve(requestId, r == null ? null : r.note()));
    }

    @PostMapping("/explanation-requests/{requestId}/reject")
    @PreAuthorize("hasRole('STORE_MANAGER')")
    public ApiResponse<ExceptionView> rejectExplanation(@PathVariable Long requestId, @Valid @RequestBody ReasonRequest r) {
        return ApiResponse.ok("Explanation rejected", exceptions.reject(requestId, r.reason()));
    }

    @GetMapping("/overtime-requests")
    @PreAuthorize("hasRole('STORE_MANAGER')")
    public ApiResponse<PageResponse<OvertimeView>> otList(@RequestParam(required = false) String status,
                                                          @PageableDefault(size = 20) Pageable p) {
        return ApiResponse.ok(overtime.list(status, p));
    }

    @PostMapping("/overtime-requests/{requestId}/approve")
    @PreAuthorize("hasRole('STORE_MANAGER')")
    public ApiResponse<OvertimeView> approveOt(@PathVariable Long requestId, @RequestBody(required = false) OptionalNoteRequest r) {
        return ApiResponse.ok("Overtime approved", overtime.approve(requestId, r == null ? null : r.note()));
    }

    @PostMapping("/overtime-requests/{requestId}/reject")
    @PreAuthorize("hasRole('STORE_MANAGER')")
    public ApiResponse<OvertimeView> rejectOt(@PathVariable Long requestId, @Valid @RequestBody ReasonRequest r) {
        return ApiResponse.ok("Overtime rejected", overtime.reject(requestId, r.reason()));
    }

    @PostMapping("/adjustment-requests/{requestId}/manager-approve")
    @PreAuthorize("hasRole('STORE_MANAGER')")
    public ApiResponse<AdjustmentView> managerApprove(@PathVariable Long requestId, @RequestBody(required = false) OptionalNoteRequest r) {
        return ApiResponse.ok("Approved by manager", adjustments.managerApprove(requestId, r == null ? null : r.note()));
    }

    @PostMapping("/adjustment-requests/{requestId}/manager-reject")
    @PreAuthorize("hasRole('STORE_MANAGER')")
    public ApiResponse<AdjustmentView> managerReject(@PathVariable Long requestId, @Valid @RequestBody ReasonRequest r) {
        return ApiResponse.ok("Rejected by manager", adjustments.managerReject(requestId, r.reason()));
    }
}
