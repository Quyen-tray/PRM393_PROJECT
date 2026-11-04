package com.hrm.coffeeshop.shared.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.time.OffsetDateTime;

public final class DeviceDto {
    private DeviceDto() {}

    public record RegisterRequest(@NotBlank @Size(max = 500) String deviceFingerprint,
                                  @NotBlank @Pattern(regexp = "ANDROID|IOS") String platform,
                                  @Size(max = 150) String deviceLabel) {}

    public record DeviceView(Long deviceId, Long employeeId, String employeeName, String deviceLabel, String platform,
                             String status, OffsetDateTime requestedAt, OffsetDateTime approvedAt, String reason) {}
}
