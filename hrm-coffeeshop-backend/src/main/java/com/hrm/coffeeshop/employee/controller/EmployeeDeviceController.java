package com.hrm.coffeeshop.employee.controller;

import com.hrm.coffeeshop.shared.dto.DeviceDto.DeviceView;
import com.hrm.coffeeshop.shared.dto.DeviceDto.RegisterRequest;
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
public class EmployeeDeviceController {
    private final DeviceService svc;

    public EmployeeDeviceController(DeviceService svc) {
        this.svc = svc;
    }

    @PostMapping("/register")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<DeviceView> register(@Valid @RequestBody RegisterRequest r) {
        return ApiResponse.ok("Device registration submitted", svc.register(r));
    }

    @GetMapping("/me")
    public ApiResponse<List<DeviceView>> mine() { return ApiResponse.ok(svc.mine()); }

    @GetMapping("/current")
    public ApiResponse<DeviceView> current(@RequestHeader(value = "X-Device-Credential", required = false) String credential) {
        return ApiResponse.ok(svc.current(credential));
    }

    @GetMapping("/{deviceId}")
    public ApiResponse<DeviceView> get(@PathVariable Long deviceId) { return ApiResponse.ok(svc.get(deviceId)); }
}
