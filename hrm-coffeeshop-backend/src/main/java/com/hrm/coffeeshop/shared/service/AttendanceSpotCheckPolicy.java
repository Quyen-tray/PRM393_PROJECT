package com.hrm.coffeeshop.shared.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.time.Duration;
import java.time.Instant;

/** Server-only, stable sampling and timing for one mid-shift attendance check. */
@Component
public class AttendanceSpotCheckPolicy {
    private final int percent;
    private final SecretKeySpec key;

    public AttendanceSpotCheckPolicy(
            @Value("${app.attendance.spot-check-sample-percent:50}") int percent,
            @Value("${app.jwt.secret}") String secret) {
        if (percent < 0 || percent > 100) throw new IllegalArgumentException("Spot-check sample percent must be 0–100");
        this.percent = percent;
        this.key = new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256");
    }

    public boolean selected(Long employeeId, Long assignmentId) {
        byte[] hash = digest("spot-check-sample:" + employeeId + ":" + assignmentId);
        int bucket = (ByteBuffer.wrap(hash).getInt() & Integer.MAX_VALUE) % 100;
        return bucket < percent;
    }

    /** Returns a stable pseudorandom instant, leaving the response window before shift end. */
    public Instant scheduledAt(Long employeeId, Long assignmentId, Instant checkedInAt,
                               Instant plannedEndAt, int responseMinutes) {
        Instant earliest = checkedInAt.plusSeconds(60);
        Instant latest = plannedEndAt.minus(Duration.ofMinutes(responseMinutes));
        if (latest.isBefore(earliest)) return null;
        long seconds = Duration.between(earliest, latest).getSeconds();
        byte[] hash = digest("spot-check-time:" + employeeId + ":" + assignmentId + ":" + checkedInAt.toEpochMilli());
        long random = ByteBuffer.wrap(hash, 4, 8).getLong() & Long.MAX_VALUE;
        return earliest.plusSeconds(seconds == 0 ? 0 : random % (seconds + 1));
    }

    private byte[] digest(String value) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(key);
            return mac.doFinal(value.getBytes(StandardCharsets.UTF_8));
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException("Cannot evaluate attendance spot-check policy", e);
        }
    }
}
