package com.hrm.coffeeshop.it;

import com.fasterxml.jackson.databind.JsonNode;
import com.hrm.coffeeshop.job.ReminderJob;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;

import java.time.OffsetDateTime;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

@AutoConfigureMockMvc
class AttendanceReadinessIT extends AttendanceFlowSupport {
    @Autowired ReminderJob reminders;

    @Test void adminSettingsDriveNewShiftDeviceAttendanceRetentionRemindersAndApprovedOt() throws Exception {
        JsonNode original = api(admin, "GET", "/admin/store-settings", null, 200).path("data");
        Map<String, Object> restore = mapper.convertValue(original, Map.class);
        restore.putAll(mapper.convertValue(original.path("store"), Map.class));
        try {
            api(employeeUser, "PATCH", "/admin/store-settings", Map.of("attendanceRadiusMeters", 40), 403);
            api(admin, "PATCH", "/admin/store-settings", Map.ofEntries(
                    Map.entry("latitude", 21.0278), Map.entry("longitude", 105.8342), Map.entry("attendanceRadiusMeters", 40),
                    Map.entry("checkInEarlyMinutes", 20), Map.entry("graceMinutes", 4), Map.entry("monthlyGraceLimit", 4),
                    Map.entry("photoRetentionMonths", 6), Map.entry("gpsMaxAccuracyMeters", 25),
                    Map.entry("shiftReminderMinutes", 25), Map.entry("checklistDueSoonMinutes", 20),
                    Map.entry("lateReminderIntervalMinutes", 3), Map.entry("maxLateReminders", 2)), 200);
            JsonNode template = api(manager, "POST", "/work-shifts", Map.of("shiftCode", "ACC-" + UUID.randomUUID().toString().substring(0, 8),
                    "shiftName", "Ca theo cấu hình", "startTime", "07:00", "endTime", "12:00", "breakMinutes", 0), 201).path("data");
            assertEquals(20, template.path("earlyCheckInMinutes").asInt());
            assertEquals(4, template.path("graceMinutes").asInt());
            long shift = api(manager, "POST", "/shift-assignments", Map.of("employeeId", employee,
                    "workShiftId", template.path("shiftId").asInt(), "workDate", day), 201).path("data").path("assignmentId").asLong();
            api(manager, "PATCH", "/shift-assignments/" + shift, Map.of("note", "Đã điều chỉnh"), 200);
            assertTrue(api(employeeUser, "GET", "/shift-assignments/me?from=" + day + "&to=" + day, null, 200).path("data").toString().contains("Đã điều chỉnh"));
            register();
            at(day, 6, 39);
            JsonNode waiting = api(employeeUser, "GET", "/attendance/me/current?assignmentId=" + shift, null, 200).path("data");
            assertTrue(waiting.path("blockers").toString().contains("DEVICE_PENDING"));
            assertTrue(waiting.path("blockers").toString().contains("CHECK_IN_TOO_EARLY"));
            api(manager, "POST", "/attendance/devices/" + device + "/approve", Map.of(), 200);
            at(day, 6, 40);
            assertTrue(api(employeeUser, "GET", "/attendance/me/current?assignmentId=" + shift, null, 200).path("data").path("canCheckIn").asBoolean());
            reminders.run(); reminders.run();
            assertEquals(1, jdbc.queryForObject("SELECT COUNT(*) FROM dbo.Notification WHERE RelatedEntityType='ShiftAssignment' AND RelatedEntityId=? AND NotificationType='SHIFT_REMINDER'", Integer.class, shift));
            at(day, 7, 3);
            var checkIn = body(shift, false);
            JsonNode entered = api(employeeUser, "POST", "/attendance/check-in", checkIn, 200).path("data");
            long attendance = entered.path("attendanceId").asLong();
            assertTrue(entered.path("graceApplied").asBoolean());
            assertEquals(0, entered.path("lateMinutes").asInt());
            assertEquals(attendance, api(employeeUser, "POST", "/attendance/check-in", checkIn, 200).path("data").path("attendanceId").asLong());
            assertEquals(day.plusMonths(6), jdbc.queryForObject("SELECT RetainUntil FROM dbo.AttendanceVerification WHERE AttendanceId=? AND VerificationType='PHOTO'", java.sql.Date.class, attendance).toLocalDate());
            at(day, 13, 0);
            JsonNode out = api(employeeUser, "POST", "/attendance/check-out", body(attendance, true), 200).path("data");
            assertEquals(357, out.path("presenceMinutes").asLong());
            assertEquals(297, out.path("totalWorkedMinutes").asInt());
            assertEquals(60, out.path("overtimeMinutes").asLong());
            assertEquals(0, out.path("approvedOvertimeMinutes").asInt());
            long overtime = api(employeeUser, "POST", "/attendance/" + attendance + "/overtime-requests", Map.of(
                    "requestedStartAt", day + "T12:00:00+07:00", "requestedEndAt", day + "T13:00:00+07:00", "reason", "Hỗ trợ cuối ca"), 201)
                    .path("data").path("requestId").asLong();
            api(manager, "POST", "/attendance/overtime-requests/" + overtime + "/approve", Map.of(), 200);
            JsonNode saved = api(employeeUser, "GET", "/attendance/" + attendance, null, 200).path("data");
            assertEquals(60, saved.path("approvedOvertimeMinutes").asInt());
            assertEquals(357, saved.path("presenceMinutes").asLong());
            assertEquals(60, saved.path("overtimeMinutes").asLong());
            assertEquals(1, countAttendanceOfShift(shift));
        } finally {
            api(admin, "PATCH", "/admin/store-settings", restore, 200);
        }
    }

    @Test void reinstallationReplacesPendingRequestAndApprovalLeavesOneActiveDevice() throws Exception {
        long abandoned = register();
        long current = register();
        assertNotEquals(abandoned, current);
        assertEquals("REVOKED", api(manager, "GET", "/attendance/devices/" + abandoned, null, 200).path("data").path("status").asText());
        api(manager, "POST", "/attendance/devices/" + current + "/reject", Map.of("reason", "Đăng ký lại đúng máy"), 200);
        assertEquals("REJECTED", api(employeeUser, "GET", "/attendance/devices/current", null, 200).path("data").path("status").asText());
        activeDevice();
        assertEquals(1, jdbc.queryForObject("SELECT COUNT(*) FROM dbo.AttendanceDevice WHERE EmployeeId=? AND Status='ACTIVE'", Integer.class, employee));
        assertEquals("ACTIVE", api(employeeUser, "GET", "/attendance/devices/current", null, 200).path("data").path("status").asText());
    }

    @Test void selectedFutureShiftIsShownAndAnOldOpenAttendanceRemainsAvailableForCheckout() throws Exception {
        activeDevice();
        long current = assign(day);
        long future = assign(day.plusDays(4));
        JsonNode selected = api(employeeUser, "GET", "/attendance/me/current?assignmentId=" + future, null, 200).path("data");
        assertEquals(future, selected.path("shiftAssignmentId").asLong());
        assertFalse(selected.path("canCheckIn").asBoolean());
        assertTrue(selected.path("blockers").toString().contains("CHECK_IN_TOO_EARLY"));
        long attendance = api(employeeUser, "POST", "/attendance/check-in", body(current, false), 200).path("data").path("attendanceId").asLong();
        at(day.plusDays(3), 7, 0);
        JsonNode open = api(employeeUser, "GET", "/attendance/me/current", null, 200).path("data");
        assertEquals(current, open.path("shiftAssignmentId").asLong());
        assertEquals(attendance, open.path("attendanceId").asLong());
        assertTrue(open.path("canCheckOut").asBoolean());
        api(employeeUser, "POST", "/attendance/check-out", body(attendance, true), 200);
    }

    @Test void mockedGpsAndReusedPhotoCannotCreateOrCompleteAttendance() throws Exception {
        activeDevice();
        long shift = assign(day);
        var checkIn = body(shift, false);
        checkIn.put("location", Map.of("latitude", 21.0278, "longitude", 105.8342, "accuracyMeters", 5,
                "capturedAt", clock.instant(), "isMocked", true));
        assertEquals("GPS_MOCKED", api(employeeUser, "POST", "/attendance/check-in", checkIn, 422).path("error").path("code").asText());
        assertEquals(0, countAttendanceOfShift(shift));
        checkIn.put("location", onSite());
        long attendance = api(employeeUser, "POST", "/attendance/check-in", checkIn, 200).path("data").path("attendanceId").asLong();
        at(day, 12, 0);
        var checkout = body(attendance, true);
        checkout.put("photoEvidence", checkIn.get("photoEvidence"));
        assertEquals("PHOTO_ALREADY_USED", api(employeeUser, "POST", "/attendance/check-out", checkout, 422).path("error").path("code").asText());
        checkout.put("photoEvidence", uploadPhoto(employee, day));
        api(employeeUser, "POST", "/attendance/check-out", checkout, 200);
        api(employeeUser, "POST", "/attendance/check-out", checkout, 200);
        assertEquals(8, jdbc.queryForObject("SELECT COUNT(*) FROM dbo.AttendanceVerification WHERE AttendanceId=?", Integer.class, attendance));
        assertEquals(0, jdbc.queryForObject("SELECT COUNT(*) FROM dbo.AttendanceVerification WHERE AttendanceId=? AND VerificationType='FACE_LIVENESS' AND VerificationStatus='PASSED'", Integer.class, attendance));
    }
}
