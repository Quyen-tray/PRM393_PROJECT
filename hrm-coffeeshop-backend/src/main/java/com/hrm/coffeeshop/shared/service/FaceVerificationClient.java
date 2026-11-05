package com.hrm.coffeeshop.shared.service;

/** Nhà cung cấp face/liveness (D-02 chưa chốt). Mặc định NOT_RUN; thay implementation khi chọn nhà cung cấp. */
public interface FaceVerificationClient {
    record Result(String matchStatus, String livenessStatus, String provider) {}

    Result verify(String sessionId, String photoStorageKey, Long employeeId);
}
