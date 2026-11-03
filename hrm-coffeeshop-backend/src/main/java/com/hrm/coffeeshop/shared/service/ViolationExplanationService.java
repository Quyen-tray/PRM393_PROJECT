package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.common.BusinessException;
import com.hrm.coffeeshop.common.ErrorCode;
import com.hrm.coffeeshop.common.Permissions;
import com.hrm.coffeeshop.common.SecurityUtils;
import com.hrm.coffeeshop.common.TimeUtils;
import com.hrm.coffeeshop.domain.ViolationEvent;
import com.hrm.coffeeshop.domain.ViolationExplanation;
import com.hrm.coffeeshop.repository.ViolationEventRepository;
import com.hrm.coffeeshop.repository.ViolationExplanationRepository;
import com.hrm.coffeeshop.shared.dto.ViolationExplanationDto.ExplanationRequest;
import com.hrm.coffeeshop.shared.dto.ViolationExplanationDto.ExplanationView;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.regex.Pattern;

@Service
public class ViolationExplanationService {
    private static final Duration VIEW_TTL = Duration.ofSeconds(120);
    private static final Pattern EVIDENCE_KEY = Pattern.compile(
            "^private-documents/employee-[0-9]+/[A-Za-z0-9._\\-/]{1,850}$");

    private final ViolationEventRepository violations;
    private final ViolationExplanationRepository explanations;
    private final StorageGateway storage;
    private final AuditService audit;
    private final Clock clock;

    public ViolationExplanationService(ViolationEventRepository violations,
                                       ViolationExplanationRepository explanations,
                                       StorageGateway storage, AuditService audit, Clock clock) {
        this.violations = violations;
        this.explanations = explanations;
        this.storage = storage;
        this.audit = audit;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public List<ExplanationView> listMine(long employeeId, long violationId) {
        ViolationEvent violation = requireOwnedViolation(employeeId, violationId);
        return listForViolation(violation);
    }

    @Transactional
    public ExplanationView submitMine(long employeeId, long violationId, ExplanationRequest request) {
        ViolationEvent violation = requireOwnedViolation(employeeId, violationId, true);
        if (!"PENDING".equals(violation.getRecordStatus()))
            throw BusinessException.invalidState("Không thể giải trình vi phạm đã được quản lý xử lý");
        if (request == null || request.explanation() == null || request.explanation().isBlank())
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Nội dung giải trình không được để trống");
        if (request.explanation().length() > 2000)
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Nội dung giải trình tối đa 2000 ký tự");

        String evidenceKey = validateEvidenceKey(employeeId, request.evidenceStorageKey());
        ViolationExplanation explanation = new ViolationExplanation();
        explanation.setViolationEventId(violationId);
        explanation.setEmployeeId(employeeId);
        explanation.setExplanation(request.explanation().trim());
        explanation.setSubmittedAt(clock.instant());
        explanation.setEvidenceStorageKey(evidenceKey);
        ViolationExplanation saved = explanations.save(explanation);
        audit.log("VIOLATION_EXPLANATION_SUBMITTED", "ViolationEvent", violationId, null,
                Map.of("employeeId", employeeId, "explanationId", saved.getViolationExplanationId(),
                        "hasEvidence", evidenceKey != null));
        return view(saved);
    }

    @Transactional(readOnly = true)
    public List<ExplanationView> listForReview(long violationId) {
        SecurityUtils.requirePermission(Permissions.VIOLATION_REVIEW);
        ViolationEvent violation = violations.findById(violationId)
                .orElseThrow(() -> BusinessException.notFound("vi phạm"));
        return listForViolation(violation);
    }

    private ViolationEvent requireOwnedViolation(long employeeId, long violationId) {
        return requireOwnedViolation(employeeId, violationId, false);
    }

    private ViolationEvent requireOwnedViolation(long employeeId, long violationId, boolean lockForUpdate) {
        Optional<ViolationEvent> result = lockForUpdate
                ? violations.findByIdForUpdate(violationId)
                : violations.findById(violationId);
        ViolationEvent violation = result.orElseThrow(() -> BusinessException.notFound("vi phạm"));
        if (!Long.valueOf(employeeId).equals(violation.getEmployeeId()))
            throw BusinessException.notFound("vi phạm");
        return violation;
    }

    private List<ExplanationView> listForViolation(ViolationEvent violation) {
        List<ViolationExplanation> history = explanations
                .findByViolationEventIdOrderBySubmittedAtAscViolationExplanationIdAsc(violation.getViolationEventId());
        if (history.stream().anyMatch(item -> !Long.valueOf(violation.getEmployeeId()).equals(item.getEmployeeId())))
            throw BusinessException.invalidState("Lịch sử giải trình không khớp nhân viên của vi phạm");
        return history.stream().map(this::view).toList();
    }

    private String validateEvidenceKey(long employeeId, String value) {
        if (value == null || value.isBlank()) return null;
        String key = value.trim();
        if (!EVIDENCE_KEY.matcher(key).matches() || key.contains("..")
                || !key.startsWith("private-documents/employee-" + employeeId + "/"))
            throw new BusinessException(ErrorCode.VALIDATION_ERROR,
                    "Minh chứng phải thuộc hồ sơ riêng của nhân viên đang đăng nhập");
        if (!storage.exists(key))
            throw new BusinessException(ErrorCode.VALIDATION_ERROR,
                    "Tệp minh chứng chưa được tải lên hoặc đã bị xóa");
        return key;
    }

    private ExplanationView view(ViolationExplanation explanation) {
        String viewUrl = explanation.getEvidenceStorageKey() == null ? null
                : storage.createViewUrl(explanation.getEvidenceStorageKey(), VIEW_TTL,
                        SecurityUtils.current().userId());
        return new ExplanationView(explanation.getViolationExplanationId(), explanation.getViolationEventId(),
                explanation.getExplanation(), TimeUtils.vn(explanation.getSubmittedAt()), viewUrl);
    }
}
