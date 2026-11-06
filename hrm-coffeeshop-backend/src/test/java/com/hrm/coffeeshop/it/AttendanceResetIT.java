package com.hrm.coffeeshop.it;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.dao.DataAccessException;
import org.springframework.jdbc.core.ConnectionCallback;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

@AutoConfigureMockMvc
class AttendanceResetIT extends AttendanceFlowSupport {
    void reset(long id, String employeeCode, boolean cancelAssignment) throws Exception {
        String source = Files.readString(Path.of("infra/sqlserver/reset-attendance.sql"), StandardCharsets.UTF_8);
        String sql = source.substring(source.indexOf("DECLARE @AttendanceId"))
                .replace("DECLARE @AttendanceId BIGINT = NULL;", "DECLARE @AttendanceId BIGINT = ?;")
                .replace("DECLARE @EmployeeCode VARCHAR(30) = NULL;", "DECLARE @EmployeeCode VARCHAR(30) = ?;")
                .replace("DECLARE @CancelAssignment BIT = 1;", "DECLARE @CancelAssignment BIT = ?;");
        jdbc.execute((ConnectionCallback<Void>) connection -> {
            try (var statement = connection.prepareStatement(sql)) {
                statement.setLong(1, id);
                statement.setString(2, employeeCode);
                statement.setBoolean(3, cancelAssignment);
                statement.execute();
            }
            return null;
        });
    }

    long checkIn(long shift) throws Exception {
        return api(employeeUser, "POST", "/attendance/check-in", body(shift, false), 200)
                .path("data").path("attendanceId").asLong();
    }

    @Test void resetCancelsOnlyItsShiftAndManagerCanAssignTheSameTimeAgain() throws Exception {
        activeDevice();
        long shift = assign(day);
        at(day, 7, 15);
        long id = checkIn(shift);
        assertTrue(jdbc.queryForObject("SELECT COUNT(*) FROM dbo.ViolationEvent WHERE AttendanceId=?", Integer.class, id) > 0);
        long otherShift = assign(day.plusDays(2));
        at(day.plusDays(2), 7, 0);
        long otherAttendance = checkIn(otherShift);
        int users = jdbc.queryForObject("SELECT COUNT(*) FROM dbo.AppUser", Integer.class);
        int devices = jdbc.queryForObject("SELECT COUNT(*) FROM dbo.AttendanceDevice", Integer.class);
        String store = jdbc.queryForObject("SELECT CONCAT(Latitude,':',Longitude,':',AttendanceRadiusMeters) FROM dbo.Store WHERE IsActive=1", String.class);
        reset(id, "NV001", true);
        assertEquals(0, countAttendanceOfShift(shift));
        assertEquals(0, jdbc.queryForObject("SELECT COUNT(*) FROM dbo.AttendanceVerification WHERE AttendanceId=?", Integer.class, id));
        assertEquals(0, jdbc.queryForObject("SELECT COUNT(*) FROM dbo.ViolationEvent WHERE AttendanceId=?", Integer.class, id));
        assertEquals("CANCELLED", jdbc.queryForObject("SELECT ScheduleStatus FROM dbo.ShiftAssignment WHERE ShiftAssignmentId=?", String.class, shift));
        assertEquals(otherAttendance, attendanceIdOfShift(otherShift));
        assertEquals("PUBLISHED", jdbc.queryForObject("SELECT ScheduleStatus FROM dbo.ShiftAssignment WHERE ShiftAssignmentId=?", String.class, otherShift));
        assertEquals(users, jdbc.queryForObject("SELECT COUNT(*) FROM dbo.AppUser", Integer.class));
        assertEquals(devices, jdbc.queryForObject("SELECT COUNT(*) FROM dbo.AttendanceDevice", Integer.class));
        assertEquals("ACTIVE", jdbc.queryForObject("SELECT Status FROM dbo.AttendanceDevice WHERE DeviceId=?", String.class, device));
        assertEquals(store, jdbc.queryForObject("SELECT CONCAT(Latitude,':',Longitude,':',AttendanceRadiusMeters) FROM dbo.Store WHERE IsActive=1", String.class));
        assertEquals(1, jdbc.queryForObject("SELECT COUNT(*) FROM dbo.AuditLog WHERE ActionCode='DEV_ATTENDANCE_RESET' AND EntityId=?", Integer.class, String.valueOf(id)));
        assertNotEquals(shift, assign(day));
    }

    @Test void keepingAssignmentAllowsCheckInAgainOnTheSameShift() throws Exception {
        activeDevice();
        long shift = assign(day);
        long previous = checkIn(shift);
        reset(previous, "NV001", false);
        assertEquals("PUBLISHED", jdbc.queryForObject("SELECT ScheduleStatus FROM dbo.ShiftAssignment WHERE ShiftAssignmentId=?", String.class, shift));
        long next = checkIn(shift);
        assertNotEquals(previous, next);
        assertEquals(1, countAttendanceOfShift(shift));
    }

    @Test void wrongEmployeeCannotResetSomeoneElsesAttendance() throws Exception {
        activeDevice();
        long shift = assign(day);
        long id = checkIn(shift);
        assertThrows(DataAccessException.class, () -> reset(id, "NV002", true));
        assertEquals(id, attendanceIdOfShift(shift));
        assertEquals("PUBLISHED", jdbc.queryForObject("SELECT ScheduleStatus FROM dbo.ShiftAssignment WHERE ShiftAssignmentId=?", String.class, shift));
    }

    @Test void reviewedAttendanceIsPreserved() throws Exception {
        activeDevice();
        long shift = assign(day);
        long id = checkIn(shift);
        jdbc.update("UPDATE dbo.Attendance SET PayrollStatus='LOCKED' WHERE AttendanceId=?", id);
        assertThrows(DataAccessException.class, () -> reset(id, "NV001", true));
        assertEquals(id, attendanceIdOfShift(shift));
        assertEquals("LOCKED", jdbc.queryForObject("SELECT PayrollStatus FROM dbo.Attendance WHERE AttendanceId=?", String.class, id));
    }

    @Test void linkedOvertimeIsPreservedWithItsAttendance() throws Exception {
        activeDevice();
        long shift = assign(day);
        long id = checkIn(shift);
        long overtime = api(employeeUser, "POST", "/attendance/" + id + "/overtime-requests", Map.of(
                "requestedStartAt", day + "T12:00:00+07:00", "requestedEndAt", day + "T13:00:00+07:00", "reason", "Giữ nghiệp vụ OT"), 201)
                .path("data").path("requestId").asLong();
        assertThrows(DataAccessException.class, () -> reset(id, "NV001", true));
        assertEquals(id, attendanceIdOfShift(shift));
        assertEquals(1, jdbc.queryForObject("SELECT COUNT(*) FROM dbo.OvertimeRequest WHERE OvertimeRequestId=?", Integer.class, overtime));
    }
}
