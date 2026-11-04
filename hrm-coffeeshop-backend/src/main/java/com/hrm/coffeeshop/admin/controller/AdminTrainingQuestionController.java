package com.hrm.coffeeshop.admin.controller;

import com.hrm.coffeeshop.common.ApiResponse;
import com.hrm.coffeeshop.shared.dto.TrainingDto.QuizAdminQuestionView;
import com.hrm.coffeeshop.shared.dto.TrainingDto.QuizQuestionListRequest;
import com.hrm.coffeeshop.shared.service.TrainingQuizService;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
public class AdminTrainingQuestionController {
    private final TrainingQuizService quizzes;

    public AdminTrainingQuestionController(TrainingQuizService quizzes) {
        this.quizzes = quizzes;
    }

    @GetMapping("/admin/training/courses/{courseId}/questions")
    @PreAuthorize("hasRole('SYSTEM_ADMIN')")
    public ApiResponse<List<QuizAdminQuestionView>> questions(@PathVariable Integer courseId) {
        return ApiResponse.ok(quizzes.adminQuestions(courseId));
    }

    @PutMapping("/admin/training/courses/{courseId}/questions")
    @PreAuthorize("hasRole('SYSTEM_ADMIN')")
    public ApiResponse<List<QuizAdminQuestionView>> replace(
            @PathVariable Integer courseId,
            @Valid @RequestBody QuizQuestionListRequest request) {
        return ApiResponse.ok("Quiz questions updated", quizzes.replaceQuestions(courseId, request));
    }
}
