package com.hrm.coffeeshop.it;

import com.hrm.coffeeshop.common.BusinessException;
import com.hrm.coffeeshop.common.ErrorCode;
import com.hrm.coffeeshop.common.Roles;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.CheckInRequest;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.OvertimeRequestDto;
import com.hrm.coffeeshop.shared.dto.ScheduleDto.AssignmentRequest;
import com.hrm.coffeeshop.shared.service.AttendanceService;
import com.hrm.coffeeshop.shared.service.OvertimeService;
import com.hrm.coffeeshop.shared.service.ShiftService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.Set;
import java.util.concurrent.*;

import static org.junit.jupiter.api.Assertions.*;

/**
 * DEC-OT / TC22, TC23: ca 07:00–12:00. OT chỉ từ 12:00 trở đi, không chồng lấn,
 * và hai yêu cầu chồng lấn gửi đồng thời chỉ được một yêu cầu thành công.
 */
class OvertimeRulesIT extends IntegrationTestBase {

    @Autowired ShiftService shifts;
    @Autowired AttendanceService attendance;
    @Autowired OvertimeService overtime;

    private static OffsetDateTime at(int h, int m) {
        return OffsetDateTime.of(2034, 7, 11, h, m, 0, 0, ZoneOffset.ofHours(7));
    }

    @Test
    void overtimeMustStartAfterShiftEndAndMustNotOverlap() throws Exception {
        long an = employeeIdByCode("NV001");
        long anUser = userIdOfEmployee("NV001");
        long manager = userIdByEmail("baonvchaos@gmail.com");
        long device = activeDeviceId(an);
        int sang = workShiftId("CA_SANG");
        LocalDate day = LocalDate.of(2034, 7, 11);

        loginAs(manager, null, Set.of(Roles.STORE_MANAGER));
        long shiftId = shifts.create(new AssignmentRequest(an, sang, day, null)).assignmentId();
        clock.setAt(vn(2034, 7, 11, 7, 5));
        loginAs(anUser, an, Set.of());
        attendance.checkIn(new CheckInRequest(shiftId, device, onSite(), uploadPhoto(an, day), null, "ot-in"));
        long attId = attendanceIdOfShift(shiftId);

        // TC23: bắt đầu trước khi ca kết thúc, khoảng bằng 0, khoảng đảo ngược: đều bị từ chối.
        assertRejected(() -> overtime.create(attId, new OvertimeRequestDto(at(11, 30), at(13, 0), "OT")),
                ErrorCode.VALIDATION_ERROR);
        assertRejected(() -> overtime.create(attId, new OvertimeRequestDto(at(13, 0), at(13, 0), "OT")),
                ErrorCode.VALIDATION_ERROR);
        assertRejected(() -> overtime.create(attId, new OvertimeRequestDto(at(14, 0), at(13, 0), "OT")),
                ErrorCode.VALIDATION_ERROR);

        // TC22: hai yêu cầu chồng lấn gửi đồng thời.
        List<OffsetDateTime[]> windows = List.of(
                new OffsetDateTime[]{at(12, 30), at(13, 30)},
                new OffsetDateTime[]{at(13, 0), at(14, 0)});
        ExecutorService pool = Executors.newFixedThreadPool(2);
        try {
            CyclicBarrier start = new CyclicBarrier(2);
            List<Future<ErrorCode>> futures = new ArrayList<>();
            for (OffsetDateTime[] w : windows) {
                futures.add(pool.submit(() -> {
                    loginAs(anUser, an, Set.of());
                    start.await(10, TimeUnit.SECONDS);
                    try {
                        overtime.create(attId, new OvertimeRequestDto(w[0], w[1], "OT"));
                        return null;
                    } catch (BusinessException e) {
                        return e.getCode();
                    }
                }));
            }
            List<ErrorCode> outcomes = new ArrayList<>();
            for (Future<ErrorCode> f : futures) outcomes.add(f.get(30, TimeUnit.SECONDS));

            assertEquals(1, outcomes.stream().filter(Objects::isNull).count(), "Kết quả: " + outcomes);
            assertEquals(ErrorCode.CONFLICT, outcomes.stream().filter(Objects::nonNull).findFirst().orElseThrow());
            assertEquals(1, jdbc.queryForObject(
                    "SELECT COUNT(*) FROM dbo.OvertimeRequest WHERE ShiftAssignmentId = ?", Integer.class, shiftId));
        } finally {
            pool.shutdownNow();
        }
    }
}
