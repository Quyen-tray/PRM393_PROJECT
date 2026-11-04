package com.hrm.coffeeshop.domain;

import jakarta.persistence.*;
import java.io.Serializable;
import java.math.BigDecimal;
import java.time.*;
import java.util.Objects;

/** Sinh tự động từ DDL bởi tools/gen_entities.py - đừng sửa tay. */
@Entity
@Table(name = "EmployeeDocument")
public class EmployeeDocument {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "EmployeeDocumentId")
    private Long employeeDocumentId;
    @Column(name = "EmployeeId")
    private Long employeeId;
    @Column(name = "DocumentTypeId")
    private Integer documentTypeId;
    @Column(name = "FileName")
    private String fileName;
    @Column(name = "StorageKey")
    private String storageKey;
    @Column(name = "ReviewStatus")
    private String reviewStatus = "PENDING";
    @Column(name = "ReviewedBy")
    private Long reviewedBy;
    @Column(name = "ReviewedAt")
    private Instant reviewedAt;
    @Column(name = "ExpiresAt")
    private LocalDate expiresAt;
    @Column(name = "IssuedAt")
    private LocalDate issuedAt;
    @Column(name = "UploadedAt")
    private Instant uploadedAt = Instant.now();
    @Column(name = "RejectionReason")
    private String rejectionReason;

    public EmployeeDocument() {}

    public Long getEmployeeDocumentId() { return employeeDocumentId; }
    public void setEmployeeDocumentId(Long employeeDocumentId) { this.employeeDocumentId = employeeDocumentId; }
    public Long getEmployeeId() { return employeeId; }
    public void setEmployeeId(Long employeeId) { this.employeeId = employeeId; }
    public Integer getDocumentTypeId() { return documentTypeId; }
    public void setDocumentTypeId(Integer documentTypeId) { this.documentTypeId = documentTypeId; }
    public String getFileName() { return fileName; }
    public void setFileName(String fileName) { this.fileName = fileName; }
    public String getStorageKey() { return storageKey; }
    public void setStorageKey(String storageKey) { this.storageKey = storageKey; }
    public String getReviewStatus() { return reviewStatus; }
    public void setReviewStatus(String reviewStatus) { this.reviewStatus = reviewStatus; }
    public Long getReviewedBy() { return reviewedBy; }
    public void setReviewedBy(Long reviewedBy) { this.reviewedBy = reviewedBy; }
    public Instant getReviewedAt() { return reviewedAt; }
    public void setReviewedAt(Instant reviewedAt) { this.reviewedAt = reviewedAt; }
    public LocalDate getExpiresAt() { return expiresAt; }
    public void setExpiresAt(LocalDate expiresAt) { this.expiresAt = expiresAt; }
    public LocalDate getIssuedAt() { return issuedAt; }
    public void setIssuedAt(LocalDate issuedAt) { this.issuedAt = issuedAt; }
    public Instant getUploadedAt() { return uploadedAt; }
    public void setUploadedAt(Instant uploadedAt) { this.uploadedAt = uploadedAt; }
    public String getRejectionReason() { return rejectionReason; }
    public void setRejectionReason(String rejectionReason) { this.rejectionReason = rejectionReason; }
}
