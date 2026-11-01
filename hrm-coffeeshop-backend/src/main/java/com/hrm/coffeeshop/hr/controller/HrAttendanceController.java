package com.hrm.coffeeshop.hr.controller;

import com.hrm.coffeeshop.shared.dto.AttendanceDto.AdjustmentView;
import com.hrm.coffeeshop.shared.dto.MiscDto.OptionalNoteRequest;
import com.hrm.coffeeshop.shared.dto.MiscDto.ReasonRequest;
import com.hrm.coffeeshop.shared.service.AttendanceAdjustmentService;

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
public class HrAttendanceController {
    private final AttendanceAdjustmentService adjustments;

    public HrAttendanceController(AttendanceAdjustmentService adjustments) {
        this.adjustments = adjustments;
    }

    @PostMapping("/adjustment-requests/{requestId}/hr-approve")
    @PreAuthorize("hasAuthority('ATTENDANCE_ADJUST_HR')")
    public ApiResponse<AdjustmentView> hrApprove(@PathVariable Long requestId, @RequestBody(required = false) OptionalNoteRequest r) {
        return ApiResponse.ok("Approved by HR", adjustments.hrApprove(requestId, r == null ? null : r.note()));
    }

    @PostMapping("/adjustment-requests/{requestId}/hr-reject")
    @PreAuthorize("hasAuthority('ATTENDANCE_ADJUST_HR')")
    public ApiResponse<AdjustmentView> hrReject(@PathVariable Long requestId, @Valid @RequestBody ReasonRequest r) {
        return ApiResponse.ok("Rejected by HR", adjustments.hrReject(requestId, r.reason()));
    }
}
