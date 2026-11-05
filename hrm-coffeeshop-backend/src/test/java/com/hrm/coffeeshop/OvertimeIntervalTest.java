package com.hrm.coffeeshop;

import com.hrm.coffeeshop.common.BusinessException;
import com.hrm.coffeeshop.common.ErrorCode;
import com.hrm.coffeeshop.shared.service.OvertimeService;
import org.junit.jupiter.api.Test;

import java.time.Duration;
import java.time.Instant;

import static org.junit.jupiter.api.Assertions.*;

/** DEC-OT: ca 08:00–17:00 (plannedEnd 17:00). Bảng quyết định cuối cùng. */
class OvertimeIntervalTest {
    private static final Instant BASE = Instant.parse("2031-03-05T00:00:00Z");
    private static final Instant PLANNED_END = at(17);
    private static final long MAX = 240;

    private static Instant at(int h) { return BASE.plus(Duration.ofHours(h)); }

    private static void assertRejected(int from, int to) {
        BusinessException e = assertThrows(BusinessException.class,
                () -> OvertimeService.requireValidInterval(PLANNED_END, at(from), at(to), MAX));
        assertEquals(ErrorCode.VALIDATION_ERROR, e.getCode());
    }

    @Test
    void startingBeforeShiftEndIsRejected() {
        assertRejected(16, 18);   // giao với ca
    }

    @Test
    void validAfterShiftEnd() {
        assertDoesNotThrow(() -> OvertimeService.requireValidInterval(PLANNED_END, at(17), at(19), MAX));
        assertDoesNotThrow(() -> OvertimeService.requireValidInterval(PLANNED_END, at(18), at(20), MAX));
    }

    @Test
    void endBeforeStartIsRejected() {
        assertRejected(19, 18);
    }

    @Test
    void zeroLengthIsRejected() {
        assertRejected(17, 17);
    }

    @Test
    void durationAboveLimitIsRejected() {
        BusinessException e = assertThrows(BusinessException.class,
                () -> OvertimeService.requireValidInterval(PLANNED_END, at(17), at(22), MAX));  // 5 giờ > 240 phút
        assertEquals(ErrorCode.VALIDATION_ERROR, e.getCode());
        assertDoesNotThrow(() -> OvertimeService.requireValidInterval(PLANNED_END, at(17), at(21), MAX)); // đúng 240 phút
    }
}
