package com.hrm.coffeeshop.it;

import com.hrm.coffeeshop.common.ErrorCode;
import com.hrm.coffeeshop.common.Roles;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.AdjustmentRequest;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.CheckInRequest;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.CheckOutRequest;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.ExplanationRequest;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.OvertimeRequestDto;
import com.hrm.coffeeshop.shared.dto.PayrollDto.PeriodRequest;
import com.hrm.coffeeshop.shared.dto.ScheduleDto.AssignmentRequest;
import com.hrm.coffeeshop.shared.dto.ScheduleDto.AssignmentView;
import com.hrm.coffeeshop.shared.service.AttendanceAdjustmentService;
import com.hrm.coffeeshop.shared.service.AttendanceExceptionService;
import com.hrm.coffeeshop.shared.service.AttendanceService;
import com.hrm.coffeeshop.shared.service.OvertimeService;
import com.hrm.coffeeshop.shared.service.PayrollService;
import com.hrm.coffeeshop.shared.service.ShiftService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;

/**
 * Luồng 1 — Chốt kỳ công (SRS 8.5, D-09).
 * Sau khi kỳ LOCKED, mọi thao tác làm thay đổi công của ca thuộc kỳ phải bị từ chối.
 * Ca ngoài kỳ vẫn phải hoạt động bình thường (đối chứng, tránh chặn quá mức).
 */
class PayrollLockIT extends IntegrationTestBase {

    @Autowired ShiftService shifts;
    @Autowired AttendanceService attendance;
    @Autowired OvertimeService overtime;
    @Autowired AttendanceAdjustmentService adjustments;
    @Autowired AttendanceExceptionService exceptions;
    @Autowired PayrollService payroll;

    private static final LocalDate D1 = LocalDate.of(2031, 3, 5);    // ca đã check-in và check-out
    private static final LocalDate D2 = LocalDate.of(2031, 3, 6);    // ca trong kỳ, chưa check-in
    private static final LocalDate DOUT = LocalDate.of(2031, 3, 20); // ca ngoài kỳ (đối chứng)
    private static final String PERIOD_CODE = "IT-LOCK-2031-03";

    @Test
    void lockedPeriodRejectsEveryChangeToItsShifts() {
        long an = employeeIdByCode("NV001");
        long anUser = userIdOfEmployee("NV001");
        long manager = userIdByEmail("quanly@hrm.test");
        long device = activeDeviceId(an);
        int sang = workShiftId("CA_SANG");

        // 1. Tạo ca trước khi chốt (quản lý).
        loginAs(manager, null, Set.of(Roles.STORE_MANAGER));
        AssignmentView shiftD1 = shifts.create(new AssignmentRequest(an, sang, D1, null));
        AssignmentView shiftD2 = shifts.create(new AssignmentRequest(an, sang, D2, null));
        AssignmentView shiftOut = shifts.create(new AssignmentRequest(an, sang, DOUT, null));

        // 2. Nhân viên check-in/check-out ca D1 hợp lệ (trước khi chốt).
        loginAs(anUser, an, Set.of());
        clock.setAt(vn(2031, 3, 5, 7, 5));
        attendance.checkIn(new CheckInRequest(shiftD1.assignmentId(), device, onSite(),
                uploadPhoto(an, D1), null, "it-in-d1"));
        long attD1 = attendanceIdOfShift(shiftD1.assignmentId());
        clock.setAt(vn(2031, 3, 5, 12, 10));
        attendance.checkOut(new CheckOutRequest(attD1, device, onSite(), uploadPhoto(an, D1), null, "it-out-d1"));

        // 3. Quản lý xác nhận, HR chốt sau khi kỳ đã kết thúc.
        clock.setAt(vn(2031, 3, 11, 9, 0));
        loginAs(manager, null, Set.of(Roles.STORE_MANAGER));
        payroll.create(new PeriodRequest(PERIOD_CODE, LocalDate.of(2031, 3, 1), LocalDate.of(2031, 3, 10), "it"));
        long periodId = jdbc.queryForObject(
                "SELECT PayrollPeriodId FROM dbo.PayrollPeriod WHERE PeriodCode = ?", Long.class, PERIOD_CODE);
        // DEC-ABS: ca D2 đã kết thúc nhưng không có chấm công, phải có đơn ABSENCE đã duyệt trước khi chốt.
        payroll.generateAbsenceRequests(periodId);
        exceptions.approve(jdbc.queryForObject(
                "SELECT TOP 1 ExceptionRequestId FROM dbo.AttendanceExceptionRequest WHERE ShiftAssignmentId = ? AND RequestType = 'ABSENCE'",
                Long.class, shiftD2.assignmentId()), "IT xác nhận vắng mặt D2");
        payroll.managerConfirm(periodId);
        payroll.hrFinalize(periodId);
        assertEquals("LOCKED", jdbc.queryForObject(
                "SELECT PeriodStatus FROM dbo.PayrollPeriod WHERE PayrollPeriodId = ?", String.class, periodId));

        // 4. Mọi thao tác thay đổi công của ca trong kỳ đã chốt phải bị từ chối.
        loginAs(anUser, an, Set.of());

        // 4a. Check-in ca D2 (chưa có bản ghi công) — đây là lỗ hổng gốc đã sửa.
        clock.setAt(vn(2031, 3, 6, 7, 5));
        assertRejected(() -> attendance.checkIn(new CheckInRequest(shiftD2.assignmentId(), device, onSite(),
                uploadPhoto(an, D2), null, "it-in-d2")), ErrorCode.PAYROLL_PERIOD_LOCKED);
        assertEquals(0, countAttendanceOfShift(shiftD2.assignmentId()),
                "Check-in bị từ chối nhưng vẫn tạo bản ghi công");

        // 4b. Check-out của ca D1. Ca đã check-out nên đưa bản ghi về trạng thái "đang làm" để
        //     kiểm tra đúng nhánh chặn của guard (mô phỏng dữ liệu bị mở lại không nhất quán).
        jdbc.update("UPDATE dbo.Attendance SET CheckOutAt = NULL WHERE AttendanceId = ?", attD1);
        assertRejected(() -> attendance.checkOut(new CheckOutRequest(attD1, device, onSite(),
                uploadPhoto(an, D1), null, "it-out-locked")), ErrorCode.PAYROLL_PERIOD_LOCKED);

        // 4c. Xin OT trên bản ghi đã chốt.
        OffsetDateTime otStart = OffsetDateTime.of(2031, 3, 5, 12, 30, 0, 0, ZoneOffset.ofHours(7));
        assertRejected(() -> overtime.create(attD1, new OvertimeRequestDto(otStart, otStart.plusHours(1), "OT")),
                ErrorCode.ATTENDANCE_LOCKED, ErrorCode.PAYROLL_PERIOD_LOCKED);

        // 4d. Điều chỉnh công trên bản ghi đã chốt.
        assertRejected(() -> adjustments.create(new AdjustmentRequest(attD1, "FORGOT", "quên check-out",
                null, OffsetDateTime.of(2031, 3, 5, 12, 5, 0, 0, ZoneOffset.ofHours(7)), null)),
                ErrorCode.ATTENDANCE_LOCKED, ErrorCode.PAYROLL_PERIOD_LOCKED);

        // 4e. Giải trình cho ca D2 (chưa có bản ghi công) — phải bị guard theo ngày chặn.
        assertRejected(() -> exceptions.create(null, new ExplanationRequest("MISSED_CHECK_IN", "quên check-in",
                        null, null,
                        OffsetDateTime.of(2031, 3, 6, 7, 0, 0, 0, ZoneOffset.ofHours(7)),
                        OffsetDateTime.of(2031, 3, 6, 12, 0, 0, 0, ZoneOffset.ofHours(7)),
                        shiftD2.assignmentId())),
                ErrorCode.PAYROLL_PERIOD_LOCKED);

        // 5. Đối chứng: ca ngoài kỳ vẫn chấm công được.
        clock.setAt(vn(2031, 3, 20, 7, 5));
        assertDoesNotThrow(() -> attendance.checkIn(new CheckInRequest(shiftOut.assignmentId(), device, onSite(),
                uploadPhoto(an, DOUT), null, "it-in-out")));
    }
}
