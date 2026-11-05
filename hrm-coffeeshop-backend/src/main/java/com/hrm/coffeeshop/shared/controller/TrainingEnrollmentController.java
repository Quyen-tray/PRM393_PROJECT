package com.hrm.coffeeshop.shared.controller;
import com.hrm.coffeeshop.common.ApiResponse;
import com.hrm.coffeeshop.shared.dto.TrainingDto.MyTrainingView;
import com.hrm.coffeeshop.shared.service.TrainingService;
import org.springframework.web.bind.annotation.*;
@RestController
public class TrainingEnrollmentController {
    private final TrainingService training;
    public TrainingEnrollmentController(TrainingService training) { this.training=training; }
    @GetMapping("/training/enrollments/{id}")
    public ApiResponse<MyTrainingView> enrollment(@PathVariable Long id) { return ApiResponse.ok(training.enrollment(id)); }
}
