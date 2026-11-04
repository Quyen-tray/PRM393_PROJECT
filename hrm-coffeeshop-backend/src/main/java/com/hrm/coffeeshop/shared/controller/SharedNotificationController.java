package com.hrm.coffeeshop.shared.controller;

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
public class SharedNotificationController {
    private final NotificationService svc;

    public SharedNotificationController(NotificationService svc) {
        this.svc = svc;
    }

    static NotificationView view(Notification n) {
        return new NotificationView(n.getNotificationId(), n.getNotificationType(), n.getTitle(), n.getMessage(),
                n.getRelatedEntityType(), n.getRelatedEntityId(), TimeUtils.vn(n.getCreatedAt()),
                TimeUtils.vn(n.getReadAt()), n.getDeliveryStatus());
    }

    @GetMapping("/notifications/me")
    public ApiResponse<PageResponse<NotificationView>> mine(@RequestParam(defaultValue = "false") boolean unreadOnly,
                                                            @PageableDefault(size = 20) Pageable p) {
        return ApiResponse.ok(PageResponse.of(svc.mine(SecurityUtils.current().userId(), unreadOnly, p), SharedNotificationController::view));
    }

    @GetMapping("/notifications/me/unread-count")
    public ApiResponse<Map<String, Long>> unread() {
        return ApiResponse.ok(Map.of("unreadCount", svc.unreadCount(SecurityUtils.current().userId())));
    }

    @PostMapping("/notifications/{notificationId}/read")
    public ApiResponse<Void> read(@PathVariable Long notificationId) {
        svc.markRead(notificationId, SecurityUtils.current().userId());
        return ApiResponse.ok("Marked as read", null);
    }

    @PostMapping("/notifications/read-all")
    public ApiResponse<Map<String, Integer>> readAll() {
        return ApiResponse.ok(Map.of("updated", svc.markAllRead(SecurityUtils.current().userId())));
    }
}
