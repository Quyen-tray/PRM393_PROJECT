package com.hrm.coffeeshop.employee.controller;

import com.hrm.coffeeshop.shared.dto.TrainingDto.EnrollRequest;
import com.hrm.coffeeshop.shared.dto.TrainingDto.MyTrainingView;
import com.hrm.coffeeshop.shared.dto.TrainingDto.RequirementView;
import com.hrm.coffeeshop.shared.service.TrainingService;

import com.hrm.coffeeshop.common.*;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
public class EmployeeTrainingController {
    private final TrainingService svc;

    public EmployeeTrainingController(TrainingService svc) {
        this.svc = svc;
    }

    @GetMapping("/training/me")
    public ApiResponse<List<MyTrainingView>> mine() { return ApiResponse.ok(svc.mine(SecurityUtils.requireEmployeeId())); }

    @GetMapping("/training/me/requirements")
    public ApiResponse<List<RequirementView>> requirements() {
        return ApiResponse.ok(svc.myRequirements(SecurityUtils.requireEmployeeId()));
    }

    @PostMapping("/training/courses/{courseId}/enroll")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<MyTrainingView> enroll(@PathVariable Integer courseId, @RequestBody(required = false) EnrollRequest r) {
        return ApiResponse.ok("Enrolled", svc.enroll(courseId, r));
    }

}
