package com.hrm.coffeeshop.it;

import com.hrm.coffeeshop.domain.EmployeeRewardPenalty;
import com.hrm.coffeeshop.repository.EmployeeRewardPenaltyRepository;
import com.hrm.coffeeshop.shared.service.RewardPenaltyService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;

@Transactional
class ResourceSortingIT extends IntegrationTestBase {
    @Autowired EmployeeRewardPenaltyRepository decisions;
    @Autowired RewardPenaltyService rewards;
    long employee, manager, first, middle, last;

    @BeforeEach void fixtures() {
        employee = employeeIdByCode("NV001");
        manager = userIdByEmail("quanly@hrm.test");
        loginAs(manager, null, Set.of("STORE_MANAGER"));
        last = decision("2091-03-03T00:00:00Z");
        first = decision("2091-03-01T00:00:00Z");
        middle = decision("2091-03-02T00:00:00Z");
    }

    long decision(String date) {
        EmployeeRewardPenalty row = new EmployeeRewardPenalty();
        row.setEmployeeId(employee);
        row.setDecisionType("REWARD");
        row.setRuleId(jdbc.queryForObject("SELECT TOP (1) RuleId FROM dbo.RuleCatalog WHERE RuleType='REWARD' ORDER BY RuleId", Integer.class));
        row.setEffectiveDate(Instant.parse(date));
        row.setDetails("Sorting fixture");
        row.setProposedBy(manager);
        return decisions.saveAndFlush(row).getRewardPenaltyId();
    }

    @Test void rewardsDefaultToNewestBeforePagination() {
        var page = rewards.list(null, null, employee, PageRequest.of(0, 2));
        assertEquals(List.of("REWARD-" + last, "REWARD-" + middle),
                page.items().stream().map(r -> r.decisionId()).toList());
    }

    @ParameterizedTest @ValueSource(strings = {"asc", "desc"})
    void rewardsHonorRequestedDirectionAndKeepPaginationConsistent(String direction) {
        Sort sort = Sort.by(Sort.Direction.fromString(direction), "effectiveDate");
        var all = rewards.list(null, null, employee, PageRequest.of(0, 100, sort)).items()
                .stream().map(r -> r.decisionId()).toList();
        var ours = Set.of("REWARD-" + first, "REWARD-" + middle, "REWARD-" + last);
        assertEquals("asc".equals(direction)
                ? List.of("REWARD-" + first, "REWARD-" + middle, "REWARD-" + last)
                : List.of("REWARD-" + last, "REWARD-" + middle, "REWARD-" + first),
                all.stream().filter(ours::contains).toList());
        var next = rewards.list(null, null, employee, PageRequest.of(1, 2, sort)).items()
                .stream().map(r -> r.decisionId()).toList();
        assertEquals(all.subList(2, Math.min(4, all.size())), next);
    }
}
