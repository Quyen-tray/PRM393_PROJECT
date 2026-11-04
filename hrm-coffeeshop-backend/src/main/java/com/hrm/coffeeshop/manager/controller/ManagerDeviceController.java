package com.hrm.coffeeshop.manager.controller;

import com.hrm.coffeeshop.shared.dto.DeviceDto.DeviceView;
import com.hrm.coffeeshop.shared.dto.MiscDto.ReasonRequest;
import com.hrm.coffeeshop.shared.service.DeviceService;

import com.hrm.coffeeshop.common.*;
import jakarta.validation.Valid;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping("/attendance/devices")
public class ManagerDeviceController {
    private final DeviceService svc;

    public ManagerDeviceController(DeviceService svc) {
        this.svc = svc;
    }

    @GetMapping
    @PreAuthorize("hasAuthority('DEVICE_APPROVE')")
    public ApiResponse<PageResponse<DeviceView>> list(@RequestParam(required = false) String status,
            @RequestParam(required = false) Long employeeId, @RequestParam(required = false) String q,
            @PageableDefault(size = 20, sort = "requestedAt", direction = org.springframework.data.domain.Sort.Direction.DESC) Pageable p) {
        return ApiResponse.ok(svc.list(status, employeeId, q, p));
    }

    @GetMapping("/employees/{employeeId}")
    @PreAuthorize("hasAuthority('DEVICE_APPROVE')")
    public ApiResponse<List<DeviceView>> forEmployee(@PathVariable Long employeeId) { return ApiResponse.ok(svc.forEmployee(employeeId)); }

    @GetMapping("/pending")
    @PreAuthorize("hasAuthority('DEVICE_APPROVE')")
    public ApiResponse<PageResponse<DeviceView>> pending(@PageableDefault(size = 20) Pageable p) {
        return ApiResponse.ok(svc.pending(p));
    }

    @PostMapping("/{deviceId}/approve")
    @PreAuthorize("hasAuthority('DEVICE_APPROVE')")
    public ApiResponse<DeviceView> approve(@PathVariable Long deviceId) {
        return ApiResponse.ok("Device approved", svc.approve(deviceId));
    }

    @PostMapping("/{deviceId}/reject")
    @PreAuthorize("hasAuthority('DEVICE_APPROVE')")
    public ApiResponse<DeviceView> reject(@PathVariable Long deviceId, @Valid @RequestBody ReasonRequest r) {
        return ApiResponse.ok("Device rejected", svc.reject(deviceId, r.reason()));
    }

    @PostMapping("/{deviceId}/revoke")
    @PreAuthorize("hasAuthority('DEVICE_APPROVE')")
    public ApiResponse<DeviceView> revoke(@PathVariable Long deviceId, @Valid @RequestBody ReasonRequest r) {
        return ApiResponse.ok("Device revoked", svc.revoke(deviceId, r.reason()));
    }
}
