package com.hrm.coffeeshop.it;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.hrm.coffeeshop.common.ErrorCode;
import com.hrm.coffeeshop.config.JwtService;
import com.hrm.coffeeshop.shared.dto.DocumentDto.SubmitRequest;
import com.hrm.coffeeshop.shared.service.DocumentService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
class EmployeeDocumentWorkflowIT extends IntegrationTestBase {
    private static final byte[] PDF = "%PDF-1.4\n%employee-document-it\n".getBytes(StandardCharsets.US_ASCII);

    @Autowired MockMvc mvc;
    @Autowired JwtService jwt;
    @Autowired DocumentService documents;
    @Autowired ObjectMapper objectMapper;

    @Test
    void catalogReturnsOnlyActiveTypesAndEffectivePositionRequirements() throws Exception {
        long employeeId = employeeIdByCode("NV001");
        int positionId = jdbc.queryForObject(
                "SELECT PositionId FROM dbo.Employee WHERE EmployeeId = ?", Integer.class, employeeId);
        int requiredType = createType(true);
        int optionalType = createType(true);
        int inactiveType = createType(false);
        addRequirement(positionId, requiredType, true);
        addRequirement(positionId, inactiveType, true);

        MvcResult result = mvc.perform(get("/api/v1/employees/me/documents/catalog")
                        .header("Authorization", bearer(employeeId)))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode items = objectMapper.readTree(result.getResponse().getContentAsString())
                .path("data").path("documents");
        assertEquals(positionId, objectMapper.readTree(result.getResponse().getContentAsString())
                .path("data").path("positionId").asInt());
        assertTrue(items.findValues("documentTypeId").stream().map(JsonNode::asInt).toList().contains(requiredType));
        assertTrue(items.findValues("documentTypeId").stream().map(JsonNode::asInt).toList().contains(optionalType));
        assertFalse(items.findValues("documentTypeId").stream().map(JsonNode::asInt).toList().contains(inactiveType));
        assertEquals(true, findItem(items, requiredType).path("required").asBoolean());
        assertEquals(false, findItem(items, optionalType).path("required").asBoolean());
        assertTrue(findItem(items, requiredType).path("isActive").asBoolean());
    }

    @Test
    void catalogAndSubmitUseAuthenticatedEmployee() throws Exception {
        long employeeA = employeeIdByCode("NV001");
        long employeeB = employeeIdByCode("NV002");
        int typeId = createType(true);
        String key = storePdf(employeeA);
        String body = objectMapper.writeValueAsString(Map.of(
                "documentTypeId", typeId,
                "storageKey", key,
                "employeeId", employeeB));

        MvcResult result = mvc.perform(post("/api/v1/employees/me/documents")
                        .header("Authorization", bearer(employeeA))
                        .contentType("application/json")
                        .content(body))
                .andExpect(status().isCreated())
                .andReturn();
        JsonNode response = objectMapper.readTree(result.getResponse().getContentAsString()).path("data");
        assertEquals(employeeA, response.path("employeeId").asLong());
        assertFalse(response.has("requestedEmployeeId"));
    }

    @Test
    void submitBlocksPendingAndValidApprovedButAllowsRejectedAndExpiredVersions() {
        long employeeId = employeeIdByCode("NV001");
        loginAs(userIdOfEmployee("NV001"), employeeId, java.util.Set.of("EMPLOYEE"));
        LocalDate today = LocalDate.of(2031, 3, 1);

        assertSubmissionBlocked(employeeId, "PENDING", null);
        assertSubmissionBlocked(employeeId, "APPROVED", null);
        assertSubmissionBlocked(employeeId, "APPROVED", today);

        assertResubmissionAllowedAndHistoryRetained(employeeId, "REJECTED", null);
        assertResubmissionAllowedAndHistoryRetained(employeeId, "EXPIRED", today.minusDays(1));
        assertResubmissionAllowedAndHistoryRetained(employeeId, "APPROVED", today.minusDays(1));
    }

    @Test
    void concurrentSubmissionsLeaveAtMostOnePendingDocument() throws Exception {
        long employeeId = employeeIdByCode("NV001");
        int typeId = createType(true);
        String indexName = "UX_EmployeeDocument_OnePendingPerType";
        Integer indexCount = jdbc.queryForObject(
                "SELECT COUNT(*) FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.EmployeeDocument') "
                        + "AND name = ? AND is_unique = 1 AND has_filter = 1", Integer.class, indexName);
        assertEquals(1, indexCount, "The database must enforce one PENDING document per employee/type");

        String token = bearer(employeeId);
        String firstKey = storePdf(employeeId);
        String secondKey = storePdf(employeeId);
        CountDownLatch ready = new CountDownLatch(2);
        CountDownLatch start = new CountDownLatch(1);
        ExecutorService pool = Executors.newFixedThreadPool(2);
        try {
            Future<Integer> first = pool.submit(() -> concurrentSubmit(token, typeId, firstKey, ready, start));
            Future<Integer> second = pool.submit(() -> concurrentSubmit(token, typeId, secondKey, ready, start));
            ready.await();
            start.countDown();
            int firstStatus = first.get();
            int secondStatus = second.get();
            assertEquals(1, (firstStatus == 201 ? 1 : 0) + (secondStatus == 201 ? 1 : 0));
            assertEquals(1, (firstStatus == 409 ? 1 : 0) + (secondStatus == 409 ? 1 : 0));
            Integer pending = jdbc.queryForObject(
                    "SELECT COUNT(*) FROM dbo.EmployeeDocument WHERE EmployeeId = ? AND DocumentTypeId = ? AND ReviewStatus = 'PENDING'",
                    Integer.class, employeeId, typeId);
            assertEquals(1, pending);
        } finally {
            pool.shutdownNow();
        }
    }

    @Test
    void submitRejectsAnotherEmployeesStorageKey() {
        long employeeA = employeeIdByCode("NV001");
        long employeeB = employeeIdByCode("NV002");
        int typeId = createType(true);
        loginAs(userIdOfEmployee("NV001"), employeeA, java.util.Set.of("EMPLOYEE"));
        String otherEmployeeKey = storePdf(employeeB);

        assertRejected(() -> documents.submit(employeeA,
                        new SubmitRequest(typeId, otherEmployeeKey, null, null)),
                ErrorCode.VALIDATION_ERROR);
    }

    private JsonNode findItem(JsonNode items, int typeId) {
        for (JsonNode item : items) {
            if (item.path("documentTypeId").asInt() == typeId) return item;
        }
        fail("Document catalog omitted type " + typeId);
        return null;
    }

    private int createType(boolean active) {
        String code = "IT_" + UUID.randomUUID().toString().replace("-", "").substring(0, 20);
        jdbc.update("INSERT INTO dbo.DocumentType (DocumentCode, DocumentName, IsActive) VALUES (?, ?, ?)",
                code, "Integration document " + code, active);
        return jdbc.queryForObject("SELECT DocumentTypeId FROM dbo.DocumentType WHERE DocumentCode = ?",
                Integer.class, code);
    }

    private void addRequirement(int positionId, int documentTypeId, boolean mandatory) {
        jdbc.update("INSERT INTO dbo.PositionDocumentRequirement "
                        + "(PositionId, DocumentTypeId, IsMandatory, EffectiveFrom) VALUES (?, ?, ?, '2030-01-01')",
                positionId, documentTypeId, mandatory);
    }

    private void assertSubmissionBlocked(long employeeId, String status, LocalDate expiresAt) {
        int typeId = createType(true);
        insertExistingDocument(employeeId, typeId, status, expiresAt);
        String key = storePdf(employeeId);
        assertRejected(() -> documents.submit(employeeId, new SubmitRequest(typeId, key, null, null)),
                ErrorCode.CONFLICT);
    }

    private void assertResubmissionAllowedAndHistoryRetained(long employeeId, String status,
                                                              LocalDate expiresAt) {
        int typeId = createType(true);
        long oldDocumentId = insertExistingDocument(employeeId, typeId, status, expiresAt);
        long previousCount = jdbc.queryForObject(
                "SELECT COUNT(*) FROM dbo.EmployeeDocument WHERE EmployeeId = ? AND DocumentTypeId = ?",
                Long.class, employeeId, typeId);
        var submitted = documents.submit(employeeId,
                new SubmitRequest(typeId, storePdf(employeeId), null, null));
        assertNotNull(submitted);
        assertEquals(previousCount + 1, jdbc.queryForObject(
                "SELECT COUNT(*) FROM dbo.EmployeeDocument WHERE EmployeeId = ? AND DocumentTypeId = ?",
                Long.class, employeeId, typeId));
        assertEquals(status, jdbc.queryForObject(
                "SELECT ReviewStatus FROM dbo.EmployeeDocument WHERE EmployeeDocumentId = ?",
                String.class, oldDocumentId));
    }

    private long insertExistingDocument(long employeeId, int typeId, String status, LocalDate expiresAt) {
        String key = "private-documents/seed/it-" + UUID.randomUUID() + ".pdf";
        jdbc.update("INSERT INTO dbo.EmployeeDocument "
                        + "(EmployeeId, DocumentTypeId, FileName, StorageKey, ReviewStatus, ExpiresAt) "
                        + "VALUES (?, ?, 'existing.pdf', ?, ?, ?)",
                employeeId, typeId, key, status, expiresAt);
        return jdbc.queryForObject("SELECT EmployeeDocumentId FROM dbo.EmployeeDocument WHERE StorageKey = ?",
                Long.class, key);
    }

    private String storePdf(long employeeId) {
        String key = "private-documents/employee-" + employeeId + "/" + UUID.randomUUID() + ".pdf";
        storage.store(key, PDF);
        return key;
    }

    private String bearer(long employeeId) {
        long userId = jdbc.queryForObject("SELECT UserId FROM dbo.Employee WHERE EmployeeId = ?",
                Long.class, employeeId);
        return "Bearer " + jwt.createAccessToken(userId);
    }

    private int concurrentSubmit(String token, int typeId, String key, CountDownLatch ready,
                                 CountDownLatch start) throws Exception {
        ready.countDown();
        start.await();
        String body = objectMapper.writeValueAsString(Map.of("documentTypeId", typeId, "storageKey", key));
        return mvc.perform(post("/api/v1/employees/me/documents")
                        .header("Authorization", token)
                        .contentType("application/json")
                        .content(body))
                .andReturn().getResponse().getStatus();
    }
}
