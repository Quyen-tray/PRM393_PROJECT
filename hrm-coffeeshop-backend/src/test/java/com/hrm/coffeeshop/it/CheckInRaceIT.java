package com.hrm.coffeeshop.it;

import com.hrm.coffeeshop.common.BusinessException;
import com.hrm.coffeeshop.common.ErrorCode;
import com.hrm.coffeeshop.common.Roles;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.CheckInRequest;
import com.hrm.coffeeshop.shared.dto.ScheduleDto.AssignmentRequest;
import com.hrm.coffeeshop.shared.service.AttendanceService;
import com.hrm.coffeeshop.shared.service.ShiftService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.Set;
import java.util.concurrent.*;

import static org.junit.jupiter.api.Assertions.*;

/** P1-09 / TC21: hai check-in đồng thời cùng ca chỉ tạo một bản ghi công; request thua nhận mã nghiệp vụ. */
class CheckInRaceIT extends IntegrationTestBase {

    @Autowired ShiftService shifts;
    @Autowired AttendanceService attendance;

    @Test
    void twoConcurrentCheckInsForSameShiftYieldOneRecord() throws Exception {
        long an = employeeIdByCode("NV001");
        long anUser = userIdOfEmployee("NV001");
        long manager = userIdByEmail("baonvchaos@gmail.com");
        long device = activeDeviceId(an);
        int sang = workShiftId("CA_SANG");
        LocalDate day = LocalDate.of(2034, 7, 10);

        loginAs(manager, null, Set.of(Roles.STORE_MANAGER));
        long shiftId = shifts.create(new AssignmentRequest(an, sang, day, null)).assignmentId();
        clock.setAt(vn(2034, 7, 10, 7, 5));

        List<CheckInRequest> requests = List.of(
                new CheckInRequest(shiftId, device, onSite(), uploadPhoto(an, day), null, "race-a"),
                new CheckInRequest(shiftId, device, onSite(), uploadPhoto(an, day), null, "race-b"));

        ExecutorService pool = Executors.newFixedThreadPool(2);
        try {
            CyclicBarrier start = new CyclicBarrier(2);
            List<Future<ErrorCode>> futures = new ArrayList<>();
            for (CheckInRequest r : requests) {
                futures.add(pool.submit(() -> {
                    loginAs(anUser, an, Set.of());
                    start.await(10, TimeUnit.SECONDS);
                    try {
                        attendance.checkIn(r);
                        return null;
                    } catch (BusinessException e) {
                        return e.getCode();
                    }
                }));
            }
            List<ErrorCode> outcomes = new ArrayList<>();
            for (Future<ErrorCode> f : futures) outcomes.add(f.get(30, TimeUnit.SECONDS));

            assertEquals(1, outcomes.stream().filter(Objects::isNull).count(), "Kết quả: " + outcomes);
            assertEquals(ErrorCode.ATTENDANCE_ALREADY_CHECKED_IN,
                    outcomes.stream().filter(Objects::nonNull).findFirst().orElseThrow());
            assertEquals(1, countAttendanceOfShift(shiftId));
        } finally {
            pool.shutdownNow();
        }
    }
}
