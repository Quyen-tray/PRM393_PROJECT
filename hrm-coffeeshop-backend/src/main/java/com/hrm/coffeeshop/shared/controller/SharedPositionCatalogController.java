package com.hrm.coffeeshop.shared.controller;
import com.hrm.coffeeshop.common.ApiResponse;
import com.hrm.coffeeshop.shared.dto.JobPositionDto.PositionView;
import com.hrm.coffeeshop.shared.service.JobPositionService;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.util.List;
@RestController
public class SharedPositionCatalogController {
    private final JobPositionService positions;
    public SharedPositionCatalogController(JobPositionService positions) { this.positions=positions; }
    @GetMapping("/job-positions")
    @PreAuthorize("hasAnyAuthority('EMPLOYEE_VIEW','EMPLOYEE_MANAGE')")
    public ApiResponse<List<PositionView>> positions() { return ApiResponse.ok(positions.list(false)); }
}
