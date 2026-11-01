package com.hrm.coffeeshop.it;

import com.hrm.coffeeshop.common.ErrorCode;
import com.hrm.coffeeshop.common.Roles;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.CheckInRequest;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.LocationDto;
import com.hrm.coffeeshop.shared.dto.ScheduleDto.AssignmentRequest;
import com.hrm.coffeeshop.shared.service.AttendanceService;
import com.hrm.coffeeshop.shared.service.ShiftService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;

/** B-17: check-in bị từ chối vì ngoài phạm vi GPS vẫn ghi nhận lần thất bại, nhưng không tạo bản ghi công. */
class VerificationAttemptIT extends IntegrationTestBase {

    @Autowired ShiftService shifts;
    @Autowired AttendanceService attendance;

    @Test
    void failedGpsCheckInIsRecordedWithoutAttendance() {
        long an = employeeIdByCode("NV001");
        long anUser = userIdOfEmployee("NV001");
        long manager = userIdByEmail("quanly@hrm.test");
        long device = activeDeviceId(an);
        int sang = workShiftId("CA_SANG");
        LocalDate day = LocalDate.of(2034, 8, 1);

        loginAs(manager, null, Set.of(Roles.STORE_MANAGER));
        long shiftId = shifts.create(new AssignmentRequest(an, sang, day, null)).assignmentId();
        clock.setAt(vn(2034, 8, 1, 7, 5));

        // Vĩ độ lệch khoảng 50 km so với cửa hàng: ngoài bán kính cho phép
        LocationDto far = new LocationDto(21.5, 105.8342, 10.0, OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC));
        loginAs(anUser, an, Set.of());
        assertRejected(() -> attendance.checkIn(new CheckInRequest(shiftId, device, far,
                uploadPhoto(an, day), null, "va-far")), ErrorCode.GPS_OUT_OF_RANGE);

        assertEquals(0, countAttendanceOfShift(shiftId), "Lần thất bại không được tạo bản ghi công");
        assertEquals(1, jdbc.queryForObject(
                "SELECT COUNT(*) FROM dbo.AttendanceVerificationAttempt WHERE EmployeeId = ? AND ShiftAssignmentId = ? "
                        + "AND VerificationType = 'GPS' AND FailureCode = 'GPS_OUT_OF_RANGE' AND EventType = 'CHECK_IN'",
                Integer.class, an, shiftId));
    }
}
