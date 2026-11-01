package com.hrm.coffeeshop.shared.controller;

import com.hrm.coffeeshop.shared.dto.TrainingDto.CourseView;
import com.hrm.coffeeshop.shared.service.TrainingService;

import com.hrm.coffeeshop.common.*;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
public class SharedTrainingController {
    private final TrainingService svc;

    public SharedTrainingController(TrainingService svc) {
        this.svc = svc;
    }

    @GetMapping("/training/courses")
    public ApiResponse<List<CourseView>> courses() {
        return ApiResponse.ok(svc.listCourses(SecurityUtils.current().hasRole(Roles.SYSTEM_ADMIN)));
    }
}
