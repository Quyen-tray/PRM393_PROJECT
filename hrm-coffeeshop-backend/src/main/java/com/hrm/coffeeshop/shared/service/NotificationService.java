package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.common.BusinessException;
import com.hrm.coffeeshop.domain.Notification;
import com.hrm.coffeeshop.repository.AppUserRepository;
import com.hrm.coffeeshop.repository.NotificationRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;

@Service
public class NotificationService {
    private final NotificationRepository repo;
    private final AppUserRepository users;
    private final Clock clock;

    public NotificationService(NotificationRepository repo, AppUserRepository users, Clock clock) {
        this.repo = repo;
        this.users = users;
        this.clock = clock;
    }

    /** Gửi cho mọi người dùng ACTIVE có vai trò roleCode (vd: báo quản lý có đơn chờ duyệt). */
    @Transactional
    public void notifyRole(String roleCode, String type, String title, String message, String entityType, Long entityId) {
        for (Long uid : users.findActiveUserIdsByRoleCode(roleCode))
            notify(uid, type, title, message, entityType, entityId, null);
    }

    /** Gửi cho mọi người dùng ACTIVE có quyền permissionCode (trực tiếp hoặc qua role), vd: báo người có quyền chốt công. */
    @Transactional
    public void notifyPermission(String permissionCode, String type, String title, String message, String entityType, Long entityId) {
        for (Long uid : users.findActiveUserIdsByPermissionCode(permissionCode))
            notify(uid, type, title, message, entityType, entityId, null);
    }

    /** Tạo thông báo (đẩy đi bởi job dispatcher). dedupKey != null → không tạo trùng khi job chạy lại (BR-REM-03). */
    @Transactional
    public void notify(Long userId, String type, String title, String message,
                       String entityType, Long entityId, String dedupKey) {
        if (userId == null) return;
        if (dedupKey != null && repo.existsByDedupKey(dedupKey)) return;
        Notification n = new Notification();
        n.setUserId(userId);
        n.setNotificationType(type);
        n.setTitle(title);
        n.setMessage(message);
        n.setRelatedEntityType(entityType);
        n.setRelatedEntityId(entityId);
        n.setDedupKey(dedupKey);
        repo.save(n);
    }

    @Transactional(readOnly = true)
    public Page<Notification> mine(Long userId, boolean unreadOnly, Pageable p) {
        return unreadOnly ? repo.findByUserIdAndReadAtIsNullOrderByCreatedAtDesc(userId, p)
                : repo.findByUserIdOrderByCreatedAtDesc(userId, p);
    }

    @Transactional(readOnly = true)
    public long unreadCount(Long userId) { return repo.countByUserIdAndReadAtIsNull(userId); }

    @Transactional
    public void markRead(Long id, Long userId) {
        Notification n = repo.findById(id).filter(x -> x.getUserId().equals(userId))
                .orElseThrow(() -> BusinessException.notFound("thông báo"));
        if (n.getReadAt() == null) n.setReadAt(clock.instant());
    }

    @Transactional
    public int markAllRead(Long userId) { return repo.markAllRead(userId, clock.instant()); }

    @Transactional(readOnly = true)
    public Page<Notification> deliveries(String status, Pageable p) {
        return status == null || status.isBlank() ? repo.findAll(PageRequest.of(p.getPageNumber(), p.getPageSize(), p.getSort().isSorted() ? p.getSort() : org.springframework.data.domain.Sort.by("createdAt").descending()))
                : repo.findByDeliveryStatusOrderByCreatedAtDesc(status, p);
    }
}
