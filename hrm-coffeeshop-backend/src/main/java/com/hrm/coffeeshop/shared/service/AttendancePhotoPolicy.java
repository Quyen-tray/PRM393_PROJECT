package com.hrm.coffeeshop.shared.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;

/** Stable, server-only sampling: refreshing or retrying cannot reroll a shift's event. */
@Component
public class AttendancePhotoPolicy {
    private final int percent;
    private final SecretKeySpec key;

    public AttendancePhotoPolicy(@Value("${app.attendance.photo-sample-percent:50}") int percent,
                                 @Value("${app.jwt.secret}") String secret) {
        if (percent < 0 || percent > 100) throw new IllegalArgumentException("Photo sample percent must be 0–100");
        this.percent = percent;
        this.key = new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256");
    }

    public boolean required(Long employeeId, Long assignmentId, String event) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(key);
            byte[] hash = mac.doFinal(("attendance-photo:" + employeeId + ":" + assignmentId + ":" + event)
                    .getBytes(StandardCharsets.UTF_8));
            int bucket = (ByteBuffer.wrap(hash).getInt() & Integer.MAX_VALUE) % 100;
            return bucket < percent;
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException("Cannot evaluate attendance photo policy", e);
        }
    }
}
