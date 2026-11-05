package com.hrm.coffeeshop.employee.controller;
import com.hrm.coffeeshop.common.*;
import com.hrm.coffeeshop.shared.dto.TrainingDto.*;
import com.hrm.coffeeshop.shared.service.TrainingQuizService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import java.util.List;
@RestController
public class EmployeeTrainingQuizController {
    private final TrainingQuizService service;
    public EmployeeTrainingQuizController(TrainingQuizService service){this.service=service;}
    @GetMapping("/training/courses/{courseId}/quiz")
    public ApiResponse<List<QuizQuestionView>> quiz(@PathVariable Integer courseId){return ApiResponse.ok(service.quiz(courseId));}
    @PostMapping("/training/courses/{courseId}/quiz-attempts") @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<QuizResultView> submit(@PathVariable Integer courseId,@Valid @RequestBody QuizSubmissionRequest r){
        return ApiResponse.ok("Đã ghi nhận kết quả bài kiểm tra",service.submit(courseId,r));
    }
    @GetMapping("/training/courses/{courseId}/attempts/me")
    public ApiResponse<List<AttemptView>> attempts(@PathVariable Integer courseId){return ApiResponse.ok(service.attempts(courseId));}
}
