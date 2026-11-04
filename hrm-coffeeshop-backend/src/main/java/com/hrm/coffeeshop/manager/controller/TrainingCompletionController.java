package com.hrm.coffeeshop.manager.controller;
import com.hrm.coffeeshop.common.ApiResponse;
import com.hrm.coffeeshop.shared.dto.TrainingDto.*;
import com.hrm.coffeeshop.shared.dto.MiscDto.*;
import com.hrm.coffeeshop.shared.service.TrainingService;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.util.List;
@RestController
@PreAuthorize("hasAuthority('TRAINING_MANAGE') or hasRole('SYSTEM_ADMIN')")
public class TrainingCompletionController {
    private final TrainingService service;
    public TrainingCompletionController(TrainingService service){this.service=service;}
    @GetMapping("/training/completion-reviews/pending")
    public ApiResponse<List<CompletionReviewView>> pending(){return ApiResponse.ok(service.pendingCompletionReviews());}
    @GetMapping("/training/completion-reviews/{id}")
    public ApiResponse<CompletionReviewView> detail(@PathVariable Long id){return ApiResponse.ok(service.completionDetail(id));}
    @PostMapping("/training/completion-reviews/{id}/approve")
    public ApiResponse<MyTrainingView> approve(@PathVariable Long id,@RequestBody(required=false) OptionalNoteRequest r){
        return ApiResponse.ok("Đã xác nhận hoàn thành",service.approveCompletion(id,r==null?null:r.note()));
    }
    @PostMapping("/training/completion-reviews/{id}/not-complete")
    public ApiResponse<MyTrainingView> reject(@PathVariable Long id,@Valid @RequestBody ReasonRequest r){
        return ApiResponse.ok("Đã ghi nhận cần tiếp tục học",service.markNotComplete(id,r.reason()));
    }
}
