package com.hrm.coffeeshop;

import com.hrm.coffeeshop.common.GeoUtils;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class GeoUtilsTest {
    @Test
    void samePointIsZero() {
        assertEquals(0.0, GeoUtils.distanceMeters(21.0285, 105.8542, 21.0285, 105.8542), 0.001);
    }

    @Test
    void roughlyOneHundredMetersPerPointNineMilliDegreesLatitude() {
        double d = GeoUtils.distanceMeters(21.0285, 105.8542, 21.0294, 105.8542);
        assertTrue(d > 95 && d < 105, "distance was " + d);
    }
}
