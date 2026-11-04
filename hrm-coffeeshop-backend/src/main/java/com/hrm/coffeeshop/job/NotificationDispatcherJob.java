package com.hrm.coffeeshop.job;

import com.hrm.coffeeshop.domain.Notification;
import com.hrm.coffeeshop.repository.NotificationRepository;
import com.hrm.coffeeshop.shared.service.PushGateway;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.Clock;
import java.time.Instant;

/**
 * Đẩy thông báo PENDING qua PushGateway; thử lại tối đa 5 lần rồi đánh dấu FAILED (CK AttemptCount ≤ 10).
 * Không giữ transaction DB khi gọi mạng: ba bước (claim ngắn, gửi, ghi kết quả ngắn).
 */
@Component
public class NotificationDispatcherJob {
    private static final Logger log = LoggerFactory.getLogger(NotificationDispatcherJob.class);
    private static final int MAX_ATTEMPTS = 5;

    private final NotificationRepository repo;
    private final PushGateway push;
    private final TransactionTemplate tx;
    private final Clock clock;

    public NotificationDispatcherJob(NotificationRepository repo, PushGateway push, TransactionTemplate tx, Clock clock) {
        this.repo = repo;
        this.push = push;
        this.tx = tx;
        this.clock = clock;
    }

    @Scheduled(fixedDelay = 15_000, initialDelay = 20_000)
    public void dispatch() {
        Instant now = clock.instant();
        for (Notification n : repo.findTop100ByDeliveryStatusOrderByCreatedAtAsc("PENDING")) {
            if (n.getScheduledAt() != null && n.getScheduledAt().isAfter(now)) continue;
            try {
                dispatchOne(n, now);
            } catch (Exception e) {
                log.warn("dispatch skipped for {}: {}", n.getNotificationId(), e.getMessage());
            }
        }
    }

    /**
     * 1) Claim trong transaction ngắn: tăng AttemptCount có điều kiện; instance thua cuộc bỏ qua.
     * 2) Gửi NGOÀI transaction.
     * 3) Ghi kết quả trong transaction ngắn.
     * Crash giữa bước 2 và 3 có thể gửi lại (at-least-once). NotificationId là khóa idempotency cho nhà cung cấp.
     */
    private void dispatchOne(Notification n, Instant now) {
        Integer claimed = tx.execute(st -> repo.claimForDispatch(n.getNotificationId(), n.getAttemptCount()));
        if (claimed == null || claimed != 1) return;

        boolean ok;
        try {
            ok = push.send(n);
        } catch (Exception e) {
            ok = false;
            log.warn("push error for {}: {}", n.getNotificationId(), e.getMessage());
        }
        final boolean delivered = ok;
        tx.executeWithoutResult(st -> {
            Notification x = repo.findById(n.getNotificationId()).orElseThrow();
            if (delivered) {
                x.setDeliveryStatus("SENT");
                x.setSentAt(now);
            } else if (x.getAttemptCount() >= MAX_ATTEMPTS) {
                x.setDeliveryStatus("FAILED");
            }
        });
    }
}
