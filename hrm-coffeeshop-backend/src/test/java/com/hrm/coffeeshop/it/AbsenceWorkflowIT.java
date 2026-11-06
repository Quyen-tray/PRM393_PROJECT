package com.hrm.coffeeshop.it;

import com.hrm.coffeeshop.common.ErrorCode;
import com.hrm.coffeeshop.common.Roles;
import com.hrm.coffeeshop.shared.dto.PayrollDto.Blocker;
import com.hrm.coffeeshop.shared.dto.PayrollDto.PeriodRequest;
import com.hrm.coffeeshop.shared.dto.PayrollDto.ReadinessView;
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

/**
 * DEC-ABS, TC24: ca đã kết thúc không có chấm công chặn chốt cho đến khi có đơn ABSENCE được quản lý duyệt.
 * Một kịch bản tuần tự duy nhất để không phụ thuộc thứ tự chạy test.
 */
class AbsenceWorkflowIT extends IntegrationTestBase {

    @Autowired ShiftService shifts;
    @Autowired PayrollService payroll;
    @Autowired AttendanceExceptionService exceptions;

    private static final String PERIOD_CODE = "IT-ABS-2033-06";

    @Test
    void absenceMustBeGeneratedApprovedOrRejectedBeforeFinalize() {
        long nv = employeeIdByCode("NV001");
        long employeeUser = userIdOfEmployee("NV001");
        long manager = userIdByEmail("baonvchaos@gmail.com");
        int sang = workShiftId("CA_SANG");

        loginAs(manager, null, Set.of(Roles.STORE_MANAGER));
        clock.setAt(vn(2033, 6, 1, 8, 0));
        long s1 = shifts.create(new AssignmentRequest(nv, sang, LocalDate.of(2033, 6, 5), null)).assignmentId();
        long s2 = shifts.create(new AssignmentRequest(nv, sang, LocalDate.of(2033, 6, 6), null)).assignmentId();
        payroll.create(new PeriodRequest(PERIOD_CODE, LocalDate.of(2033, 6, 1), LocalDate.of(2033, 6, 10), "it"));
        long periodId = jdbc.queryForObject(
                "SELECT PayrollPeriodId FROM dbo.PayrollPeriod WHERE PeriodCode = ?", Long.class, PERIOD_CODE);

        // Ca đã kết thúc, chưa ai tạo đơn: readiness phải chặn.
        clock.setAt(vn(2033, 6, 12, 9, 0));
        ReadinessView r1 = payroll.readiness(periodId);
        assertFalse(r1.canFinalize());
        assertTrue(idsOf(r1, "MISSING_ABSENCE_REQUEST").containsAll(List.of(s1, s2)));

        // Nhân viên không được tạo đơn vắng mặt cho chính mình (chỉ quản lý).
        loginAs(employeeUser, nv, Set.of());
        assertRejected(() -> payroll.generateAbsenceRequests(periodId), ErrorCode.PERMISSION_DENIED);

        // Quản lý tạo đơn chờ duyệt; gọi lại không tạo trùng.
        loginAs(manager, null, Set.of(Roles.STORE_MANAGER));
        assertEquals(2, created(payroll.generateAbsenceRequests(periodId)));
        assertEquals(0, created(payroll.generateAbsenceRequests(periodId)));
        ReadinessView r2 = payroll.readiness(periodId);
        assertTrue(idsOf(r2, "PENDING_ABSENCE").containsAll(List.of(s1, s2)));
        assertFalse(idsOf(r2, "MISSING_ABSENCE_REQUEST").contains(s1));

        // s1 được duyệt, s2 bị từ chối.
        exceptions.approve(absenceRequestOf(s1), "xác nhận vắng mặt");
        exceptions.reject(absenceRequestOf(s2), "có chấm công tại quầy, cần kiểm tra");

        ReadinessView r3 = payroll.readiness(periodId);
        assertFalse(anyAbsenceBlocker(r3, s1), "Ca đã duyệt vắng mặt không được chặn");
        assertTrue(idsOf(r3, "REJECTED_ABSENCE").contains(s2));
        assertFalse(r3.canFinalize());
        // Đơn ABSENCE không ghi bản ghi công.
        assertEquals(0, countAttendanceOfShift(s1));
        assertEquals("APPROVED", jdbc.queryForObject(
                "SELECT RequestStatus FROM dbo.AttendanceExceptionRequest WHERE ExceptionRequestId = ?",
                String.class, absenceRequestOf(s1)));

        // Đơn bị từ chối được tạo lại: chỉ ca s2 có đơn mới, ở trạng thái chờ duyệt.
        assertEquals(1, created(payroll.generateAbsenceRequests(periodId)));
        ReadinessView r4 = payroll.readiness(periodId);
        assertTrue(idsOf(r4, "PENDING_ABSENCE").contains(s2));
        assertFalse(idsOf(r4, "REJECTED_ABSENCE").contains(s2));
        assertFalse(anyAbsenceBlocker(r4, s1));
    }

    private static List<Long> idsOf(ReadinessView rd, String type) {
        return rd.blockers().stream().filter(b -> type.equals(b.type()))
                .flatMap(b -> b.ids().stream()).toList();
    }

    private static boolean anyAbsenceBlocker(ReadinessView rd, long shiftId) {
        return idsOf(rd, "MISSING_ABSENCE_REQUEST").contains(shiftId)
                || idsOf(rd, "PENDING_ABSENCE").contains(shiftId)
                || idsOf(rd, "REJECTED_ABSENCE").contains(shiftId);
    }

    private static int created(java.util.Map<String, Object> result) {
        return ((Number) result.get("created")).intValue();
    }

    /** Đơn ABSENCE mới nhất của ca. */
    private long absenceRequestOf(long shiftId) {
        List<Long> ids = jdbc.queryForList(
                "SELECT ExceptionRequestId FROM dbo.AttendanceExceptionRequest "
                        + "WHERE ShiftAssignmentId = ? AND RequestType = 'ABSENCE' ORDER BY ExceptionRequestId DESC",
                Long.class, shiftId);
        assertFalse(ids.isEmpty(), "Chưa có đơn ABSENCE cho ca " + shiftId);
        return ids.get(0);
    }
}
