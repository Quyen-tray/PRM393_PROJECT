package com.hrm.coffeeshop.employee.controller;

import com.hrm.coffeeshop.shared.dto.AttendanceDto.AdjustmentRequest;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.AdjustmentView;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.AttendanceView;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.CheckInRequest;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.CheckInResponse;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.CheckOutRequest;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.CheckOutResponse;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.CurrentShiftView;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.ExceptionView;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.ExplanationRequest;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.OvertimeRequestDto;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.OvertimeView;
import com.hrm.coffeeshop.shared.service.AttendanceAdjustmentService;
import com.hrm.coffeeshop.shared.service.AttendanceExceptionService;
import com.hrm.coffeeshop.shared.service.AttendanceService;
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
public class EmployeeAttendanceController {
    private final AttendanceService svc;
    private final AttendanceExceptionService exceptions;
    private final OvertimeService overtime;
    private final AttendanceAdjustmentService adjustments;
    private final com.hrm.coffeeshop.shared.service.DeviceService devices;

    public EmployeeAttendanceController(AttendanceService svc, AttendanceExceptionService exceptions, OvertimeService overtime, AttendanceAdjustmentService adjustments, com.hrm.coffeeshop.shared.service.DeviceService devices) {
        this.svc = svc;
        this.exceptions = exceptions;
        this.overtime = overtime;
        this.adjustments = adjustments;
        this.devices = devices;
    }

    @PostMapping("/check-in")
    public ApiResponse<CheckInResponse> checkIn(@RequestHeader(value = "Idempotency-Key", required = false) String idemHeader,
                                                @RequestHeader(value = "X-Device-Credential", required = false) String credential,
                                                @Valid @RequestBody CheckInRequest r) {
        devices.requireInstallation(r.deviceId(), credential);
        String key = resolveKey(r.idempotencyKey(), idemHeader);
        return ApiResponse.ok("Check-in successful", svc.checkIn(new CheckInRequest(r.shiftAssignmentId(), r.deviceId(),
                r.location(), r.photoEvidence(), r.faceVerification(), key)));
    }

    @PostMapping("/check-out")
    public ApiResponse<CheckOutResponse> checkOut(@RequestHeader(value = "Idempotency-Key", required = false) String idemHeader,
                                                  @RequestHeader(value = "X-Device-Credential", required = false) String credential,
                                                  @Valid @RequestBody CheckOutRequest r) {
        devices.requireInstallation(r.deviceId(), credential);
        String key = resolveKey(r.idempotencyKey(), idemHeader);
        return ApiResponse.ok("Check-out successful", svc.checkOut(new CheckOutRequest(r.attendanceId(), r.deviceId(),
                r.location(), r.photoEvidence(), r.faceVerification(), key)));
    }

    /** SRS 8.1: khóa idempotency lấy từ header Idempotency-Key, hoặc từ body idempotencyKey. */
    private static String resolveKey(String body, String header) {
        String key = header != null && !header.isBlank() ? header.trim() : body;
        if (key != null && key.length() > 100)
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Idempotency-Key tối đa 100 ký tự");
        return key;
    }

    @GetMapping("/me/current")
    public ApiResponse<CurrentShiftView> current(@RequestHeader(value = "X-Device-Credential", required = false) String credential,
                                                @RequestParam(required = false) Long assignmentId) {
        return ApiResponse.ok(svc.current(credential, assignmentId));
    }

    @GetMapping("/me")
    public ApiResponse<PageResponse<AttendanceView>> mine(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @PageableDefault(size = 31, sort = "attendanceId", direction = Sort.Direction.DESC) Pageable p) {
        return ApiResponse.ok(svc.mine(from, to, p));
    }

    @PostMapping("/{attendanceId}/explanation-requests")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<ExceptionView> explain(@PathVariable Long attendanceId, @Valid @RequestBody ExplanationRequest r) {
        return ApiResponse.ok("Explanation submitted", exceptions.create(attendanceId, r));
    }

    /** Dùng khi CHƯA có bản ghi công (vd: GPS không khả dụng nên không check-in được): truyền scheduleId. */
    @PostMapping("/explanation-requests")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<ExceptionView> explainForShift(@Valid @RequestBody ExplanationRequest r) {
        return ApiResponse.ok("Explanation submitted", exceptions.create(null, r));
    }

    @GetMapping("/explanation-requests/me")
    public ApiResponse<List<ExceptionView>> myExplanations() { return ApiResponse.ok(exceptions.mine()); }

    @PostMapping("/{attendanceId}/overtime-requests")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<OvertimeView> requestOt(@PathVariable Long attendanceId, @Valid @RequestBody OvertimeRequestDto r) {
        return ApiResponse.ok("Overtime requested", overtime.create(attendanceId, r));
    }

    @GetMapping("/overtime-requests/me")
    public ApiResponse<List<OvertimeView>> myOvertime() { return ApiResponse.ok(overtime.mine()); }

    @GetMapping("/explanation-requests/{requestId}")
    public ApiResponse<ExceptionView> explanation(@PathVariable Long requestId) { return ApiResponse.ok(exceptions.get(requestId)); }

    @GetMapping("/overtime-requests/{requestId}")
    public ApiResponse<OvertimeView> overtime(@PathVariable Long requestId) { return ApiResponse.ok(overtime.get(requestId)); }

    @PostMapping("/adjustment-requests")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<List<AdjustmentView>> requestAdjustment(@Valid @RequestBody AdjustmentRequest r) {
        return ApiResponse.ok("Adjustment requested", adjustments.create(r));
    }

    @GetMapping("/adjustment-requests/me")
    public ApiResponse<PageResponse<AdjustmentView>> myAdjustments(@PageableDefault(size = 20, sort = "createdAt", direction = Sort.Direction.DESC) Pageable p) {
        return ApiResponse.ok(adjustments.mine(p));
    }
}
