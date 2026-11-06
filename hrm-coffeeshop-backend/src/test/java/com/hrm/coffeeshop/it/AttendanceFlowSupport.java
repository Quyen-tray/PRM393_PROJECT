package com.hrm.coffeeshop.it;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.hrm.coffeeshop.config.JwtService;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.assertEquals;

abstract class AttendanceFlowSupport extends IntegrationTestBase {
    private static final AtomicInteger DAYS = new AtomicInteger();
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper mapper;
    @Autowired JwtService jwt;
    long employee, employeeUser, manager, admin, device;
    LocalDate day;
    String credential;

    @BeforeEach void actors() {
        employee = employeeIdByCode("NV001");
        employeeUser = userIdOfEmployee("NV001");
        manager = userIdByEmail("baonvchaos@gmail.com");
        admin = jdbc.queryForObject("SELECT TOP (1) ur.UserId FROM dbo.UserRole ur JOIN dbo.Role r ON r.RoleId=ur.RoleId WHERE r.RoleCode='SYSTEM_ADMIN' ORDER BY ur.UserId", Long.class);
        day = LocalDate.of(2065, 1, 1).plusDays(DAYS.addAndGet(40));
        at(day, 7, 0);
    }

    void at(LocalDate date, int hour, int minute) {
        clock.setAt(date.atTime(hour, minute).atZone(VN).toInstant());
    }

    JsonNode api(long actor, String method, String path, Object body, int expected) throws Exception {
        var request = MockMvcRequestBuilders.request(HttpMethod.valueOf(method), "/api/v1" + path)
                .header("Authorization", "Bearer " + jwt.createAccessToken(actor));
        if (credential != null) request.header("X-Device-Credential", credential);
        if (body != null) request.contentType(MediaType.APPLICATION_JSON).content(mapper.writeValueAsBytes(body));
        var response = mvc.perform(request).andReturn().getResponse();
        JsonNode envelope = mapper.readTree(response.getContentAsString(java.nio.charset.StandardCharsets.UTF_8));
        assertEquals(expected, response.getStatus(), method + " " + path + ": " + envelope.path("message"));
        return envelope;
    }

    long register() throws Exception {
        credential = "acceptance-" + UUID.randomUUID();
        device = api(employeeUser, "POST", "/attendance/devices/register", Map.of(
                "deviceFingerprint", credential, "deviceLabel", "Acceptance Android", "platform", "ANDROID"), 201)
                .path("data").path("deviceId").asLong();
        return device;
    }

    void activeDevice() throws Exception {
        register();
        api(manager, "POST", "/attendance/devices/" + device + "/approve", Map.of(), 200);
    }

    long assign(LocalDate date) throws Exception {
        return api(manager, "POST", "/shift-assignments", Map.of("employeeId", employee,
                "workShiftId", workShiftId("CA_SANG"), "workDate", date), 201)
                .path("data").path("assignmentId").asLong();
    }

    Map<String, Object> body(long id, boolean checkout) {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put(checkout ? "attendanceId" : "shiftAssignmentId", id);
        body.put("deviceId", device);
        body.put("location", onSite());
        body.put("photoEvidence", uploadPhoto(employee, day));
        body.put("idempotencyKey", UUID.randomUUID().toString());
        return body;
    }
}
