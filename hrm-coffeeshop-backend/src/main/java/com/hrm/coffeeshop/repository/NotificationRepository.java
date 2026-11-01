package com.hrm.coffeeshop.repository;

import com.hrm.coffeeshop.domain.*;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.time.*;
import java.util.*;

public interface NotificationRepository extends JpaRepository<Notification, Long> {

    boolean existsByDedupKey(String dedupKey);
    Page<Notification> findByUserIdOrderByCreatedAtDesc(Long userId, Pageable p);
    Page<Notification> findByUserIdAndReadAtIsNullOrderByCreatedAtDesc(Long userId, Pageable p);
    long countByUserIdAndReadAtIsNull(Long userId);
    Page<Notification> findByDeliveryStatusOrderByCreatedAtDesc(String status, Pageable p);
    List<Notification> findTop100ByDeliveryStatusOrderByCreatedAtAsc(String status);

    /** Nhận xử lý một thông báo: chỉ thành công khi bản ghi còn PENDING và số lần thử chưa đổi (chống gửi trùng nhiều instance). */
    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update Notification n set n.attemptCount = n.attemptCount + 1 "
         + "where n.notificationId = :id and n.deliveryStatus = 'PENDING' and n.attemptCount = :expected")
    int claimForDispatch(@Param("id") Long id, @Param("expected") Short expected);

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query("update Notification n set n.readAt = :now where n.userId = :userId and n.readAt is null")
    int markAllRead(@Param("userId") Long userId, @Param("now") Instant now);
}
