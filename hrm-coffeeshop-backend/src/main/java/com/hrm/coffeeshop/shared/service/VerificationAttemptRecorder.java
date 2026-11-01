package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.domain.AttendanceVerificationAttempt;
import com.hrm.coffeeshop.repository.AttendanceVerificationAttemptRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;

@Service
public class VerificationAttemptRecorder {
    private final AttendanceVerificationAttemptRepository repo;

    public VerificationAttemptRecorder(AttendanceVerificationAttemptRepository repo) {
        this.repo = repo;
    }

    /**
     * Ghi trong transaction RIÊNG: khi nghiệp vụ ném lỗi và rollback, bản ghi thất bại vẫn được giữ lại.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void record(Long employeeId, Long shiftAssignmentId, String eventType, String verificationType,
                       String failureCode, Long deviceId, Instant at) {
        AttendanceVerificationAttempt a = new AttendanceVerificationAttempt();
        a.setEmployeeId(employeeId);
        a.setShiftAssignmentId(shiftAssignmentId);
        a.setEventType(eventType);
        a.setVerificationType(verificationType);
        a.setFailureCode(failureCode);
        a.setDeviceId(deviceId);
        a.setAttemptedAt(at);
        repo.save(a);
    }

    @Transactional
    public int purgeOlderThan(Instant cutoff) {
        return repo.purgeBefore(cutoff);
    }
}
