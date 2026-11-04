package com.hrm.coffeeshop.shared.controller;

import com.hrm.coffeeshop.common.*;
import com.hrm.coffeeshop.repository.*;
import com.hrm.coffeeshop.shared.service.*;
import org.springframework.web.bind.annotation.*;
import java.time.Duration;
import java.util.*;

@RestController
public class SharedRequestEvidenceController {
    private final AttendanceExceptionService explanations;
    private final AttendanceAdjustmentService adjustments;
    private final OvertimeService overtime;
    private final AttendanceExceptionRequestRepository exceptionRepo;
    private final AttendanceAdjustmentRequestRepository adjustmentRepo;
    private final AttendanceRepository attendanceRepo;
    private final AttendanceService attendance;
    private final StorageGateway storage;
    private final AuditService audit;
    public SharedRequestEvidenceController(AttendanceExceptionService explanations, AttendanceAdjustmentService adjustments,
        OvertimeService overtime, AttendanceExceptionRequestRepository exceptionRepo, AttendanceAdjustmentRequestRepository adjustmentRepo,
        AttendanceRepository attendanceRepo, AttendanceService attendance, StorageGateway storage, AuditService audit) {
        this.explanations=explanations;this.adjustments=adjustments;this.overtime=overtime;this.exceptionRepo=exceptionRepo;
        this.adjustmentRepo=adjustmentRepo;this.attendanceRepo=attendanceRepo;this.attendance=attendance;this.storage=storage;this.audit=audit;
    }
    private List<Map<String,Object>> signed(String key, Long ownerId, String type, Long id) {
        AuthUser user=SecurityUtils.current();
        if(!Objects.equals(ownerId,user.employeeId())) SecurityUtils.requirePermission(Permissions.EVIDENCE_VIEW);
        if(key==null || key.isBlank()) return List.of();
        audit.log("EVIDENCE_VIEW",type,id,null,Map.of("purpose","REQUEST_REVIEW"));
        return List.of(Map.of("evidenceViewUrl",storage.createViewUrl(key,Duration.ofMinutes(5),user.userId())));
    }
    @GetMapping("/attendance/explanation-requests/{id}/evidence")
    public ApiResponse<List<Map<String,Object>>> explanation(@PathVariable Long id) {
        var view=explanations.get(id);
        var row=exceptionRepo.findById(id).orElseThrow(()->BusinessException.notFound("giải trình"));
        return ApiResponse.ok(signed(row.getEvidenceStorageKey(),view.employeeId(),"AttendanceExceptionRequest",id));
    }
    @GetMapping("/attendance/adjustment-requests/{id}/evidence")
    public ApiResponse<List<Map<String,Object>>> adjustment(@PathVariable Long id) {
        var view=adjustments.get(id);
        var row=adjustmentRepo.findById(id).orElseThrow(()->BusinessException.notFound("điều chỉnh công"));
        return ApiResponse.ok(signed(row.getEvidenceStorageKey(),view.employeeId(),"AttendanceAdjustmentRequest",id));
    }
    @GetMapping("/attendance/overtime-requests/{id}/evidence")
    public ApiResponse<?> overtime(@PathVariable Long id) {
        var view=overtime.get(id);
        var record=attendanceRepo.findByShiftAssignmentId(view.scheduleId());
        return ApiResponse.ok(record.isEmpty()?List.of():attendance.verifications(record.get().getAttendanceId()));
    }
}
