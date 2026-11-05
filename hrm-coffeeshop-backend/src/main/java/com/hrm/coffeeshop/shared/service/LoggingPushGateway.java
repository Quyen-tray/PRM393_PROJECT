package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.domain.Notification;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

@Component
public class LoggingPushGateway implements PushGateway {
    private static final Logger log = LoggerFactory.getLogger(LoggingPushGateway.class);

    @Override
    public boolean send(Notification n) {
        log.info("PUSH_NOT_CONFIGURED user={} type={} entity={}#{} (not delivered)", n.getUserId(), n.getNotificationType(),
                n.getRelatedEntityType(), n.getRelatedEntityId());
        // Chỉ ghi log không đồng nghĩa push đã được gửi; trả false để dispatcher retry rồi đánh FAILED.
        return false;
    }
}
