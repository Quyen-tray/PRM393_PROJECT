package com.hrm.coffeeshop.shared.dto;

import java.time.OffsetDateTime;

public final class MiscDto {
    private MiscDto() {}

    public record NotificationView(Long notificationId, String type, String title, String message,
                                   String relatedEntityType, Long relatedEntityId, OffsetDateTime createdAt,
                                   OffsetDateTime readAt, String deliveryStatus) {}

    public record ReasonRequest(@jakarta.validation.constraints.NotBlank @jakarta.validation.constraints.Size(max = 500) String reason) {}

    public record OptionalNoteRequest(@jakarta.validation.constraints.Size(max = 500) String note) {}
}
