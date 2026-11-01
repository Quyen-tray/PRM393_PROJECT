package com.hrm.coffeeshop.it;

import com.hrm.coffeeshop.config.CorrelationIdFilter;
import com.hrm.coffeeshop.shared.controller.SharedLocalStorageViewController;
import com.hrm.coffeeshop.shared.service.SignedUrlStorageGateway;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import java.net.URI;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Arrays;
import java.util.Map;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

/** Kiểm tra audit phải phản ánh kết quả truy cập file thực tế, không chỉ việc cấp signed URL. */
class SignedFileAccessAuditIT extends IntegrationTestBase {
    @Autowired SharedLocalStorageViewController fileView;
    @Autowired SignedUrlStorageGateway signedStorage;

    @AfterEach
    void clearRequestContext() { RequestContextHolder.resetRequestAttributes(); }

    @Test
    void successfulAccessIsAuditedWithCorrelationId() {
        String key = "private-documents/employee-1/" + UUID.randomUUID() + ".pdf";
        storage.store(key, "%PDF-1.4\n".getBytes(StandardCharsets.US_ASCII));
        long actor = userIdOfEmployee("NV001");
        setCorrelation("audit-success-001");

        var response = view(key, expiry(), signature(key, actor), actor);

        assertEquals(200, response.getStatusCode().value());
        assertEquals("STORAGE_VIEW", latestAction(key));
        assertEquals("audit-success-001", latestCorrelation(key));
        assertEquals(actor, latestActor(key));
    }

    @Test
    void validSignatureForMissingFileIsAuditedAsNotFound() {
        String key = "private-documents/employee-1/" + UUID.randomUUID() + ".pdf";
        long actor = userIdOfEmployee("NV001");
        setCorrelation("audit-missing-001");

        var response = view(key, expiry(), signature(key, actor), actor);

        assertEquals(404, response.getStatusCode().value());
        assertEquals("STORAGE_VIEW_NOT_FOUND", latestAction(key));
        assertEquals("audit-missing-001", latestCorrelation(key));
    }

    @Test
    void invalidSignatureIsAuditedAsDenied() {
        String key = "private-documents/employee-1/" + UUID.randomUUID() + ".pdf";
        setCorrelation("audit-denied-001");

        var response = view(key, expiry(), "invalid-signature", userIdOfEmployee("NV001"));

        assertEquals(403, response.getStatusCode().value());
        assertEquals("STORAGE_VIEW_DENIED", latestAction(key));
        assertEquals("audit-denied-001", latestCorrelation(key));
        assertNull(latestActor(key), "actor claim chưa xác minh không được ghi nhận");
    }

    @Test
    void expiredSignedUrlIsDeniedAndAudited() {
        String key = "private-documents/employee-1/" + UUID.randomUUID() + ".pdf";
        long actor = userIdOfEmployee("NV001");
        Map<String, String> query = query(signedStorage.createViewUrl(key, Duration.ofSeconds(-1), actor));
        setCorrelation("audit-expired-001");

        var response = view(key, Long.parseLong(query.get("exp")), query.get("sig"), actor);

        assertEquals(403, response.getStatusCode().value());
        assertEquals("STORAGE_VIEW_DENIED", latestAction(key));
    }

    @Test
    void pathTraversalKeyCannotReadOutsideStorageRoot() {
        String key = "../outside-" + UUID.randomUUID() + ".pdf";
        long actor = userIdOfEmployee("NV001");
        Map<String, String> query = query(signedStorage.createViewUrl(key, Duration.ofMinutes(2), actor));
        setCorrelation("audit-traversal-001");

        var response = view(key, Long.parseLong(query.get("exp")), query.get("sig"), actor);

        assertEquals(404, response.getStatusCode().value());
        assertEquals("STORAGE_VIEW_NOT_FOUND", latestAction(key));
    }

    private long expiry() { return clock.instant().plus(Duration.ofMinutes(2)).getEpochSecond(); }

    private String signature(String key, Long actor) {
        return query(signedStorage.createViewUrl(key, Duration.ofMinutes(2), actor)).get("sig");
    }

    private org.springframework.http.ResponseEntity<byte[]> view(String key, long exp, String sig, Long actor) {
        ServletRequestAttributes attributes = (ServletRequestAttributes) RequestContextHolder.getRequestAttributes();
        return fileView.view(key, exp, sig, actor, attributes.getRequest());
    }

    private static Map<String, String> query(String url) {
        String raw = URI.create(url).getRawQuery();
        return Arrays.stream(raw.split("&")).map(p -> p.split("=", 2))
                .collect(java.util.stream.Collectors.toMap(p -> p[0],
                        p -> URLDecoder.decode(p[1], StandardCharsets.UTF_8)));
    }

    private void setCorrelation(String id) {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setAttribute(CorrelationIdFilter.ATTRIBUTE, id);
        RequestContextHolder.setRequestAttributes(new ServletRequestAttributes(request));
    }

    private String latestAction(String key) {
        return jdbc.queryForObject("SELECT TOP 1 ActionCode FROM dbo.AuditLog WHERE EntityType = 'StoredFile' AND EntityId = ? ORDER BY AuditLogId DESC",
                String.class, key.substring(0, Math.min(key.length(), 100)));
    }

    private String latestCorrelation(String key) {
        return jdbc.queryForObject("SELECT TOP 1 CorrelationId FROM dbo.AuditLog WHERE EntityType = 'StoredFile' AND EntityId = ? ORDER BY AuditLogId DESC",
                String.class, key.substring(0, Math.min(key.length(), 100)));
    }

    private Long latestActor(String key) {
        return jdbc.queryForObject("SELECT TOP 1 ActorUserId FROM dbo.AuditLog WHERE EntityType = 'StoredFile' AND EntityId = ? ORDER BY AuditLogId DESC",
                Long.class, key.substring(0, Math.min(key.length(), 100)));
    }
}
