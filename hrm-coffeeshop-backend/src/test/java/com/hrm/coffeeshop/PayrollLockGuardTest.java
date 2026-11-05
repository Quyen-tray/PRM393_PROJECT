package com.hrm.coffeeshop;

import com.hrm.coffeeshop.common.BusinessException;
import com.hrm.coffeeshop.common.ErrorCode;
import com.hrm.coffeeshop.domain.PayrollPeriod;
import com.hrm.coffeeshop.repository.PayrollPeriodRepository;
import com.hrm.coffeeshop.shared.service.PayrollLockGuard;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

/**
 * Kỳ công đã chốt phải chặn thay đổi công của ngày nằm trong kỳ (SRS 8.5, D-09).
 * Guard khóa kỳ trước rồi đọc trạng thái: các test dưới đây kiểm tra quyết định dựa trên
 * trạng thái đọc SAU khi lấy khóa (repository trả về bản ghi đã khóa).
 */
class PayrollLockGuardTest {

    private final LocalDate day = LocalDate.parse("2026-10-14");

    private static PayrollPeriod period(String status) {
        PayrollPeriod p = new PayrollPeriod();
        p.setPeriodCode("P-" + status);
        p.setStartDate(LocalDate.parse("2026-10-01"));
        p.setEndDate(LocalDate.parse("2026-10-31"));
        p.setPeriodStatus(status);
        return p;
    }

    @Test
    void blocksWhenWorkDateInsideLockedPeriod() {
        PayrollPeriodRepository periods = mock(PayrollPeriodRepository.class);
        when(periods.findCoveringForUpdate(eq(day))).thenReturn(List.of(period("LOCKED")));
        PayrollLockGuard guard = new PayrollLockGuard(periods);

        BusinessException e = assertThrows(BusinessException.class, () -> guard.assertWorkDateOpen(day));
        assertEquals(ErrorCode.PAYROLL_PERIOD_LOCKED, e.getCode());
    }

    @Test
    void allowsWhenCoveringPeriodIsStillOpen() {
        // Kỳ đang mở (chưa chốt): guard vẫn phải lấy khóa, nhưng không được chặn.
        PayrollPeriodRepository periods = mock(PayrollPeriodRepository.class);
        when(periods.findCoveringForUpdate(eq(day))).thenReturn(List.of(period("HR_REVIEW")));
        PayrollLockGuard guard = new PayrollLockGuard(periods);

        assertDoesNotThrow(() -> guard.assertWorkDateOpen(day));
        verify(periods).findCoveringForUpdate(eq(day));
    }

    @Test
    void allowsWhenNoPeriodCoversDate() {
        PayrollPeriodRepository periods = mock(PayrollPeriodRepository.class);
        when(periods.findCoveringForUpdate(eq(day))).thenReturn(List.of());
        PayrollLockGuard guard = new PayrollLockGuard(periods);

        assertDoesNotThrow(() -> guard.assertWorkDateOpen(day));
    }

    @Test
    void nullWorkDateIsIgnoredWithoutLocking() {
        PayrollPeriodRepository periods = mock(PayrollPeriodRepository.class);
        PayrollLockGuard guard = new PayrollLockGuard(periods);

        assertDoesNotThrow(() -> guard.assertWorkDateOpen(null));
        verifyNoInteractions(periods);
    }
}
