package com.hrm.coffeeshop.shared.dto;

import java.math.BigDecimal;

public final class StoreDto {
    private StoreDto() {}

    public record StoreView(Integer storeId, String storeCode, String name, String address,
                            BigDecimal latitude, BigDecimal longitude, Integer attendanceRadiusMeters, String status) {}

    /** Mọi trường tùy chọn khi PATCH; validation theo SRS 9.2. */
    public record SettingsRequest(String name, String address, BigDecimal latitude, BigDecimal longitude,
                                  Integer attendanceRadiusMeters, Integer checkInEarlyMinutes, Integer graceMinutes,
                                  Integer monthlyGraceLimit, Integer photoRetentionMonths,
                                  Integer lateReminderIntervalMinutes, Integer maxLateReminders,
                                  Integer shiftReminderMinutes, Integer checklistDueSoonMinutes,
                                  Integer gpsMaxAccuracyMeters) {}

    public record SettingsView(StoreView store, Integer attendanceRadiusMeters, Integer checkInEarlyMinutes,
                               Integer graceMinutes, Integer monthlyGraceLimit, Integer photoRetentionMonths,
                               Integer lateReminderIntervalMinutes, Integer maxLateReminders,
                               Integer shiftReminderMinutes, Integer checklistDueSoonMinutes,
                               Integer gpsMaxAccuracyMeters) {}

    public record ReminderRuleView(String ruleId, String description, Integer leadMinutes,
                                   Integer intervalMinutes, Integer maxAttempts, Boolean isActive) {}

    public record ReminderRuleRequest(Integer leadMinutes, Integer intervalMinutes, Integer maxAttempts, Boolean isActive) {
        public ReminderRuleRequest(Integer leadMinutes, Integer intervalMinutes, Integer maxAttempts) { this(leadMinutes, intervalMinutes, maxAttempts, null); }
    }
}
