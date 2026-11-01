package com.hrm.coffeeshop.shared.controller;

import com.hrm.coffeeshop.common.ApiResponse;
import com.hrm.coffeeshop.domain.RuleCatalog;
import com.hrm.coffeeshop.repository.RuleCatalogRepository;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.math.BigDecimal;
import java.util.Comparator;
import java.util.List;

/**
 * Danh mục mã lý do thưởng/phạt đang hoạt động (chỉ đọc), để người đề xuất chọn mã hợp lệ.
 * Chỉ trả các mã đang bật. Không trả mã tự động ghi nhận nếu ruleType không khớp bộ lọc.
 */
@RestController
public class SharedRuleCatalogController {
    private final RuleCatalogRepository rules;

    public SharedRuleCatalogController(RuleCatalogRepository rules) {
        this.rules = rules;
    }

    public record RuleView(Integer ruleId, String ruleCode, String ruleName, String ruleType, String severity,
                           BigDecimal defaultAmount, String description) {}

    @GetMapping("/rule-catalog")
    @PreAuthorize("hasAnyAuthority('REWARD_PROPOSE','REWARD_VIEW')")
    public ApiResponse<List<RuleView>> list(@RequestParam(required = false) String ruleType) {
        String wanted = ruleType == null ? "" : ruleType.trim();
        List<RuleView> out = rules.findAll().stream()
                .filter(r -> Boolean.TRUE.equals(r.getIsActive()))
                .filter(r -> wanted.isEmpty() || wanted.equals(r.getRuleType()))
                .sorted(Comparator.comparing(RuleCatalog::getRuleCode))
                .map(r -> new RuleView(r.getRuleId(), r.getRuleCode(), r.getRuleName(), r.getRuleType(),
                        r.getSeverity(), r.getDefaultAmount(), r.getDescription()))
                .toList();
        return ApiResponse.ok(out);
    }
}
