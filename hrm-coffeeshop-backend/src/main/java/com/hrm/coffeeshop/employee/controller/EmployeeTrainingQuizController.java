package com.hrm.coffeeshop.employee.controller;

import com.hrm.coffeeshop.common.ApiResponse;
import com.hrm.coffeeshop.common.SecurityUtils;
import com.hrm.coffeeshop.shared.dto.TrainingDto.QuizQuestionView;
import com.hrm.coffeeshop.shared.dto.TrainingDto.QuizResultView;
import com.hrm.coffeeshop.shared.dto.TrainingDto.QuizSubmissionRequest;
import com.hrm.coffeeshop.shared.service.TrainingQuizService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
public class EmployeeTrainingQuizController {
    private final TrainingQuizService quizzes;

    public EmployeeTrainingQuizController(TrainingQuizService quizzes) {
        this.quizzes = quizzes;
    }

    @GetMapping("/training/courses/{courseId}/quiz")
    public ApiResponse<List<QuizQuestionView>> quiz(@PathVariable Integer courseId) {
        SecurityUtils.requireEmployeeId();
        return ApiResponse.ok(quizzes.quiz(courseId));
    }

    @PostMapping("/training/courses/{courseId}/quiz-attempts")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<QuizResultView> submit(
            @PathVariable Integer courseId,
            @Valid @RequestBody QuizSubmissionRequest request) {
        SecurityUtils.requireEmployeeId();
        return ApiResponse.ok("Quiz attempt recorded", quizzes.submit(courseId, request));
    }
}
