package com.hrm.coffeeshop.manager.controller;

import com.hrm.coffeeshop.shared.dto.TrainingDto.AttemptRequest;
import com.hrm.coffeeshop.shared.dto.TrainingDto.MyTrainingView;
import com.hrm.coffeeshop.shared.dto.TrainingDto.ProgressView;
import com.hrm.coffeeshop.shared.service.TrainingService;

import com.hrm.coffeeshop.common.*;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
public class ManagerTrainingController {
    private final TrainingService svc;

    public ManagerTrainingController(TrainingService svc) {
        this.svc = svc;
    }

    @PostMapping("/training/courses/{courseId}/attempts")
    @PreAuthorize("hasAuthority('TRAINING_MANAGE')")
    public ApiResponse<MyTrainingView> attempt(@PathVariable Integer courseId, @Valid @RequestBody AttemptRequest r) {
        return ApiResponse.ok("Attempt recorded", svc.recordAttempt(courseId, r));
    }

    @GetMapping("/training/employees/{employeeId}/progress")
    @PreAuthorize("hasAuthority('TRAINING_MANAGE')")
    public ApiResponse<ProgressView> progress(@PathVariable Long employeeId) {
        return ApiResponse.ok("Training progress retrieved", svc.progress(employeeId));
    }
}
