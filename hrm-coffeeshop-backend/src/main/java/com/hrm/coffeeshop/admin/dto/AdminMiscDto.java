package com.hrm.coffeeshop.admin.dto;

import java.time.OffsetDateTime;

public final class AdminMiscDto {
    private AdminMiscDto() {}

    public record AuditView(Long auditLogId, Long actorUserId, String actionCode, String entityType, String entityId,
                            String beforeJson, String afterJson, String ipAddress, String correlationId,
                            OffsetDateTime createdAt) {}
}
