package com.hrm.coffeeshop.domain;

import jakarta.persistence.*;
import java.io.Serializable;
import java.math.BigDecimal;
import java.time.*;
import java.util.Objects;

/** Sinh tự động từ DDL bởi tools/gen_entities.py - đừng sửa tay. */
@Entity
@Table(name = "AttendanceAdjustmentRequest")
public class AttendanceAdjustmentRequest {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "AttendanceAdjustmentRequestId")
    private Long attendanceAdjustmentRequestId;
    @Version
    @Column(name = "RowVersion")
    private Long rowVersion = 0L;
    @Column(name = "AttendanceId")
    private Long attendanceId;
    @Column(name = "RequestedBy")
    private Long requestedBy;
    @Column(name = "FieldName")
    private String fieldName;
    @Column(name = "OldValue")
    private String oldValue;
    @Column(name = "NewValue")
    private String newValue;
    @Column(name = "Reason")
    private String reason;
    @Column(name = "EvidenceStorageKey")
    private String evidenceStorageKey;
    @Column(name = "ManagerStatus")
    private String managerStatus = "PENDING";
    @Column(name = "ManagerReviewedBy")
    private Long managerReviewedBy;
    @Column(name = "ManagerReviewedAt")
    private Instant managerReviewedAt;
    @Column(name = "HrStatus")
    private String hrStatus = "PENDING";
    @Column(name = "HrReviewedBy")
    private Long hrReviewedBy;
    @Column(name = "HrReviewedAt")
    private Instant hrReviewedAt;
    @Column(name = "CreatedAt")
    private Instant createdAt = Instant.now();

    public AttendanceAdjustmentRequest() {}

    public Long getAttendanceAdjustmentRequestId() { return attendanceAdjustmentRequestId; }
    public void setAttendanceAdjustmentRequestId(Long attendanceAdjustmentRequestId) { this.attendanceAdjustmentRequestId = attendanceAdjustmentRequestId; }
    public Long getRowVersion() { return rowVersion; }
    public void setRowVersion(Long rowVersion) { this.rowVersion = rowVersion; }
    public Long getAttendanceId() { return attendanceId; }
    public void setAttendanceId(Long attendanceId) { this.attendanceId = attendanceId; }
    public Long getRequestedBy() { return requestedBy; }
    public void setRequestedBy(Long requestedBy) { this.requestedBy = requestedBy; }
    public String getFieldName() { return fieldName; }
    public void setFieldName(String fieldName) { this.fieldName = fieldName; }
    public String getOldValue() { return oldValue; }
    public void setOldValue(String oldValue) { this.oldValue = oldValue; }
    public String getNewValue() { return newValue; }
    public void setNewValue(String newValue) { this.newValue = newValue; }
    public String getReason() { return reason; }
    public void setReason(String reason) { this.reason = reason; }
    public String getEvidenceStorageKey() { return evidenceStorageKey; }
    public void setEvidenceStorageKey(String evidenceStorageKey) { this.evidenceStorageKey = evidenceStorageKey; }
    public String getManagerStatus() { return managerStatus; }
    public void setManagerStatus(String managerStatus) { this.managerStatus = managerStatus; }
    public Long getManagerReviewedBy() { return managerReviewedBy; }
    public void setManagerReviewedBy(Long managerReviewedBy) { this.managerReviewedBy = managerReviewedBy; }
    public Instant getManagerReviewedAt() { return managerReviewedAt; }
    public void setManagerReviewedAt(Instant managerReviewedAt) { this.managerReviewedAt = managerReviewedAt; }
    public String getHrStatus() { return hrStatus; }
    public void setHrStatus(String hrStatus) { this.hrStatus = hrStatus; }
    public Long getHrReviewedBy() { return hrReviewedBy; }
    public void setHrReviewedBy(Long hrReviewedBy) { this.hrReviewedBy = hrReviewedBy; }
    public Instant getHrReviewedAt() { return hrReviewedAt; }
    public void setHrReviewedAt(Instant hrReviewedAt) { this.hrReviewedAt = hrReviewedAt; }
    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
}
