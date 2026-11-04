package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.shared.dto.ViolationDto.DecisionRequest;
import com.hrm.coffeeshop.shared.dto.ViolationDto.DecisionView;

import com.hrm.coffeeshop.common.*;
import com.hrm.coffeeshop.domain.*;
import com.hrm.coffeeshop.repository.*;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.util.*;

/**
 * Quyết định thưởng/phạt (SRS 7.4 EmployeeRewardPenalty, DecisionType = REWARD | PENALTY).
 * Đã duyệt thì KHÔNG sửa: chỉ hủy kèm lý do + audit (BR-RW-04).
 * Người đề xuất ≠ người duyệt ≠ nhân viên được xét. Quyết định có số tiền chỉ vào bảng lương sau khi APPROVED.
 * Mã quyết định giữ dạng "REWARD-{id}" / "PENALTY-{id}" để API ổn định.
 */
@Service
public class RewardPenaltyService {
    private final EmployeeRewardPenaltyRepository decisions;
    private final RuleCatalogRepository rules;
    private final PayrollLockGuard lockGuard;
    private final StoreService storeService;
    private final PersonLookup people;
    private final NotificationService notifications;
    private final AuditService audit;
    private final Clock clock;
    private final ViolationEventRepository violations;

    public RewardPenaltyService(EmployeeRewardPenaltyRepository decisions, RuleCatalogRepository rules,
                                PayrollLockGuard lockGuard, StoreService storeService, PersonLookup people,
                                NotificationService notifications, AuditService audit, Clock clock, ViolationEventRepository violations) {
        this.decisions = decisions;
        this.rules = rules;
        this.lockGuard = lockGuard;
        this.storeService = storeService;
        this.people = people;
        this.notifications = notifications;
        this.audit = audit;
        this.clock = clock;
        this.violations = violations;
    }

    /** CRITICAL (hoặc số tiền ≥ ngưỡng nếu cấu hình) → Giám đốc vận hành; còn lại → người có quyền duyệt thưởng/phạt. */
    static void requireAuthority(AuthUser u, String severity, BigDecimal amount, int directorThreshold) {
        boolean needDirector = "CRITICAL".equals(severity)
                || (directorThreshold > 0 && amount != null && amount.compareTo(BigDecimal.valueOf(directorThreshold)) >= 0);
        boolean ok = needDirector ? u.hasPermission(Permissions.REWARD_APPROVE_CRITICAL)
                : u.hasPermission(Permissions.REWARD_APPROVE);
        if (!ok) throw BusinessException.forbidden(needDirector
                ? "Quyết định này cần Giám đốc vận hành phê duyệt" : "Bạn không có quyền xử lý quyết định này");
    }

    private static String decisionId(EmployeeRewardPenalty e) {
        return ("REWARD".equals(e.getDecisionType()) ? "REWARD-" : "PENALTY-") + e.getRewardPenaltyId();
    }

    private DecisionView view(EmployeeRewardPenalty e) {
        RuleCatalog rule = rules.findById(e.getRuleId()).orElse(null);
        return new DecisionView(decisionId(e), e.getDecisionType(), e.getEmployeeId(), people.nameOf(e.getEmployeeId()),
                rule == null ? null : rule.getRuleCode(), rule == null ? null : rule.getRuleName(),
                rule == null ? null : rule.getSeverity(), e.getDetails(), e.getAmount(), status(e.getDecisionStatus()),
                e.getProposedBy(), e.getApprovedBy(), e.getReviewNote(), TimeUtils.vn(e.getEffectiveDate()), e.getViolationEventId());
    }

    private static String status(String db) { return "PENDING".equals(db) ? "PENDING_APPROVAL" : db; }

    @Transactional
    public DecisionView create(DecisionRequest r) {
        AuthUser u = SecurityUtils.current();
        if (!u.hasPermission(Permissions.REWARD_PROPOSE)) throw BusinessException.forbidden("Bạn không có quyền đề xuất");
        boolean reward = "REWARD".equals(r.decisionType());
        if (people.employee(r.employeeId()).isEmpty()) throw BusinessException.notFound("nhân viên");
        if (people.userIdOf(r.employeeId()).equals(u.userId()))
            throw BusinessException.forbidden("Không thể tự đề xuất thưởng/phạt cho chính mình");
        RuleCatalog rule = rules.findByRuleCode(r.reasonCode()).filter(x -> Boolean.TRUE.equals(x.getIsActive()))
                .orElseThrow(() -> new BusinessException(ErrorCode.VALIDATION_ERROR, "Mã lý do không tồn tại"));
        if (reward != "REWARD".equals(rule.getRuleType()))
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Mã lý do không phù hợp loại quyết định");
        EmployeeRewardPenalty e = new EmployeeRewardPenalty();
        e.setDecisionType(reward ? "REWARD" : "PENALTY");
        e.setEmployeeId(r.employeeId());
        e.setRuleId(rule.getRuleId());
        if (r.violationEventId() != null) {
            var source = violations.findById(r.violationEventId()).orElseThrow(() -> BusinessException.notFound("vi phạm nguồn"));
            if (reward || !source.getEmployeeId().equals(r.employeeId()) || !source.getRuleId().equals(rule.getRuleId()))
                throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Nhân viên, quy định và loại phạt phải khớp vi phạm nguồn");
            if (!"APPROVED".equals(source.getRecordStatus())) throw BusinessException.invalidState("Vi phạm nguồn chưa được xác nhận");
            e.setViolationEventId(r.violationEventId());
        }
        e.setAmount(r.amount() != null ? r.amount() : rule.getDefaultAmount());
        e.setEffectiveDate(r.effectiveDate() != null ? TimeUtils.startOfDay(r.effectiveDate()) : clock.instant());
        e.setDetails(r.description().trim());
        e.setProposedBy(u.userId());
        decisions.save(e);
        DecisionView v = view(e);
        audit.log("DECISION_CREATE", "EmployeeRewardPenalty", e.getRewardPenaltyId(), null,
                Map.of("employeeId", r.employeeId(), "rule", rule.getRuleCode(), "amount", String.valueOf(e.getAmount())));
        notifications.notifyRole(Roles.STORE_MANAGER, "DECISION_PENDING", "Có đề xuất thưởng/phạt chờ duyệt",
                v.reasonName() + " - " + v.employeeName(), "EmployeeRewardPenalty", e.getRewardPenaltyId());
        return v;
    }

    /** Lọc theo loại, trạng thái, nhân viên (quy mô một cửa hàng: lọc trong bộ nhớ). */
    @Transactional(readOnly = true)
    public PageResponse<DecisionView> list(String type, String status, Long employeeId, Pageable p) {
        String dbStatus = status == null || status.isBlank() ? "" : ("PENDING_APPROVAL".equals(status) ? "PENDING" : status);
        String dbType = type == null ? "" : type.trim();
        Page<EmployeeRewardPenalty> page = decisions.search(dbType, employeeId == null ? 0L : employeeId, dbStatus,
                PageRequest.of(p.getPageNumber(), p.getPageSize()));
        return PageResponse.of(page, this::view);
    }

    private static boolean match(Long emp, String st, Long wantEmp, String wantSt) {
        return (wantEmp == null || wantEmp.equals(emp)) && (wantSt.isEmpty() || wantSt.equals(st));
    }

    @Transactional(readOnly = true)
    public PageResponse<DecisionView> mine(Pageable p) {
        return list(null, null, SecurityUtils.requireEmployeeId(), p);
    }

    @Transactional(readOnly = true)
    public DecisionView get(Long id) {
        var e = decisions.findById(id).orElseThrow(() -> BusinessException.notFound("quyết định"));
        if (!e.getEmployeeId().equals(SecurityUtils.current().employeeId())) SecurityUtils.requirePermission(Permissions.REWARD_VIEW);
        return view(e);
    }

    @Transactional
    public DecisionView approve(String decisionId, String note) { return decide(decisionId, "APPROVED", note); }

    @Transactional
    public DecisionView reject(String decisionId, String reason) {
        if (reason == null || reason.isBlank()) throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Phải nhập lý do từ chối");
        return decide(decisionId, "REJECTED", reason.trim());
    }

    @Transactional
    public DecisionView cancel(String decisionId, String reason) {
        if (reason == null || reason.isBlank()) throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Phải nhập lý do hủy");
        return decide(decisionId, "CANCELLED", reason.trim());
    }

    private DecisionView decide(String decisionId, String target, String note) {
        AuthUser u = SecurityUtils.current();
        boolean reward = decisionId.startsWith("REWARD-");
        if (!reward && !decisionId.startsWith("PENALTY-")) throw new BusinessException(ErrorCode.VALIDATION_ERROR, "decisionId không hợp lệ");
        long id;
        try { id = Long.parseLong(decisionId.substring(decisionId.indexOf('-') + 1)); }
        catch (NumberFormatException ex) { throw new BusinessException(ErrorCode.VALIDATION_ERROR, "decisionId không hợp lệ"); }

        EmployeeRewardPenalty e = decisions.findById(id).orElseThrow(() -> BusinessException.notFound("quyết định"));
        if (!(reward ? "REWARD" : "PENALTY").equals(e.getDecisionType()))
            throw BusinessException.notFound("quyết định");
        Long empId = e.getEmployeeId();
        String cur = e.getDecisionStatus();
        Long creator = e.getProposedBy();
        BigDecimal amount = e.getAmount();
        RuleCatalog rule = rules.findById(e.getRuleId()).orElseThrow();
        Instant at = e.getEffectiveDate();

        requireAuthority(u, rule.getSeverity(), amount, storeService.current().getDirectorApprovalThreshold());
        if (people.userIdOf(empId).equals(u.userId())) throw BusinessException.forbidden("Không thể xử lý quyết định về chính mình");

        if ("APPLIED".equals(cur)) throw BusinessException.invalidState("Quyết định đã áp dụng vào lương, không thể thay đổi");
        switch (target) {
            case "APPROVED", "REJECTED" -> {
                if (!"PENDING".equals(cur)) throw BusinessException.invalidState("Quyết định không ở trạng thái chờ duyệt");
                if (creator != null && creator.equals(u.userId())) throw BusinessException.forbidden("Người đề xuất không được tự duyệt");
            }
            case "CANCELLED" -> {
                if (!List.of("PENDING", "APPROVED").contains(cur)) throw BusinessException.invalidState("Không thể hủy quyết định ở trạng thái này");
            }
            default -> throw new IllegalStateException();
        }
        LocalDate d = TimeUtils.dateOf(at);
        if (!"REJECTED".equals(target)) lockGuard.assertWorkDateOpen(d);   // khóa kỳ chứa quyết định, rồi mới ghi

        Instant now = clock.instant();
        DecisionView before = view(e);
        e.setDecisionStatus(target);
        e.setApprovedBy(u.userId());
        e.setApprovedAt(now);
        e.setReviewNote(note);
        decisions.saveAndFlush(e);
        DecisionView after = view(e);
        audit.log("DECISION_" + target, "EmployeeRewardPenalty", id, Map.of("status", before.status()),
                Map.of("status", after.status(), "note", String.valueOf(note)));
        notifications.notify(people.userIdOf(empId), "DECISION_REVIEWED", "Quyết định thưởng/phạt đã được cập nhật",
                rule.getRuleName() + ": " + after.status(), "EmployeeRewardPenalty", id, null);
        return after;
    }
}
