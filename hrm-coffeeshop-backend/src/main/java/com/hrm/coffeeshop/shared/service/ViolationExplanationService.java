package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.common.*;
import com.hrm.coffeeshop.domain.ViolationExplanation;
import com.hrm.coffeeshop.repository.*;
import jakarta.validation.constraints.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.*;
import java.util.*;

@Service
public class ViolationExplanationService {
    public record Request(@NotBlank @Size(max = 2000) String reason, @Size(max = 900) String evidenceStorageKey) {}
    public record View(Long explanationId, Long violationId, Long employeeId, String reason, String evidenceUrl, OffsetDateTime createdAt) {}
    private final ViolationEventRepository violations;
    private final ViolationExplanationRepository explanations;
    private final StorageGateway storage;
    private final NotificationService notifications;
    private final AuditService audit;
    private final Clock clock;
    public ViolationExplanationService(ViolationEventRepository violations, ViolationExplanationRepository explanations,
            StorageGateway storage, NotificationService notifications, AuditService audit, Clock clock) {
        this.violations = violations; this.explanations = explanations; this.storage = storage;
        this.notifications = notifications; this.audit = audit; this.clock = clock;
    }
    private View view(ViolationExplanation e) {
        String url = e.getEvidenceStorageKey() == null ? null : storage.createViewUrl(e.getEvidenceStorageKey(), Duration.ofMinutes(2), SecurityUtils.current().userId());
        return new View(e.getExplanationId(), e.getViolationEventId(), e.getEmployeeId(), e.getReason(), url, TimeUtils.vn(e.getCreatedAt()));
    }
    @Transactional(readOnly = true)
    public List<View> list(Long id) {
        var v = violations.findById(id).orElseThrow(() -> BusinessException.notFound("vi phạm"));
        if (!v.getEmployeeId().equals(SecurityUtils.current().employeeId())) SecurityUtils.requirePermission(Permissions.VIOLATION_REVIEW);
        return explanations.findByViolationEventIdOrderByCreatedAtAsc(id).stream().map(this::view).toList();
    }
    @Transactional
    public View submit(Long id, Request request) {
        Long employeeId = SecurityUtils.requireEmployeeId();
        var v = violations.findById(id).orElseThrow(() -> BusinessException.notFound("vi phạm"));
        if (!v.getEmployeeId().equals(employeeId)) throw BusinessException.forbidden("Chỉ được giải trình vi phạm của mình");
        if (!"PENDING".equals(v.getRecordStatus())) throw BusinessException.invalidState("Vi phạm đã được xử lý; không thể bổ sung giải trình");
        String key = request.evidenceStorageKey();
        if (key != null && !key.isBlank()) {
            if (key.contains("..") || !key.startsWith("private-documents/employee-" + employeeId + "/") || !storage.exists(key))
                throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Bằng chứng chưa được tải lên hoặc không thuộc nhân viên");
        } else key = null;
        ViolationExplanation e = new ViolationExplanation();
        e.setViolationEventId(id); e.setEmployeeId(employeeId); e.setReason(request.reason().trim());
        e.setEvidenceStorageKey(key); e.setCreatedAt(clock.instant()); explanations.saveAndFlush(e);
        audit.log("VIOLATION_EXPLANATION", "ViolationEvent", id, null, Map.of("explanationId", e.getExplanationId()));
        notifications.notifyReviewers(Set.of(), Set.of(Permissions.VIOLATION_REVIEW), "VIOLATION_EXPLANATION", "Có giải trình vi phạm", "Nhân viên bổ sung giải trình", "ViolationEvent", id);
        return view(e);
    }
}
