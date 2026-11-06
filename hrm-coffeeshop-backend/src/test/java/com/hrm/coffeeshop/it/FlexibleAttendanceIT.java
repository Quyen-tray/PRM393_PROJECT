package com.hrm.coffeeshop.it;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;

import static org.junit.jupiter.api.Assertions.*;

@AutoConfigureMockMvc
@SpringBootTest(properties = "app.attendance.flexible-testing-enabled=true")
class FlexibleAttendanceIT extends AttendanceFlowSupport {
    @Test void managerCanAssignOverlappingFullDaysAndEachAssignmentHasOneAttendance() throws Exception {
        activeDevice();
        long first = assign(day), second = assign(day);
        var selected = api(employeeUser, "GET", "/attendance/me/current?assignmentId=" + second, null, 200).path("data");
        assertTrue(selected.path("flexibleTesting").asBoolean());
        assertTrue(selected.path("mockLocationsAllowed").asBoolean());
        assertTrue(selected.path("shiftChoices").size() >= 2);
        assertTrue(selected.path("shiftChoices").toString().contains("\"assignmentId\":" + first));
        assertEquals(day + "T00:00:00+07:00", selected.path("plannedStartAt").asText());
        assertTrue(selected.path("canCheckIn").asBoolean());
        at(day, 0, 1);
        long attendance = api(employeeUser, "POST", "/attendance/check-in", body(second, false), 200).path("data").path("attendanceId").asLong();
        api(employeeUser, "POST", "/attendance/check-out", body(attendance, true), 200);
        api(employeeUser, "POST", "/attendance/check-in", body(second, false), 409);
        long nextAttendance = api(employeeUser, "POST", "/attendance/check-in", body(first, false), 200).path("data").path("attendanceId").asLong();
        api(employeeUser, "POST", "/attendance/check-out", body(nextAttendance, true), 200);
        assertEquals(1, countAttendanceOfShift(second));
        assertEquals(1, countAttendanceOfShift(first));
        assertNotEquals(attendance, nextAttendance);
    }
}
