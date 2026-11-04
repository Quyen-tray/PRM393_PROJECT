package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.domain.Notification;

/** Kênh đẩy (FCM/APNs). Implementation mặc định chỉ log; thay bằng FCM khi tích hợp. */
public interface PushGateway {
    boolean send(Notification n);
}
