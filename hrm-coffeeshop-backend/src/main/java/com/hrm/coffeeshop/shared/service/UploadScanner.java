package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.common.FileSignature;

/**
 * Điểm mở rộng quét mã độc trước khi lưu tệp (đặc biệt cho PDF). Triển khai production gắn bộ quét thật
 * (ví dụ ClamAV) bằng một bean khác và loại NoopUploadScanner. Ném BusinessException nếu tệp không an toàn.
 */
public interface UploadScanner {
    void scan(byte[] content, FileSignature type);
}
