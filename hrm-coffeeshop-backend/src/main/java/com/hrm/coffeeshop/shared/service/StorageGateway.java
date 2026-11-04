package com.hrm.coffeeshop.shared.service;

import java.time.Duration;

/**
 * Cổng truy cập private storage (S3/Azure Blob/GCS...). Thay implementation theo D-11.
 * App di động KHÔNG biết nhà cung cấp lưu trữ: nó chỉ gọi POST /storage/uploads của backend,
 * nên đổi sang S3/Azure/GCS chỉ cần viết một bean implement interface này (đặt app.storage.provider khác "local").
 */
public interface StorageGateway {
    /** URL xem có hạn ngắn; không bao giờ là đường dẫn công khai lâu dài. */
    String createViewUrl(String storageKey, Duration ttl);

    /** Signed URL có thể mang actor claim đã được ký để audit lần truy cập thực tế (nếu provider hỗ trợ). */
    default String createViewUrl(String storageKey, Duration ttl, Long actorUserId) {
        return createViewUrl(storageKey, ttl);
    }

    /** Ghi nội dung dưới khóa đã được kiểm tra hợp lệ (không ghi đè khóa đã tồn tại). */
    void store(String storageKey, byte[] content);

    void delete(String storageKey);

    /** File đã được upload và còn tồn tại dưới khóa này (dùng để chặn ảnh giả / đã bị xóa). */
    boolean exists(String storageKey);
}
