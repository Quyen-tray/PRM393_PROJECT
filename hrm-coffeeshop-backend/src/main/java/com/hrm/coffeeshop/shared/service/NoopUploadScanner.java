package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.common.FileSignature;
import org.springframework.stereotype.Component;

/** Mặc định chưa quét mã độc. Cần thay trước khi đưa production (xem docs/DECISIONS_BASELINE.md). */
@Component
public class NoopUploadScanner implements UploadScanner {
    @Override
    public void scan(byte[] content, FileSignature type) { /* no-op */ }
}
