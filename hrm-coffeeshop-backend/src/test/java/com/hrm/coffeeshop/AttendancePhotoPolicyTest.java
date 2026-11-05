package com.hrm.coffeeshop;

import com.hrm.coffeeshop.shared.service.AttendancePhotoPolicy;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class AttendancePhotoPolicyTest {
    private static final String SECRET = "photo-policy-test-secret-at-least-32-characters";

    @Test void samplingIsStableAcrossReloadsAndSeparateForEachEvent() {
        var policy = new AttendancePhotoPolicy(50, SECRET);
        int selected = 0, different = 0;
        for (long id = 1; id <= 2000; id++) {
            boolean in = policy.required(7L, id, "CHECK_IN");
            assertEquals(in, new AttendancePhotoPolicy(50, SECRET).required(7L, id, "CHECK_IN"));
            if (in) selected++;
            if (in != policy.required(7L, id, "CHECK_OUT")) different++;
        }
        assertTrue(selected > 900 && selected < 1100);
        assertTrue(different > 900 && different < 1100);
    }

    @Test void configurationSupportsNeverAndAlwaysRequiringAPhoto() {
        for (long id = 1; id <= 100; id++) {
            assertFalse(new AttendancePhotoPolicy(0, SECRET).required(7L, id, "CHECK_IN"));
            assertTrue(new AttendancePhotoPolicy(100, SECRET).required(7L, id, "CHECK_OUT"));
        }
    }

    @Test void invalidSamplingConfigurationFailsAtStartup() {
        assertThrows(IllegalArgumentException.class, () -> new AttendancePhotoPolicy(-1, SECRET));
        assertThrows(IllegalArgumentException.class, () -> new AttendancePhotoPolicy(101, SECRET));
    }
}
