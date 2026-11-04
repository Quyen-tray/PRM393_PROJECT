package com.hrm.coffeeshop.admin.controller;

import com.hrm.coffeeshop.shared.dto.MiscDto.NotificationView;
import com.hrm.coffeeshop.shared.service.NotificationService;

import com.hrm.coffeeshop.common.*;
import com.hrm.coffeeshop.domain.Notification;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.util.Map;

@RestController
public class AdminNotificationController {
    private final NotificationService svc;

    public AdminNotificationController(NotificationService svc) {
        this.svc = svc;
    }

    static NotificationView view(Notification n) {
        return new NotificationView(n.getNotificationId(), n.getNotificationType(), n.getTitle(), n.getMessage(),
                n.getRelatedEntityType(), n.getRelatedEntityId(), TimeUtils.vn(n.getCreatedAt()),
                TimeUtils.vn(n.getReadAt()), n.getDeliveryStatus());
    }

    @GetMapping("/admin/notification-deliveries")
    @PreAuthorize("hasRole('SYSTEM_ADMIN')")
    public ApiResponse<PageResponse<NotificationView>> deliveries(@RequestParam(required = false) String status,
                                                                  @PageableDefault(size = 50) Pageable p) {
        return ApiResponse.ok(PageResponse.of(svc.deliveries(status, p), AdminNotificationController::view));
    }
}
