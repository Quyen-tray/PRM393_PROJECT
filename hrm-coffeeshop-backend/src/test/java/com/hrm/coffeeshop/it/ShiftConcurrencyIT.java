package com.hrm.coffeeshop.it;

import com.hrm.coffeeshop.common.BusinessException;
import com.hrm.coffeeshop.common.ErrorCode;
import com.hrm.coffeeshop.common.Roles;
import com.hrm.coffeeshop.shared.dto.ScheduleDto.AssignmentRequest;
import com.hrm.coffeeshop.shared.service.ShiftService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.concurrent.*;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;

/**
 * Luồng 2 — Phân ca đồng thời.
 * Hai quản lý cùng phân một ca cho cùng nhân viên trong cùng khoảng thời gian:
 * đúng một thao tác thành công, thao tác còn lại bị từ chối với CONFLICT.
 */
class ShiftConcurrencyIT extends IntegrationTestBase {

    @Autowired ShiftService shifts;

    private record Outcome(ErrorCode rejectedWith) {
        boolean ok() { return rejectedWith == null; }
    }

    @Test
    void twoManagersAssigningOverlappingShiftOnlyOneSucceeds() throws Exception {
        long an = employeeIdByCode("NV001");
        long manager1 = userIdByEmail("baonvchaos@gmail.com");
        long manager2 = createUser("it-manager2-shift@hrm.test");
        int sang = workShiftId("CA_SANG");
        LocalDate day = LocalDate.of(2032, 4, 10);

        ExecutorService pool = Executors.newFixedThreadPool(2);
        try {
            CyclicBarrier start = new CyclicBarrier(2);
            List<Future<Outcome>> futures = new ArrayList<>();
            for (long manager : List.of(manager1, manager2)) {
                futures.add(pool.submit(() -> {
                    loginAs(manager, null, Set.of(Roles.STORE_MANAGER));
                    start.await(10, TimeUnit.SECONDS);
                    try {
                        shifts.create(new AssignmentRequest(an, sang, day, "race"));
                        return new Outcome(null);
                    } catch (BusinessException e) {
                        return new Outcome(e.getCode());
                    }
                }));
            }
            List<Outcome> results = new ArrayList<>();
            for (Future<Outcome> f : futures) results.add(f.get(30, TimeUnit.SECONDS));

            long successes = results.stream().filter(Outcome::ok).count();
            assertEquals(1, successes, "Đúng một thao tác phải thành công, kết quả: " + results);
            results.stream().filter(r -> !r.ok())
                    .forEach(r -> assertEquals(ErrorCode.CONFLICT, r.rejectedWith(),
                            "Thao tác thua phải bị từ chối với CONFLICT"));

            Integer rows = jdbc.queryForObject(
                    "SELECT COUNT(*) FROM dbo.ShiftAssignment WHERE EmployeeId = ? AND WorkDate = ? AND ScheduleStatus = 'PUBLISHED'",
                    Integer.class, an, day);
            assertEquals(1, rows, "Trong DB phải chỉ có một ca cho nhân viên vào ngày này");
        } finally {
            pool.shutdownNow();
        }
    }

    @Test
    void nonOverlappingShiftStillAllowedAfterRace() {
        // Đối chứng: khóa theo nhân viên không được chặn việc phân ca hợp lệ (ca chiều không trùng ca sáng).
        long an = employeeIdByCode("NV001");
        long manager = userIdByEmail("baonvchaos@gmail.com");
        LocalDate day = LocalDate.of(2032, 4, 11);
        loginAs(manager, null, Set.of(Roles.STORE_MANAGER));
        assertDoesNotThrow(() -> shifts.create(new AssignmentRequest(an, workShiftId("CA_SANG"), day, null)));
        assertDoesNotThrow(() -> shifts.create(new AssignmentRequest(an, workShiftId("CA_CHIEU"), day, null)));
    }
}
