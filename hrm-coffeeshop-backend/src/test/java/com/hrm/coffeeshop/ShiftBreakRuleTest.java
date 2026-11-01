package com.hrm.coffeeshop;

import com.hrm.coffeeshop.common.BusinessException;
import com.hrm.coffeeshop.shared.service.ShiftService;
import org.junit.jupiter.api.Test;

import java.time.LocalTime;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

/** P2-05: nghỉ giữa ca phải nhỏ hơn thời lượng ca, kể cả ca qua nửa đêm. */
class ShiftBreakRuleTest {

    @Test
    void shiftMinutesHandlesOvernightShift() {
        assertEquals(540, ShiftService.shiftMinutes(LocalTime.of(8, 0), LocalTime.of(17, 0)));
        assertEquals(480, ShiftService.shiftMinutes(LocalTime.of(22, 0), LocalTime.of(6, 0)));
    }

    @Test
    void breakBelowDurationIsAccepted() {
        assertDoesNotThrow(() -> ShiftService.requireBreakWithinShift(LocalTime.of(8, 0), LocalTime.of(17, 0), 60));
        assertDoesNotThrow(() -> ShiftService.requireBreakWithinShift(LocalTime.of(22, 0), LocalTime.of(6, 0), 479));
        assertDoesNotThrow(() -> ShiftService.requireBreakWithinShift(LocalTime.of(8, 0), LocalTime.of(9, 0), null));
    }

    @Test
    void breakAtOrAboveDurationIsRejected() {
        // Ca 60 phút, nghỉ 60 phút: vượt quá trần 240 nên không bắt được bằng @Max cũ, nhưng vẫn phải chặn
        assertThrows(BusinessException.class, () ->
                ShiftService.requireBreakWithinShift(LocalTime.of(8, 0), LocalTime.of(9, 0), 60));
        assertThrows(BusinessException.class, () ->
                ShiftService.requireBreakWithinShift(LocalTime.of(22, 0), LocalTime.of(6, 0), 480));
        assertThrows(BusinessException.class, () ->
                ShiftService.requireBreakWithinShift(LocalTime.of(8, 0), LocalTime.of(17, 0), -1));
    }
}
