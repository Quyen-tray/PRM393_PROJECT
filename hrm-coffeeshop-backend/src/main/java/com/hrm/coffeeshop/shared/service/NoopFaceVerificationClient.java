package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.shared.service.FaceVerificationClient.Result;

import org.springframework.stereotype.Component;

@Component
public class NoopFaceVerificationClient implements FaceVerificationClient {
    @Override
    public Result verify(String sessionId, String photoStorageKey, Long employeeId) {
        return new Result("NOT_RUN", "NOT_RUN", "none");
    }
}
