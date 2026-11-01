package com.hrm.coffeeshop.it;

import com.hrm.coffeeshop.common.BusinessException;
import com.hrm.coffeeshop.common.ErrorCode;
import com.hrm.coffeeshop.common.Roles;
import com.hrm.coffeeshop.shared.dto.ScheduleDto.AssignmentRequest;
import com.hrm.coffeeshop.shared.dto.ScheduleDto.AssignmentView;
import com.hrm.coffeeshop.shared.service.OvertimeService;
import com.hrm.coffeeshop.shared.service.ShiftService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.orm.ObjectOptimisticLockingFailureException;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.concurrent.*;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Luồng 3 — Duyệt đồng thời.
 * Hai quản lý cùng duyệt một yêu cầu OT: đúng một người ghi được quyết định,
 * người còn lại nhận lỗi có kiểm soát (INVALID_STATE hoặc CONFLICT), không ghi đè.
 */
class OvertimeApprovalConcurrencyIT extends IntegrationTestBase {

    @Autowired ShiftService shifts;
    @Autowired OvertimeService overtime;

    private record Outcome(long userId, ErrorCode rejectedWith) {
        boolean ok() { return rejectedWith == null; }
    }

    @Test
    void twoManagersApprovingSameOvertimeNeverOverwriteEachOther() throws Exception {
        long an = employeeIdByCode("NV001");
        long manager1 = userIdByEmail("quanly@hrm.test");
        long manager2 = createUser("it-manager2-ot@hrm.test");
        LocalDate day = LocalDate.of(2033, 5, 10);

        loginAs(manager1, null, Set.of(Roles.STORE_MANAGER));
        AssignmentView shift = shifts.create(new AssignmentRequest(an, workShiftId("CA_SANG"), day, null));

        // Yêu cầu OT ở trạng thái PENDING (chèn trực tiếp, giờ lưu UTC). 12:00–13:00 VN = 05:00–06:00 UTC.
        jdbc.update("INSERT INTO dbo.OvertimeRequest (ShiftAssignmentId, EmployeeId, RequestedStartAt, RequestedEndAt, Reason) VALUES (?, ?, ?, ?, ?)",
                shift.assignmentId(), an,
                LocalDateTime.of(2033, 5, 10, 5, 0), LocalDateTime.of(2033, 5, 10, 6, 0), "it");
        long otId = jdbc.queryForObject(
                "SELECT OvertimeRequestId FROM dbo.OvertimeRequest WHERE ShiftAssignmentId = ?",
                Long.class, shift.assignmentId());

        ExecutorService pool = Executors.newFixedThreadPool(2);
        try {
            CyclicBarrier start = new CyclicBarrier(2);
            List<Future<Outcome>> futures = new ArrayList<>();
            for (long manager : List.of(manager1, manager2)) {
                futures.add(pool.submit(() -> {
                    loginAs(manager, null, Set.of(Roles.STORE_MANAGER));
                    start.await(10, TimeUnit.SECONDS);
                    try {
                        overtime.approve(otId, "duyệt bởi " + manager);
                        return new Outcome(manager, null);
                    } catch (BusinessException e) {
                        return new Outcome(manager, e.getCode());
                    } catch (ObjectOptimisticLockingFailureException e) {
                        return new Outcome(manager, ErrorCode.CONFLICT);
                    }
                }));
            }
            List<Outcome> results = new ArrayList<>();
            for (Future<Outcome> f : futures) results.add(f.get(30, TimeUnit.SECONDS));

            List<Outcome> winners = results.stream().filter(Outcome::ok).toList();
            List<Outcome> losers = results.stream().filter(r -> !r.ok()).toList();
            assertEquals(1, winners.size(), "Đúng một người duyệt thành công, kết quả: " + results);
            assertEquals(1, losers.size());
            ErrorCode loserCode = losers.get(0).rejectedWith();
            assertTrue(loserCode == ErrorCode.INVALID_STATE || loserCode == ErrorCode.CONFLICT,
                    "Người thua phải nhận INVALID_STATE hoặc CONFLICT, nhận: " + loserCode);

            // Trạng thái trong DB phải là quyết định của người thắng, và chỉ được ghi đúng một lần.
            String status = jdbc.queryForObject("SELECT ApprovalStatus FROM dbo.OvertimeRequest WHERE OvertimeRequestId = ?",
                    String.class, otId);
            long reviewedBy = jdbc.queryForObject("SELECT ReviewedBy FROM dbo.OvertimeRequest WHERE OvertimeRequestId = ?",
                    Long.class, otId);
            long rowVersion = jdbc.queryForObject("SELECT RowVersion FROM dbo.OvertimeRequest WHERE OvertimeRequestId = ?",
                    Long.class, otId);
            assertEquals("APPROVED", status);
            assertEquals(winners.get(0).userId(), reviewedBy, "Người ghi nhận phải là người thắng");
            assertEquals(1L, rowVersion, "Bản ghi phải được ghi đúng một lần (RowVersion = 1)");
        } finally {
            pool.shutdownNow();
        }
    }
}
