package com.hrm.coffeeshop.admin.controller;
import com.hrm.coffeeshop.common.ApiResponse;
import com.hrm.coffeeshop.shared.dto.TrainingDto.*;
import com.hrm.coffeeshop.shared.service.TrainingQuizService;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.util.List;
@RestController
@PreAuthorize("hasRole('SYSTEM_ADMIN')")
public class AdminTrainingQuestionController {
    private final TrainingQuizService service;
    public AdminTrainingQuestionController(TrainingQuizService service){this.service=service;}
    @GetMapping("/admin/training/courses/{courseId}/questions")
    public ApiResponse<List<QuizAdminQuestionView>> questions(@PathVariable Integer courseId){return ApiResponse.ok(service.adminQuestions(courseId));}
    @PostMapping("/admin/training/courses/{courseId}/questions")
    public ApiResponse<QuizAdminQuestionView> create(@PathVariable Integer courseId, @Valid @RequestBody QuizQuestionRequest r) {
        return ApiResponse.ok(service.saveQuestion(courseId, null, r));
    }
    @PutMapping("/admin/training/courses/{courseId}/questions/{questionId}")
    public ApiResponse<QuizAdminQuestionView> update(@PathVariable Integer courseId, @PathVariable Long questionId, @Valid @RequestBody QuizQuestionRequest r) {
        return ApiResponse.ok(service.saveQuestion(courseId, questionId, r));
    }
    @DeleteMapping("/admin/training/courses/{courseId}/questions/{questionId}")
    public ApiResponse<Void> delete(@PathVariable Integer courseId, @PathVariable Long questionId) {
        service.deleteQuestion(courseId, questionId); return ApiResponse.ok(null);
    }
    @PutMapping("/admin/training/courses/{courseId}/questions")
    public ApiResponse<List<QuizAdminQuestionView>> save(@PathVariable Integer courseId,@Valid @RequestBody QuizQuestionListRequest r){
        return ApiResponse.ok("Đã lưu bộ câu hỏi",service.replaceQuestions(courseId,r));
    }
}
