package com.hrm.coffeeshop.it;

import com.hrm.coffeeshop.common.BusinessException;
import com.hrm.coffeeshop.common.ErrorCode;
import com.hrm.coffeeshop.common.Roles;
import com.hrm.coffeeshop.shared.dto.ScheduleDto.AssignmentRequest;
import com.hrm.coffeeshop.shared.dto.ScheduleDto.AssignmentView;
import com.hrm.coffeeshop.shared.service.AttendanceAdjustmentService;
import com.hrm.coffeeshop.shared.service.AttendanceExceptionService;
import com.hrm.coffeeshop.shared.service.RewardPenaltyService;
import com.hrm.coffeeshop.shared.service.ShiftService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.orm.ObjectOptimisticLockingFailureException;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.*;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Luồng 3 (mở rộng) — Duyệt đồng thời cho ba luồng còn thiếu test: điều chỉnh công, giải trình,
 * thưởng/phạt. Mỗi luồng: hai quản lý cùng duyệt một bản ghi, đúng một người được ghi nhận,
 * người còn lại nhận lỗi có kiểm soát (INVALID_STATE hoặc CONFLICT), không ghi đè.
 *
 * Lưu ý: test dùng tài khoản test có đủ quyền (IntegrationTestBase), nên chỉ kiểm tra khóa lạc quan,
 * không kiểm tra phân quyền. Phân quyền theo tài khoản seed được kiểm tra riêng.
 */
class ApprovalRowVersionConcurrencyIT extends IntegrationTestBase {

    @Autowired ShiftService shifts;
    @Autowired AttendanceAdjustmentService adjustments;
    @Autowired AttendanceExceptionService exceptions;
    @Autowired RewardPenaltyService rewards;

    private record Outcome(long userId, ErrorCode rejectedWith) {
        boolean ok() { return rejectedWith == null; }
    }

    @FunctionalInterface
    private interface ManagerAction {
        void run(long managerUserId) throws Exception;
    }

    /** Chạy đồng thời hành động duyệt của từng quản lý (xuất phát cùng lúc nhờ barrier). */
    private List<Outcome> raceAsManagers(ManagerAction action, long... managers) throws Exception {
        ExecutorService pool = Executors.newFixedThreadPool(managers.length);
        try {
            CyclicBarrier start = new CyclicBarrier(managers.length);
            List<Future<Outcome>> futures = new ArrayList<>();
            for (long m : managers) {
                futures.add(pool.submit(() -> {
                    loginAs(m, null, Set.of(Roles.STORE_MANAGER));
                    start.await(10, TimeUnit.SECONDS);
                    try {
                        action.run(m);
                        return new Outcome(m, null);
                    } catch (BusinessException e) {
                        return new Outcome(m, e.getCode());
                    } catch (ObjectOptimisticLockingFailureException | DataIntegrityViolationException e) {
                        // Khóa lạc quan (RowVersion) hoặc ràng buộc duy nhất của bản ghi công: đều là xung đột có kiểm soát.
                        return new Outcome(m, ErrorCode.CONFLICT);
                    }
                }));
            }
            List<Outcome> results = new ArrayList<>();
            for (Future<Outcome> f : futures) results.add(f.get(30, TimeUnit.SECONDS));
            return results;
        } finally {
            pool.shutdownNow();
        }
    }

    /** Khẳng định đúng một người thắng và người thua nhận lỗi có kiểm soát. Trả về userId người thắng. */
    private static long assertSingleWinner(List<Outcome> results) {
        List<Outcome> winners = results.stream().filter(Outcome::ok).toList();
        List<Outcome> losers = results.stream().filter(r -> !r.ok()).toList();
        assertEquals(1, winners.size(), "Đúng một người duyệt thành công, kết quả: " + results);
        assertEquals(1, losers.size(), "Đúng một người thua, kết quả: " + results);
        ErrorCode code = losers.get(0).rejectedWith();
        assertTrue(code == ErrorCode.INVALID_STATE || code == ErrorCode.CONFLICT,
                "Người thua phải nhận INVALID_STATE hoặc CONFLICT, nhận: " + code);
        return winners.get(0).userId();
    }

    @Test
    void twoManagersApprovingSameAdjustmentNeverOverwriteEachOther() throws Exception {
        long an = employeeIdByCode("NV001");
        long requester = userIdOfEmployee("NV001");
        long manager1 = userIdByEmail("quanly@hrm.test");
        long manager2 = createUser("it-manager2-adj@hrm.test");
        LocalDate day = LocalDate.of(2033, 6, 10);

        loginAs(manager1, null, Set.of(Roles.STORE_MANAGER));
        AssignmentView shift = shifts.create(new AssignmentRequest(an, workShiftId("CA_SANG"), day, null));
        jdbc.update("INSERT INTO dbo.Attendance (ShiftAssignmentId, EmployeeId, CheckInAt, CheckOutAt) VALUES (?, ?, ?, ?)",
                shift.assignmentId(), an, LocalDateTime.of(2033, 6, 10, 0, 0), LocalDateTime.of(2033, 6, 10, 5, 0));
        long attId = attendanceIdOfShift(shift.assignmentId());
        // Yêu cầu điều chỉnh giờ check-out đang chờ quản lý duyệt (chèn trực tiếp, giờ lưu UTC).
        jdbc.update("INSERT INTO dbo.AttendanceAdjustmentRequest (AttendanceId, RequestedBy, FieldName, NewValue, Reason) "
                + "VALUES (?, ?, 'CHECK_OUT', ?, ?)", attId, requester, "2033-06-10T06:00:00Z", "it");
        long adjId = jdbc.queryForObject(
                "SELECT AttendanceAdjustmentRequestId FROM dbo.AttendanceAdjustmentRequest WHERE AttendanceId = ?",
                Long.class, attId);

        List<Outcome> results = raceAsManagers(m -> adjustments.managerApprove(adjId, "duyệt bởi " + m), manager1, manager2);
        long winner = assertSingleWinner(results);

        Map<String, Object> row = jdbc.queryForMap(
                "SELECT ManagerStatus, ManagerReviewedBy, RowVersion FROM dbo.AttendanceAdjustmentRequest "
                        + "WHERE AttendanceAdjustmentRequestId = ?", adjId);
        assertEquals("APPROVED", row.get("ManagerStatus"));
        assertEquals(winner, ((Number) row.get("ManagerReviewedBy")).longValue(), "Người ghi nhận phải là người thắng");
        assertEquals(1L, ((Number) row.get("RowVersion")).longValue(), "Bản ghi chỉ được ghi đúng một lần");
    }

    @Test
    void twoManagersApprovingSameExceptionCreateOneAttendanceAndOneDecision() throws Exception {
        long an = employeeIdByCode("NV001");
        long manager1 = userIdByEmail("quanly@hrm.test");
        long manager2 = createUser("it-manager2-exc@hrm.test");
        LocalDate day = LocalDate.of(2033, 6, 11);

        loginAs(manager1, null, Set.of(Roles.STORE_MANAGER));
        AssignmentView shift = shifts.create(new AssignmentRequest(an, workShiftId("CA_SANG"), day, null));
        // Đơn giải trình "quên check-in" đang chờ duyệt, chưa có bản ghi công (approve sẽ tạo bản ghi).
        jdbc.update("INSERT INTO dbo.AttendanceExceptionRequest (EmployeeId, ShiftAssignmentId, RequestType, "
                        + "RequestedCheckInAt, RequestedCheckOutAt, Reason, RequestStatus) VALUES (?, ?, 'MISSED_CHECK_IN', ?, ?, 'it', 'PENDING')",
                an, shift.assignmentId(), LocalDateTime.of(2033, 6, 11, 0, 0), LocalDateTime.of(2033, 6, 11, 5, 0));
        long exId = jdbc.queryForObject(
                "SELECT ExceptionRequestId FROM dbo.AttendanceExceptionRequest WHERE ShiftAssignmentId = ?",
                Long.class, shift.assignmentId());

        List<Outcome> results = raceAsManagers(m -> exceptions.approve(exId, "duyệt bởi " + m), manager1, manager2);
        long winner = assertSingleWinner(results);

        assertEquals(1, countAttendanceOfShift(shift.assignmentId()), "Không được tạo hai bản ghi công cho cùng một ca");
        // RowVersion không được khẳng định ở đây: approve gán thêm trường (ReviewedBy...) sau lần flush có khóa,
        // nên giá trị cuối phụ thuộc số lần ghi; điều quan trọng là người thắng là người được ghi nhận.
        Map<String, Object> row = jdbc.queryForMap(
                "SELECT RequestStatus, ReviewedBy FROM dbo.AttendanceExceptionRequest WHERE ExceptionRequestId = ?", exId);
        assertEquals("APPROVED", row.get("RequestStatus"));
        assertEquals(winner, ((Number) row.get("ReviewedBy")).longValue(), "Người ghi nhận phải là người thắng");
    }

    @Test
    void twoManagersApprovingSameRewardDecisionRecordOnlyOne() throws Exception {
        long an = employeeIdByCode("NV001");
        long proposer = createUser("it-proposer-rp@hrm.test");
        long manager1 = userIdByEmail("quanly@hrm.test");
        long manager2 = createUser("it-manager2-rp@hrm.test");

        // Quyết định thưởng đang chờ duyệt (rule OUTSTANDING_ACHIEVEMENT có sẵn trong seed).
        jdbc.update("INSERT INTO dbo.EmployeeRewardPenalty (DecisionType, EmployeeId, RuleId, EffectiveDate, Details, "
                        + "Amount, DecisionStatus, ProposedBy) VALUES ('REWARD', ?, "
                        + "(SELECT RuleId FROM dbo.RuleCatalog WHERE RuleCode = 'OUTSTANDING_ACHIEVEMENT'), ?, 'it', 100000, 'PENDING', ?)",
                an, LocalDateTime.of(2033, 6, 12, 0, 0), proposer);
        long id = jdbc.queryForObject(
                "SELECT RewardPenaltyId FROM dbo.EmployeeRewardPenalty WHERE ProposedBy = ? AND Details = 'it'",
                Long.class, proposer);
        String decisionId = "REWARD-" + id;

        List<Outcome> results = raceAsManagers(m -> rewards.approve(decisionId, "duyệt bởi " + m), manager1, manager2);
        long winner = assertSingleWinner(results);

        Map<String, Object> row = jdbc.queryForMap(
                "SELECT DecisionStatus, ApprovedBy, RowVersion FROM dbo.EmployeeRewardPenalty WHERE RewardPenaltyId = ?", id);
        assertEquals("APPROVED", row.get("DecisionStatus"));
        assertEquals(winner, ((Number) row.get("ApprovedBy")).longValue(), "Người ghi nhận phải là người thắng");
        assertEquals(1L, ((Number) row.get("RowVersion")).longValue(), "Bản ghi chỉ được ghi đúng một lần");
    }
}
