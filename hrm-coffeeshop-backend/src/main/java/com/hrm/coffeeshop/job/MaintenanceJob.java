package com.hrm.coffeeshop.job;

import com.hrm.coffeeshop.shared.service.*;

import com.hrm.coffeeshop.common.TimeUtils;
import com.hrm.coffeeshop.domain.AttendanceVerification;
import com.hrm.coffeeshop.repository.AttendanceVerificationRepository;
import com.hrm.coffeeshop.repository.AttendanceExceptionRequestRepository;
import com.hrm.coffeeshop.domain.AttendanceExceptionRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.Clock;
import java.util.Map;

/** Việc định kỳ hằng ngày: hết hạn hồ sơ; xóa minh chứng quá thời hạn lưu (xóa file + ẩn danh, KHÔNG xóa dữ liệu công). */
@Component
public class MaintenanceJob {
    private static final Logger log = LoggerFactory.getLogger(MaintenanceJob.class);

    private final DocumentService documents;
    private final TrainingService training;
    private final AttendanceVerificationRepository evidences;
    private final AttendanceExceptionRequestRepository exceptions;
    private final StorageGateway storage;
    private final AuditService audit;
    private final TransactionTemplate tx;
    private final VerificationAttemptRecorder attempts;
    private final Clock clock;

    public MaintenanceJob(DocumentService documents, TrainingService training, AttendanceVerificationRepository evidences,
                          AttendanceExceptionRequestRepository exceptions, StorageGateway storage, AuditService audit, TransactionTemplate tx, VerificationAttemptRecorder attempts, Clock clock) {
        this.documents = documents;
        this.training = training;
        this.exceptions = exceptions;
        this.evidences = evidences;
        this.storage = storage;
        this.audit = audit;
        this.tx = tx;
        this.attempts = attempts;
        this.clock = clock;
    }

    @Scheduled(cron = "0 15 2 * * *", zone = "Asia/Ho_Chi_Minh")
    public void daily() {
        try {
            int n = documents.expireOutdated();
            if (n > 0) log.info("Expired {} documents", n);
        } catch (Exception e) { log.error("document expiry failed", e); }
        try {
            int t = training.expireOutdated();
            if (t > 0) log.info("Expired {} training records", t);
        } catch (Exception e) { log.error("training expiry failed", e); }
        try { purgeEvidence(); } catch (Exception e) { log.error("evidence purge failed", e); }
        try {   // B-17: giữ lần xác minh thất bại 180 ngày
            int n = attempts.purgeOlderThan(clock.instant().minus(java.time.Duration.ofDays(180)));
            if (n > 0) log.info("Purged {} verification attempts", n);
        } catch (Exception e) { log.error("verification attempt purge failed", e); }
    }

    /** Xóa ảnh hết hạn lưu (SRS 7.4 / BR-PHOTO): ảnh xác minh và tệp giải trình. Chỉ xóa file, giữ bản ghi và audit. */
    void purgeEvidence() {
        java.time.LocalDate today = TimeUtils.today(clock);
        for (AttendanceVerification v : evidences.findExpired(today)) {
            try {
                tx.executeWithoutResult(st -> {
                    storage.delete(v.getEvidenceStorageKey());
                    v.setEvidenceStorageKey("PURGED");
                    v.setContentHash(null);
                    v.setAiResultJson(null);
                    evidences.save(v);
                    audit.log("EVIDENCE_PURGED", "AttendanceVerification", v.getVerificationId(), null,
                            Map.of("attendanceId", String.valueOf(v.getAttendanceId())));
                });
            } catch (Exception ex) { log.warn("purge skipped for {}: {}", v.getVerificationId(), ex.getMessage()); }
        }
        for (AttendanceExceptionRequest x : exceptions.findExpiredEvidence(today)) {
            try {
                tx.executeWithoutResult(st -> {
                    storage.delete(x.getEvidenceStorageKey());
                    x.setEvidenceStorageKey("PURGED");
                    exceptions.save(x);
                    audit.log("EVIDENCE_PURGED", "AttendanceExceptionRequest", x.getExceptionRequestId(), null, Map.of());
                });
            } catch (Exception ex) { log.warn("purge skipped for exception {}: {}", x.getExceptionRequestId(), ex.getMessage()); }
        }
    }
}
