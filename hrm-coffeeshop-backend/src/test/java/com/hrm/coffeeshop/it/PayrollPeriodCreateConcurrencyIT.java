package com.hrm.coffeeshop.it;

import com.hrm.coffeeshop.common.BusinessException;
import com.hrm.coffeeshop.common.ErrorCode;
import com.hrm.coffeeshop.common.Roles;
import com.hrm.coffeeshop.shared.dto.PayrollDto.PeriodRequest;
import com.hrm.coffeeshop.shared.service.PayrollService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.concurrent.*;

import static org.junit.jupiter.api.Assertions.assertEquals;

/** P1-11: hai yêu cầu tạo kỳ công trùng ngày chạy đồng thời, đúng một yêu cầu được ghi nhận. */
class PayrollPeriodCreateConcurrencyIT extends IntegrationTestBase {

    @Autowired PayrollService payroll;

    @Test
    void overlappingPeriodsCreatedConcurrentlyYieldOneSuccess() throws Exception {
        long admin = userIdByEmail("quanly@hrm.test");
        PeriodRequest a = new PeriodRequest("RACE-A", LocalDate.of(2041, 1, 1), LocalDate.of(2041, 1, 31), null);
        PeriodRequest b = new PeriodRequest("RACE-B", LocalDate.of(2041, 1, 15), LocalDate.of(2041, 2, 15), null);

        ExecutorService pool = Executors.newFixedThreadPool(2);
        try {
            CyclicBarrier start = new CyclicBarrier(2);
            List<Future<ErrorCode>> results = new ArrayList<>();
            for (PeriodRequest r : List.of(a, b)) {
                results.add(pool.submit(() -> {
                    loginAs(admin, null, Set.of(Roles.SYSTEM_ADMIN));
                    start.await(10, TimeUnit.SECONDS);
                    try {
                        payroll.create(r);
                        return null;                    // thành công
                    } catch (BusinessException e) {
                        return e.getCode();             // lỗi nghiệp vụ có kiểm soát
                    }
                }));
            }
            List<ErrorCode> outcomes = new ArrayList<>();
            for (Future<ErrorCode> f : results) outcomes.add(f.get(30, TimeUnit.SECONDS));

            long ok = outcomes.stream().filter(c -> c == null).count();
            assertEquals(1, ok, "Đúng một kỳ công được tạo; kết quả: " + outcomes);
            assertEquals(ErrorCode.CONFLICT, outcomes.stream().filter(c -> c != null).findFirst().orElseThrow());
        } finally {
            pool.shutdownNow();
        }
    }
}
