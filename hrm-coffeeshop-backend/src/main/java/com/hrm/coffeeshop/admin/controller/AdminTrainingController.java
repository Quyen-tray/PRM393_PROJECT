package com.hrm.coffeeshop.admin.controller;

import com.hrm.coffeeshop.shared.dto.TrainingDto.CourseRequest;
import com.hrm.coffeeshop.shared.dto.TrainingDto.CourseView;
import com.hrm.coffeeshop.shared.service.TrainingService;

import com.hrm.coffeeshop.common.*;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
public class AdminTrainingController {
    private final TrainingService svc;

    public AdminTrainingController(TrainingService svc) {
        this.svc = svc;
    }

    @PostMapping("/admin/training/courses")
    @PreAuthorize("hasRole('SYSTEM_ADMIN')")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<CourseView> create(@Valid @RequestBody CourseRequest r) {
        return ApiResponse.ok("Course created", svc.createCourse(r));
    }

    @PutMapping("/admin/training/courses/{courseId}")
    @PreAuthorize("hasRole('SYSTEM_ADMIN')")
    public ApiResponse<CourseView> update(@PathVariable Integer courseId, @Valid @RequestBody CourseRequest r) {
        return ApiResponse.ok("Course updated", svc.updateCourse(courseId, r));
    }
}
