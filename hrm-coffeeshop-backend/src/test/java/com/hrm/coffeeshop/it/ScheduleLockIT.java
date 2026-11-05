package com.hrm.coffeeshop.it;

import com.hrm.coffeeshop.common.ErrorCode;
import com.hrm.coffeeshop.common.Roles;
import com.hrm.coffeeshop.shared.dto.PayrollDto.PeriodRequest;
import com.hrm.coffeeshop.shared.dto.ScheduleDto.AssignmentPatch;
import com.hrm.coffeeshop.shared.dto.ScheduleDto.AssignmentRequest;
import com.hrm.coffeeshop.shared.service.AttendanceExceptionService;
import com.hrm.coffeeshop.shared.service.PayrollService;
import com.hrm.coffeeshop.shared.service.ShiftService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.time.LocalDate;
import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;

/** P1-08 / TC25: sau khi kỳ đã chốt, không tạo, sửa hay hủy ca thuộc kỳ đó, kể cả chuyển ca từ ngoài vào kỳ. */
class ScheduleLockIT extends IntegrationTestBase {

    @Autowired ShiftService shifts;
    @Autowired PayrollService payroll;
    @Autowired AttendanceExceptionService exceptions;

    @Test
    void lockedPeriodBlocksCreatePatchAndCancelOfItsShifts() {
        long nv = employeeIdByCode("NV001");
        long manager = userIdByEmail("quanly@hrm.test");
        int sang = workShiftId("CA_SANG");
        String code = "IT-SCHED-2032-05";

        loginAs(manager, null, Set.of(Roles.STORE_MANAGER));
        clock.setAt(vn(2032, 5, 1, 8, 0));
        long inPeriod = shifts.create(new AssignmentRequest(nv, sang, LocalDate.of(2032, 5, 5), null)).assignmentId();
        long outside = shifts.create(new AssignmentRequest(nv, sang, LocalDate.of(2032, 5, 20), null)).assignmentId();
        payroll.create(new PeriodRequest(code, LocalDate.of(2032, 5, 1), LocalDate.of(2032, 5, 10), "it"));
        long periodId = jdbc.queryForObject("SELECT PayrollPeriodId FROM dbo.PayrollPeriod WHERE PeriodCode = ?", Long.class, code);

        // Ca đã kết thúc không có chấm công: cần đơn ABSENCE đã duyệt trước khi chốt (DEC-ABS).
        clock.setAt(vn(2032, 5, 11, 9, 0));
        payroll.generateAbsenceRequests(periodId);
        Long absenceId = jdbc.queryForList(
                "SELECT ExceptionRequestId FROM dbo.AttendanceExceptionRequest WHERE ShiftAssignmentId = ? AND RequestType = 'ABSENCE'",
                Long.class, inPeriod).get(0);
        exceptions.approve(absenceId, "xác nhận vắng mặt");
        payroll.managerConfirm(periodId);
        payroll.hrFinalize(periodId);
        assertEquals("LOCKED", jdbc.queryForObject(
                "SELECT PeriodStatus FROM dbo.PayrollPeriod WHERE PayrollPeriodId = ?", String.class, periodId));

        assertRejected(() -> shifts.create(new AssignmentRequest(nv, sang, LocalDate.of(2032, 5, 7), null)),
                ErrorCode.PAYROLL_PERIOD_LOCKED);
        assertRejected(() -> shifts.patch(inPeriod, new AssignmentPatch(null, LocalDate.of(2032, 5, 6), null)),
                ErrorCode.PAYROLL_PERIOD_LOCKED);
        assertRejected(() -> shifts.cancel(inPeriod, "thử hủy"), ErrorCode.PAYROLL_PERIOD_LOCKED);

        // Không được lách bằng cách chuyển ca từ ngoài kỳ vào kỳ đã khóa.
        assertRejected(() -> shifts.patch(outside, new AssignmentPatch(null, LocalDate.of(2032, 5, 7), null)),
                ErrorCode.PAYROLL_PERIOD_LOCKED);

        // Đối chứng: ca ngoài kỳ vẫn sửa được.
        assertDoesNotThrow(() -> shifts.patch(outside, new AssignmentPatch(null, LocalDate.of(2032, 5, 21), null)));
    }
}
