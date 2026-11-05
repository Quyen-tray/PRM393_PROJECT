package com.hrm.coffeeshop.domain;

import jakarta.persistence.*;
import java.io.Serializable;
import java.math.BigDecimal;
import java.time.*;
import java.util.Objects;

/** Sinh tự động từ DDL bởi tools/gen_entities.py - đừng sửa tay. */
@Entity
@Table(name = "ChecklistEvidence")
public class ChecklistEvidence {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "ChecklistEvidenceId")
    private Long checklistEvidenceId;
    @Column(name = "ChecklistTaskId")
    private Long checklistTaskId;
    @Column(name = "ChecklistTaskItemId")
    private Long checklistTaskItemId;
    @Column(name = "StorageKey")
    private String storageKey;
    @Column(name = "UploadedBy")
    private Long uploadedBy;
    @Column(name = "UploadedAt")
    private Instant uploadedAt = Instant.now();

    public ChecklistEvidence() {}

    public Long getChecklistEvidenceId() { return checklistEvidenceId; }
    public void setChecklistEvidenceId(Long checklistEvidenceId) { this.checklistEvidenceId = checklistEvidenceId; }
    public Long getChecklistTaskId() { return checklistTaskId; }
    public void setChecklistTaskId(Long checklistTaskId) { this.checklistTaskId = checklistTaskId; }
    public Long getChecklistTaskItemId() { return checklistTaskItemId; }
    public void setChecklistTaskItemId(Long checklistTaskItemId) { this.checklistTaskItemId = checklistTaskItemId; }
    public String getStorageKey() { return storageKey; }
    public void setStorageKey(String storageKey) { this.storageKey = storageKey; }
    public Long getUploadedBy() { return uploadedBy; }
    public void setUploadedBy(Long uploadedBy) { this.uploadedBy = uploadedBy; }
    public Instant getUploadedAt() { return uploadedAt; }
    public void setUploadedAt(Instant uploadedAt) { this.uploadedAt = uploadedAt; }
}
