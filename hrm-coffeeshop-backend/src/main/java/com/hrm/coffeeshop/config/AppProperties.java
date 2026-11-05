package com.hrm.coffeeshop.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "app")
public record AppProperties(String zone, Jwt jwt, Google google, Storage storage,
                            Attendance attendance, RateLimit rateLimit) {
    public record Jwt(String secret, long accessTtlSeconds, long refreshTtlDays) {}
    public record Google(String clientId) {}
    public record Storage(long signedUrlTtlSeconds, String signingSecret) {}
    public record Attendance(int gpsMaxAccuracyMeters, int gpsMaxAgeSeconds) {}
    public record RateLimit(int authPerMinute, int attendancePerMinute) {}
}
