package com.hrm.coffeeshop.it;

import com.hrm.coffeeshop.config.JwtService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.UUID;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
class ViolationListIT extends IntegrationTestBase {

    @Autowired MockMvc mvc;
    @Autowired JwtService jwt;

    @Test
    void listsViolationsByOccurredAtWhenSortIsOmitted() throws Exception {
        long userId = createUser("it-violation-list-" + UUID.randomUUID() + "@hrm.test");
        int managerRoleId = jdbc.queryForObject(
                "SELECT RoleId FROM dbo.Role WHERE RoleCode = 'STORE_MANAGER'", Integer.class);
        jdbc.update("INSERT INTO dbo.UserRole (UserId, RoleId) VALUES (?, ?)", userId, managerRoleId);

        long employeeId = jdbc.queryForObject(
                "SELECT TOP 1 EmployeeId FROM dbo.Employee ORDER BY EmployeeId", Long.class);
        int ruleId = jdbc.queryForObject(
                "SELECT TOP 1 RuleId FROM dbo.RuleCatalog ORDER BY RuleId", Integer.class);

        String olderPending = "ViolationListIT older pending " + UUID.randomUUID();
        String newerPending = "ViolationListIT newer pending " + UUID.randomUUID();
        String newestRejected = "ViolationListIT newest rejected " + UUID.randomUUID();
        insertViolation(employeeId, ruleId, "2099-01-01T00:00:00Z", olderPending, "PENDING");
        insertViolation(employeeId, ruleId, "2099-01-02T00:00:00Z", newerPending, "PENDING");
        insertViolation(employeeId, ruleId, "2099-01-03T00:00:00Z", newestRejected, "REJECTED");

        String token = jwt.createAccessToken(userId);
        mvc.perform(get("/api/v1/violations")
                        .queryParam("page", "0")
                        .queryParam("size", "20")
                        .queryParam("employeeId", Long.toString(employeeId))
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items[0].details").value(newestRejected))
                .andExpect(jsonPath("$.data.items[1].details").value(newerPending))
                .andExpect(jsonPath("$.data.items[2].details").value(olderPending));

        mvc.perform(get("/api/v1/violations")
                        .queryParam("page", "0")
                        .queryParam("size", "20")
                        .queryParam("employeeId", Long.toString(employeeId))
                        .queryParam("status", "OPEN")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items[0].details").value(newerPending))
                .andExpect(jsonPath("$.data.items[1].details").value(olderPending))
                .andExpect(jsonPath("$.data.items[2]").doesNotExist());
    }

    private void insertViolation(long employeeId, int ruleId, String occurredAt,
                                 String details, String status) {
        jdbc.update("INSERT INTO dbo.ViolationEvent " +
                        "(EmployeeId, RuleId, OccurredAt, SourceType, Details, RecordStatus) " +
                        "VALUES (?, ?, ?, 'MANUAL', ?, ?)",
                employeeId, ruleId, Timestamp.from(Instant.parse(occurredAt)), details, status);
    }
}
