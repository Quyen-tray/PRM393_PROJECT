package com.hrm.coffeeshop;

import com.hrm.coffeeshop.shared.service.AttendanceMetricsService;
import com.hrm.coffeeshop.shared.service.AttendanceMetricsService.Late;
import com.hrm.coffeeshop.shared.service.StoreService;
import com.hrm.coffeeshop.domain.Store;

import com.hrm.coffeeshop.repository.AttendanceRepository;
import com.hrm.coffeeshop.repository.OvertimeRequestRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.time.temporal.ChronoUnit;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/** Quy tắc ân hạn / đi muộn (BR-TIME-02..04). */
class AttendanceMetricsServiceTest {
    private final Instant start = Instant.parse("2026-10-14T00:00:00Z");   // 07:00 giờ Việt Nam
    private AttendanceRepository attendance;
    private AttendanceMetricsService svc;

    @BeforeEach
    void setUp() {
        attendance = mock(AttendanceRepository.class);
        StoreService storeService = mock(StoreService.class);
        Store store = new Store();
        store.setMonthlyGraceLimit(3);
        when(storeService.current()).thenReturn(store);
        svc = new AttendanceMetricsService(attendance, mock(OvertimeRequestRepository.class), storeService);
    }

    private void graceUsed(long n) {
        when(attendance.countGraceUsed(anyLong(), any(), any(), anyLong())).thenReturn(n);
    }

    @Test
    void onTimeIsNotLate() {
        graceUsed(0);
        Late l = svc.computeLate(1L, start.minus(5, ChronoUnit.MINUTES), start, 5, null);
        assertEquals(0, l.minutes());
        assertFalse(l.graceApplied());
    }

    @Test
    void insideGraceConsumesOneGraceAndIsNotLate() {
        graceUsed(0);
        Late l = svc.computeLate(1L, start.plus(4, ChronoUnit.MINUTES), start, 5, null);
        assertEquals(0, l.minutes());
        assertTrue(l.graceApplied());
    }

    @Test
    void afterGraceIsCountedFromGraceEnd() {
        graceUsed(0);
        Late l = svc.computeLate(1L, start.plus(8, ChronoUnit.MINUTES), start, 5, null);
        assertEquals(3, l.minutes());
        assertFalse(l.graceApplied());
    }

    @Test
    void whenGraceQuotaIsExhaustedLateCountsFromShiftStart() {
        graceUsed(3);
        Late l = svc.computeLate(1L, start.plus(4, ChronoUnit.MINUTES), start, 5, null);
        assertEquals(4, l.minutes());
        assertFalse(l.graceApplied());
    }
}
