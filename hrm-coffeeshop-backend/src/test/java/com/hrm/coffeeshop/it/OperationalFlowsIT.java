package com.hrm.coffeeshop.it;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.hrm.coffeeshop.config.JwtService;
import com.hrm.coffeeshop.job.ReminderJob;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.*;

/** Real role guards, controllers, storage, reminders and SQL Server; no mocked business beans. */
@AutoConfigureMockMvc
class OperationalFlowsIT extends IntegrationTestBase {
    private static final AtomicInteger DAYS = new AtomicInteger();
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper mapper;
    @Autowired JwtService jwt;
    @Autowired ReminderJob reminders;
    long employee, employeeUser, manager, admin, device;
    LocalDate day;
    String credential;

    @BeforeEach void actors() {
        employee = employeeIdByCode("NV001");
        employeeUser = userIdOfEmployee("NV001");
        manager = userIdByEmail("baonvchaos@gmail.com");
        admin = jdbc.queryForObject("SELECT TOP (1) ur.UserId FROM dbo.UserRole ur JOIN dbo.Role r ON r.RoleId=ur.RoleId WHERE r.RoleCode='SYSTEM_ADMIN' ORDER BY ur.UserId", Long.class);
        day = LocalDate.of(2048, 1, 1).plusDays(DAYS.addAndGet(120));
        at(day, 7, 5);
    }

    void at(LocalDate date, int hour, int minute) {
        clock.setAt(date.atTime(hour, minute).atZone(VN).toInstant());
    }

    JsonNode api(long actor, String method, String path, Object body, int expected, String installation) throws Exception {
        var request = MockMvcRequestBuilders.request(HttpMethod.valueOf(method), "/api/v1" + path)
                .header("Authorization", "Bearer " + jwt.createAccessToken(actor));
        if (installation != null) request.header("X-Device-Credential", installation);
        if (body != null) request.contentType(MediaType.APPLICATION_JSON).content(mapper.writeValueAsBytes(body));
        var response = mvc.perform(request).andReturn().getResponse();
        JsonNode envelope = mapper.readTree(response.getContentAsString());
        assertEquals(expected, response.getStatus(), method + " " + path + ": " + envelope.path("message"));
        return envelope;
    }

    JsonNode api(long actor, String method, String path, Object body, int expected) throws Exception {
        return api(actor, method, path, body, expected, null);
    }

    JsonNode assignment(LocalDate date) throws Exception {
        return api(manager, "POST", "/shift-assignments", Map.of("employeeId", employee,
                "workShiftId", workShiftId("CA_SANG"), "workDate", date.toString()), 201).path("data");
    }

    long attendanceShift() throws Exception {
        credential = "flow-installation-" + UUID.randomUUID();
        device = api(employeeUser, "POST", "/attendance/devices/register", Map.of("deviceFingerprint", credential,
                "platform", "ANDROID", "deviceLabel", "Operational flow device"), 201).path("data").path("deviceId").asLong();
        api(manager, "POST", "/attendance/devices/" + device + "/approve", Map.of(), 200);
        return assignment(day).path("assignmentId").asLong();
    }

    Map<String, Object> attendanceBody(long id, boolean checkout, boolean photo) {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put(checkout ? "attendanceId" : "shiftAssignmentId", id);
        body.put("deviceId", device);
        body.put("location", onSite());
        body.put("idempotencyKey", UUID.randomUUID().toString());
        if (photo) body.put("photoEvidence", uploadPhoto(employee, day));
        return body;
    }

    @Test void selectedCameraIsEnforcedForBothEventsAndRetriesAreIdempotent() throws Exception {
        long shift = attendanceShift();
        for (int reload = 0; reload < 3; reload++)
            assertTrue(api(employeeUser, "GET", "/attendance/me/current", null, 200, credential)
                    .path("data").path("photoRequired").asBoolean());
        var body = attendanceBody(shift, false, false);
        assertEquals("PHOTO_REQUIRED", api(employeeUser, "POST", "/attendance/check-in", body, 422, credential).path("error").path("code").asText());
        body.put("photoEvidence", Map.of("cameraPermissionGranted", false));
        assertEquals("CAMERA_PERMISSION_DENIED", api(employeeUser, "POST", "/attendance/check-in", body, 422, credential).path("error").path("code").asText());
        body.put("photoEvidence", uploadPhoto(employee, day));
        long attendanceId = api(employeeUser, "POST", "/attendance/check-in", body, 200, credential).path("data").path("attendanceId").asLong();
        assertEquals(attendanceId, api(employeeUser, "POST", "/attendance/check-in", body, 200, credential).path("data").path("attendanceId").asLong());
        at(day, 11, 0);
        var checkout = attendanceBody(attendanceId, true, false);
        assertEquals("PHOTO_REQUIRED", api(employeeUser, "POST", "/attendance/check-out", checkout, 422, credential).path("error").path("code").asText());
        checkout.put("photoEvidence", uploadPhoto(employee, day));
        api(employeeUser, "POST", "/attendance/check-out", checkout, 200, credential);
        api(employeeUser, "POST", "/attendance/check-out", checkout, 200, credential);
        assertEquals(1, countAttendanceOfShift(shift));
        assertEquals(2, jdbc.queryForObject("SELECT COUNT(*) FROM dbo.AttendanceVerification WHERE AttendanceId=? AND VerificationType='PHOTO' AND VerificationStatus='PASSED'", Integer.class, attendanceId));
        assertEquals("CHECKED_OUT", api(manager, "GET", "/attendance/" + attendanceId, null, 200).path("data").path("attendanceStatus").asText());
    }

    @Test void photoIsAlwaysRequiredAndDoesNotWeakenGpsOrInstallationChecks() throws Exception {
        long shift = attendanceShift();
        assertTrue(api(employeeUser, "GET", "/attendance/me/current", null, 200, credential).path("data").path("photoRequired").asBoolean());
        var body = attendanceBody(shift, false, false);
        api(employeeUser, "POST", "/attendance/check-in", body, 422, "another-installation");
        api(employeeUser, "POST", "/attendance/check-in", body, 422);
        assertEquals("PHOTO_REQUIRED", api(employeeUser, "POST", "/attendance/check-in", body, 422, credential).path("error").path("code").asText());
        assertEquals(0, countAttendanceOfShift(shift));
        body.put("photoEvidence", uploadPhoto(employee, day));
        long attendanceId = api(employeeUser, "POST", "/attendance/check-in", body, 200, credential).path("data").path("attendanceId").asLong();
        at(day, 11, 0);
        var checkout = attendanceBody(attendanceId, true, false);
        assertEquals("PHOTO_REQUIRED", api(employeeUser, "POST", "/attendance/check-out", checkout, 422, credential).path("error").path("code").asText());
        checkout.put("photoEvidence", uploadPhoto(employee, day));
        api(employeeUser, "POST", "/attendance/check-out", checkout, 200, credential);
        assertEquals(2, jdbc.queryForObject("SELECT COUNT(*) FROM dbo.AttendanceVerification WHERE AttendanceId=? AND VerificationType='PHOTO' AND VerificationStatus='PASSED'", Integer.class, attendanceId));
    }

    @ParameterizedTest
    @CsvSource({"MISSING,GPS_UNAVAILABLE", "FAR,GPS_OUT_OF_RANGE", "STALE,GPS_STALE", "INACCURATE,GPS_ACCURACY_INSUFFICIENT"})
    void invalidGpsCannotCreateAttendance(String kind, String expectedCode) throws Exception {
        long shift = attendanceShift();
        var body = attendanceBody(shift, false, false);
        Object location = switch (kind) {
            case "MISSING" -> null;
            case "FAR" -> Map.of("latitude", 21.5, "longitude", 105.8342, "accuracyMeters", 5, "capturedAt", clock.instant());
            case "STALE" -> Map.of("latitude", 21.0278, "longitude", 105.8342, "accuracyMeters", 5, "capturedAt", clock.instant().minusSeconds(300));
            default -> Map.of("latitude", 21.0278, "longitude", 105.8342, "accuracyMeters", 500, "capturedAt", clock.instant());
        };
        body.put("location", location);
        assertEquals(expectedCode, api(employeeUser, "POST", "/attendance/check-in", body, 422, credential).path("error").path("code").asText());
        assertEquals(0, countAttendanceOfShift(shift));
    }

    JsonNode checklist(String type, long schedule, LocalDate date) throws Exception {
        long template = api(admin, "POST", "/admin/checklist-templates", Map.of(
                "checklistCode", "FLOW-" + UUID.randomUUID().toString().substring(0, 8), "checklistName", "Dọn dẹp " + type,
                "checklistType", type, "managerApprovalRequired", true, "isActive", true,
                "items", java.util.List.of(Map.of("itemName", "Lau sạch quầy", "isRequired", true, "requiresEvidence", true, "sortOrder", 1))), 201)
                .path("data").path("templateId").asLong();
        return api(manager, "POST", "/checklists/instances/generate", Map.of("templateId", template,
                "scheduleId", schedule, "employeeId", employee, "workDate", date.toString()), 201).path("data");
    }

    String checklistPhoto(long owner) {
        String key = "checklist-evidence/" + owner + "/" + UUID.randomUUID() + ".jpg";
        storage.store(key, new byte[]{(byte) 255, (byte) 216, (byte) 255, 0});
        return key;
    }

    @ParameterizedTest @ValueSource(strings = {"OPENING", "CLOSING"})
    void cleaningDeadlineAndOwnerFollowTheAssignedShift(String type) throws Exception {
        JsonNode shift = assignment(day);
        JsonNode task = checklist(type, shift.path("assignmentId").asLong(), day);
        OffsetDateTime expected = OffsetDateTime.parse(shift.path("OPENING".equals(type) ? "plannedStartAt" : "plannedEndAt").asText());
        if ("OPENING".equals(type)) expected = expected.plusMinutes(30);
        assertEquals(expected, OffsetDateTime.parse(task.path("dueAt").asText()));
        assertEquals(employee, task.path("employeeId").asLong());
        api(manager, "POST", "/checklists/instances/generate", Map.of("templateId", task.path("templateId").asInt(),
                "scheduleId", shift.path("assignmentId").asLong(), "employeeId", employeeIdByCode("NV002"), "workDate", day.toString()), 422);
    }

    @Test void cleaningReviewRequiresRealOwnedEvidenceAndACompleteRedo() throws Exception {
        JsonNode task = checklist("CLOSING", assignment(day).path("assignmentId").asLong(), day);
        long id = task.path("taskId").asLong();
        long item = task.path("items").get(0).path("runItemId").asLong();
        String path = "/checklists/tasks/" + id;
        api(employeeUser, "POST", path + "/start", Map.of(), 200);
        api(employeeUser, "POST", path + "/submit", Map.of(), 400);
        api(employeeUser, "POST", path + "/items/" + item + "/complete", Map.of("evidenceStorageKey", "checklist-evidence/" + employee + "/" + UUID.randomUUID() + ".jpg"), 400);
        api(employeeUser, "POST", path + "/items/" + item + "/complete", Map.of("evidenceStorageKey", checklistPhoto(employeeIdByCode("NV002"))), 403);
        String originalPhoto = checklistPhoto(employee);
        api(employeeUser, "POST", path + "/items/" + item + "/complete", Map.of("evidenceStorageKey", originalPhoto), 200);
        api(employeeUser, "POST", path + "/submit", Map.of(), 200);
        api(employeeUser, "POST", path + "/approve", Map.of(), 403);
        clock.setAt(clock.instant().plusSeconds(1));
        JsonNode rejected = api(manager, "POST", path + "/reject", Map.of("reason", "Còn bẩn, chụp lại sau khi lau"), 200).path("data");
        assertFalse(rejected.path("items").get(0).path("isCompleted").asBoolean());
        assertFalse(rejected.path("items").get(0).path("hasEvidence").asBoolean());
        api(employeeUser, "POST", path + "/start", Map.of(), 200);
        api(employeeUser, "POST", path + "/submit", Map.of(), 400);
        api(employeeUser, "POST", path + "/items/" + item + "/complete", Map.of(), 422);
        api(employeeUser, "POST", path + "/items/" + item + "/complete", Map.of("evidenceStorageKey", originalPhoto), 422);
        clock.setAt(clock.instant().plusSeconds(1));
        api(employeeUser, "POST", path + "/items/" + item + "/complete", Map.of("evidenceStorageKey", checklistPhoto(employee)), 200);
        api(employeeUser, "POST", path + "/submit", Map.of(), 200);
        assertEquals("APPROVED", api(manager, "POST", path + "/approve", Map.of("note", "Đã sạch"), 200).path("data").path("status").asText());
        assertEquals(2, jdbc.queryForObject("SELECT COUNT(*) FROM dbo.ChecklistEvidence WHERE ChecklistTaskId=?", Integer.class, id));
    }

    int remindersFor(long task, String type) {
        return jdbc.queryForObject("SELECT COUNT(*) FROM dbo.Notification WHERE RelatedEntityType='ChecklistTask' AND RelatedEntityId=? AND NotificationType=?", Integer.class, task, type);
    }

    @Test void remindersAreDeduplicatedStopForSubmissionAndResumeForRejectedWork() throws Exception {
        JsonNode task = checklist("CLOSING", assignment(day).path("assignmentId").asLong(), day);
        long id = task.path("taskId").asLong(), item = task.path("items").get(0).path("runItemId").asLong();
        String path = "/checklists/tasks/" + id;
        var due = OffsetDateTime.parse(task.path("dueAt").asText()).toInstant();
        clock.setAt(due.minusSeconds(600));
        reminders.run(); reminders.run();
        assertEquals(1, remindersFor(id, "CHECKLIST_DUE_SOON"));
        api(employeeUser, "POST", path + "/start", Map.of(), 200);
        api(employeeUser, "POST", path + "/items/" + item + "/complete", Map.of("evidenceStorageKey", checklistPhoto(employee)), 200);
        api(employeeUser, "POST", path + "/submit", Map.of(), 200);
        clock.setAt(due.plusSeconds(360)); reminders.run();
        assertEquals(0, remindersFor(id, "CHECKLIST_OVERDUE"));
        api(manager, "POST", path + "/reject", Map.of("reason", "Cần làm lại"), 200);
        reminders.run(); reminders.run();
        assertEquals(1, remindersFor(id, "CHECKLIST_OVERDUE"));
        clock.setAt(due.plusSeconds(361));
        api(employeeUser, "POST", path + "/start", Map.of(), 200);
        api(employeeUser, "POST", path + "/items/" + item + "/complete", Map.of("evidenceStorageKey", checklistPhoto(employee)), 200);
        api(employeeUser, "POST", path + "/submit", Map.of(), 200);
        api(manager, "POST", path + "/approve", Map.of(), 200);
        clock.setAt(due.plusSeconds(1200)); reminders.run();
        assertEquals(1, remindersFor(id, "CHECKLIST_OVERDUE"));
    }

    @Test void managerChartsCountActivePeopleAndSeparateMissingTrainingFromShiftEligibility() throws Exception {
        JsonNode status = api(manager, "GET", "/dashboard/manager/employee-status", null, 200).path("data");
        int active = jdbc.queryForObject("SELECT COUNT(*) FROM dbo.Employee WHERE EmploymentStatus='ACTIVE'", Integer.class);
        assertEquals(active, status.path("trainingStatus").path("COMPLETE").asInt() + status.path("trainingStatus").path("MISSING").asInt());
        assertTrue(status.path("trainingStatus").path("MISSING").asInt() > 0);
        assertEquals(active, status.path("skillAssessmentStatus").path("ASSESSED").asInt() + status.path("skillAssessmentStatus").path("NOT_ASSESSED").asInt());
        api(employeeUser, "GET", "/dashboard/manager/employee-status", null, 403);
        for (String endpoint : java.util.List.of("overview", "attendance", "operations", "rewards-penalties"))
            assertTrue(api(manager, "GET", "/dashboard/manager/" + endpoint, null, 200).path("success").asBoolean());
    }

    @Test void dailyOperationsReportExcludesMidnightOfTheFollowingDay() throws Exception {
        checklist("CLOSING", assignment(day).path("assignmentId").asLong(), day);
        JsonNode tomorrow = checklist("OPENING", assignment(day.plusDays(1)).path("assignmentId").asLong(), day.plusDays(1));
        jdbc.update("UPDATE dbo.ChecklistTask SET DueAt=? WHERE ChecklistTaskId=?",
                java.sql.Timestamp.from(day.plusDays(1).atStartOfDay(VN).toInstant()), tomorrow.path("taskId").asLong());
        JsonNode data = api(manager, "GET", "/dashboard/manager/operations?from=" + day + "&to=" + day, null, 200).path("data");
        assertEquals(1, data.path("totalChecklists").asInt());
    }

    @Test void overdueRemindersAreSpacedAndViolationFollowsTheLastReminder() throws Exception {
        JsonNode task = checklist("CLOSING", assignment(day).path("assignmentId").asLong(), day);
        long id = task.path("taskId").asLong();
        int interval = jdbc.queryForObject("SELECT IntervalMinutes FROM dbo.ReminderRule WHERE RuleCode='CHECKLIST_OVERDUE'", Integer.class);
        int max = jdbc.queryForObject("SELECT MaxAttempts FROM dbo.ReminderRule WHERE RuleCode='CHECKLIST_OVERDUE'", Integer.class);
        boolean wasEnabled = jdbc.queryForObject("SELECT IsActive FROM dbo.ReminderRule WHERE RuleCode='CHECKLIST_OVERDUE'", Boolean.class);
        clock.setAt(OffsetDateTime.parse(task.path("dueAt").asText()).toInstant().plusSeconds((interval * max + 1L) * 60));
        try {
            jdbc.update("UPDATE dbo.ReminderRule SET IsActive=0 WHERE RuleCode='CHECKLIST_OVERDUE'");
            reminders.run();
            assertEquals(0, remindersFor(id, "CHECKLIST_OVERDUE"));
            assertEquals(0, jdbc.queryForObject("SELECT COUNT(*) FROM dbo.ViolationEvent WHERE ChecklistTaskId=?", Integer.class, id));
            jdbc.update("UPDATE dbo.ReminderRule SET IsActive=1 WHERE RuleCode='CHECKLIST_OVERDUE'");
            reminders.run(); reminders.run();
            assertEquals(1, remindersFor(id, "CHECKLIST_OVERDUE"));
            assertEquals(0, jdbc.queryForObject("SELECT COUNT(*) FROM dbo.ViolationEvent WHERE ChecklistTaskId=? AND RecordStatus='PENDING'", Integer.class, id));
            clock.setAt(clock.instant().plusSeconds(interval * 60L));
            reminders.run();
            assertEquals(2, remindersFor(id, "CHECKLIST_OVERDUE"));
            assertEquals(0, jdbc.queryForObject("SELECT COUNT(*) FROM dbo.ViolationEvent WHERE ChecklistTaskId=? AND RecordStatus='PENDING'", Integer.class, id));
            clock.setAt(clock.instant().plusSeconds(interval * 60L));
            reminders.run();
            assertEquals(max, remindersFor(id, "CHECKLIST_OVERDUE"));
            assertEquals(1, jdbc.queryForObject("SELECT COUNT(*) FROM dbo.ViolationEvent WHERE ChecklistTaskId=? AND RecordStatus='PENDING'", Integer.class, id));
        } finally {
            jdbc.update("UPDATE dbo.ReminderRule SET IsActive=? WHERE RuleCode='CHECKLIST_OVERDUE'", wasEnabled);
        }
    }
}
