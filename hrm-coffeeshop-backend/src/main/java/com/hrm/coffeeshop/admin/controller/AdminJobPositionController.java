package com.hrm.coffeeshop.admin.controller;

import com.hrm.coffeeshop.shared.dto.JobPositionDto.DocRequirementView;
import com.hrm.coffeeshop.shared.dto.JobPositionDto.DocRequirementsRequest;
import com.hrm.coffeeshop.shared.dto.JobPositionDto.PositionRequest;
import com.hrm.coffeeshop.shared.dto.JobPositionDto.PositionView;
import com.hrm.coffeeshop.shared.dto.JobPositionDto.TrainingRequirementView;
import com.hrm.coffeeshop.shared.dto.JobPositionDto.TrainingRequirementsRequest;
import com.hrm.coffeeshop.shared.service.JobPositionService;

import com.hrm.coffeeshop.common.*;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.util.List;

/** SRS 9.3, 9.4, 9.7: quản lý chức vụ và yêu cầu theo chức vụ (Admin). */
@RestController
public class AdminJobPositionController {
    private final JobPositionService svc;

    public AdminJobPositionController(JobPositionService svc) {
        this.svc = svc;
    }

    @GetMapping("/admin/job-positions")
    @PreAuthorize("hasRole('SYSTEM_ADMIN')")
    public ApiResponse<List<PositionView>> list(@RequestParam(defaultValue = "false") boolean includeInactive) {
        return ApiResponse.ok(svc.list(includeInactive));
    }

    @PostMapping("/admin/job-positions")
    @PreAuthorize("hasRole('SYSTEM_ADMIN')")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<PositionView> create(@Valid @RequestBody PositionRequest r) {
        return ApiResponse.ok("Job position created", svc.create(r));
    }

    @PutMapping("/admin/job-positions/{positionId}")
    @PreAuthorize("hasRole('SYSTEM_ADMIN')")
    public ApiResponse<PositionView> update(@PathVariable Integer positionId, @Valid @RequestBody PositionRequest r) {
        return ApiResponse.ok("Job position updated", svc.update(positionId, r));
    }

    @GetMapping("/admin/job-positions/{positionId}/document-requirements")
    @PreAuthorize("hasRole('SYSTEM_ADMIN')")
    public ApiResponse<List<DocRequirementView>> documentRequirements(@PathVariable Integer positionId) {
        return ApiResponse.ok(svc.documentRequirements(positionId));
    }

    @PutMapping("/admin/job-positions/{positionId}/document-requirements")
    @PreAuthorize("hasRole('SYSTEM_ADMIN')")
    public ApiResponse<List<DocRequirementView>> replaceDocumentRequirements(@PathVariable Integer positionId,
                                                                            @Valid @RequestBody DocRequirementsRequest r) {
        return ApiResponse.ok("Document requirements updated", svc.replaceDocumentRequirements(positionId, r));
    }

    @GetMapping("/admin/job-positions/{positionId}/training-requirements")
    @PreAuthorize("hasRole('SYSTEM_ADMIN')")
    public ApiResponse<List<TrainingRequirementView>> trainingRequirements(@PathVariable Integer positionId) {
        return ApiResponse.ok(svc.trainingRequirements(positionId));
    }

    @PutMapping("/admin/job-positions/{positionId}/training-requirements")
    @PreAuthorize("hasRole('SYSTEM_ADMIN')")
    public ApiResponse<List<TrainingRequirementView>> replaceTrainingRequirements(@PathVariable Integer positionId,
                                                                                  @Valid @RequestBody TrainingRequirementsRequest r) {
        return ApiResponse.ok("Training requirements updated", svc.replaceTrainingRequirements(positionId, r));
    }
}
