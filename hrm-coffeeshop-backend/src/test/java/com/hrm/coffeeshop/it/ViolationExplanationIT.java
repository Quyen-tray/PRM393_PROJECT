package com.hrm.coffeeshop.it;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.hrm.coffeeshop.config.JwtService;
import com.hrm.coffeeshop.shared.service.StorageGateway;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;

import java.util.Map;
import java.util.UUID;

import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.not;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
class ViolationExplanationIT extends IntegrationTestBase {

    @Autowired MockMvc mvc;
    @Autowired JwtService jwt;
    @Autowired ObjectMapper objectMapper;

    @Test
    void employeeListsOnlyOwnViolations() throws Exception {
        long ownEmployeeId = employeeIdByCode("NV001");
        long otherEmployeeId = employeeIdByCode("NV002");
        String ownDetails = "explanation-own-" + UUID.randomUUID();
        String otherDetails = "explanation-other-" + UUID.randomUUID();
        insertViolation(ownEmployeeId, ownDetails, "PENDING");
        insertViolation(otherEmployeeId, otherDetails, "PENDING");

        mvc.perform(get("/api/v1/employees/me/violations")
                        .header("Authorization", bearer("NV001")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.items[*].details", hasItem(ownDetails)))
                .andExpect(jsonPath("$.data.items[*].details", not(hasItem(otherDetails))));
    }

    @Test
    void employeeCannotReadOrSubmitExplanationForAnotherEmployeesViolation() throws Exception {
        long ownerId = employeeIdByCode("NV001");
        long violationId = insertViolation(ownerId, "owned-violation-" + UUID.randomUUID(), "PENDING");

        mvc.perform(get("/api/v1/employees/me/violations/{id}/explanations", violationId)
                        .header("Authorization", bearer("NV002")))
                .andExpect(status().isNotFound());

        mvc.perform(post("/api/v1/employees/me/violations/{id}/explanations", violationId)
                        .header("Authorization", bearer("NV002"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("explanation", "This belongs to another employee"))))
                .andExpect(status().isNotFound());

        assertEquals(0, explanationCount(violationId));
    }

    @Test
    void explanationsAppendWhileOpenAndNeverChangeViolationStatus() throws Exception {
        long employeeId = employeeIdByCode("NV001");
        long violationId = insertViolation(employeeId, "append-only-" + UUID.randomUUID(), "PENDING");

        submit("NV001", violationId, "First explanation").andExpect(status().isCreated());
        submit("NV001", violationId, "Additional context").andExpect(status().isCreated());

        assertEquals("PENDING", violationStatus(violationId));
        assertEquals(2, explanationCount(violationId));
        mvc.perform(get("/api/v1/employees/me/violations/{id}/explanations", violationId)
                        .header("Authorization", bearer("NV001")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(2))
                .andExpect(jsonPath("$.data[0].explanation").value("First explanation"))
                .andExpect(jsonPath("$.data[1].explanation").value("Additional context"))
                .andExpect(jsonPath("$.data[0].evidenceStorageKey").doesNotExist());
    }

    @Test
    void closedViolationRejectsExplanation() throws Exception {
        long employeeId = employeeIdByCode("NV001");
        long violationId = insertViolation(employeeId, "closed-" + UUID.randomUUID(), "APPROVED");

        submit("NV001", violationId, "Too late")
                .andExpect(status().isConflict());

        assertEquals(0, explanationCount(violationId));
    }

    @Test
    void reviewerPermissionControlsExplanationHistoryAndEvidenceMustBeOwned() throws Exception {
        long employeeId = employeeIdByCode("NV001");
        long violationId = insertViolation(employeeId, "review-permission-" + UUID.randomUUID(), "PENDING");
        String ownKey = "private-documents/employee-" + employeeId + "/" + UUID.randomUUID() + ".png";
        storage.store(ownKey, new byte[]{1, 2, 3});
        mvc.perform(post("/api/v1/employees/me/violations/{id}/explanations", violationId)
                        .header("Authorization", bearer("NV001"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("explanation", "Has evidence", "evidenceStorageKey", ownKey))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.evidenceViewUrl").isNotEmpty())
                .andExpect(jsonPath("$.data.evidenceStorageKey").doesNotExist());

        mvc.perform(get("/api/v1/violations/{id}/explanations", violationId)
                        .header("Authorization", bearer("NV001")))
                .andExpect(status().isForbidden());
        mvc.perform(get("/api/v1/violations/{id}/explanations", violationId)
                        .header("Authorization", bearer("QL001")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.length()").value(1))
                .andExpect(jsonPath("$.data[0].evidenceViewUrl").isNotEmpty());

        long otherEmployeeId = employeeIdByCode("NV002");
        String otherKey = "private-documents/employee-" + otherEmployeeId + "/" + UUID.randomUUID() + ".png";
        storage.store(otherKey, new byte[]{1, 2, 3});
        int before = explanationCount(violationId);
        mvc.perform(post("/api/v1/employees/me/violations/{id}/explanations", violationId)
                        .header("Authorization", bearer("NV001"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("explanation", "Wrong owner key", "evidenceStorageKey", otherKey))))
                .andExpect(status().isBadRequest());
        assertEquals(before, explanationCount(violationId));
    }

    private ResultActions submit(String employeeCode, long violationId, String explanation) throws Exception {
        return mvc.perform(post("/api/v1/employees/me/violations/{id}/explanations", violationId)
                .header("Authorization", bearer(employeeCode))
                .contentType(MediaType.APPLICATION_JSON)
                .content(json(Map.of("explanation", explanation))));
    }

    private String bearer(String employeeCode) {
        return "Bearer " + jwt.createAccessToken(userIdOfEmployee(employeeCode));
    }

    private String json(Object value) throws Exception {
        return objectMapper.writeValueAsString(value);
    }

    private long insertViolation(long employeeId, String details, String status) {
        int ruleId = jdbc.queryForObject("SELECT TOP 1 RuleId FROM dbo.RuleCatalog ORDER BY RuleId", Integer.class);
        jdbc.update("INSERT INTO dbo.ViolationEvent (EmployeeId, RuleId, SourceType, Details, RecordStatus) "
                        + "VALUES (?, ?, 'MANUAL', ?, ?)",
                employeeId, ruleId, details, status);
        return jdbc.queryForObject("SELECT CONVERT(BIGINT, SCOPE_IDENTITY())", Long.class);
    }

    private int explanationCount(long violationId) {
        return jdbc.queryForObject("SELECT COUNT(*) FROM dbo.ViolationExplanation WHERE ViolationEventId = ?",
                Integer.class, violationId);
    }

    private String violationStatus(long violationId) {
        return jdbc.queryForObject("SELECT RecordStatus FROM dbo.ViolationEvent WHERE ViolationEventId = ?",
                String.class, violationId);
    }
}
