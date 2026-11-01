package com.hrm.coffeeshop.domain;

import jakarta.persistence.*;
import java.io.Serializable;
import java.math.BigDecimal;
import java.time.*;
import java.util.Objects;

/** Sinh tự động từ DDL bởi tools/gen_entities.py - đừng sửa tay. */
@Entity
@Table(name = "AttendanceAdjustmentHistory")
public class AttendanceAdjustmentHistory {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "AdjustmentHistoryId")
    private Long adjustmentHistoryId;
    @Column(name = "AttendanceAdjustmentRequestId")
    private Long attendanceAdjustmentRequestId;
    @Column(name = "AttendanceId")
    private Long attendanceId;
    @Column(name = "FieldName")
    private String fieldName;
    @Column(name = "OldValue")
    private String oldValue;
    @Column(name = "NewValue")
    private String newValue;
    @Column(name = "ChangedBy")
    private Long changedBy;
    @Column(name = "ChangedAt")
    private Instant changedAt = Instant.now();

    public AttendanceAdjustmentHistory() {}

    public Long getAdjustmentHistoryId() { return adjustmentHistoryId; }
    public void setAdjustmentHistoryId(Long adjustmentHistoryId) { this.adjustmentHistoryId = adjustmentHistoryId; }
    public Long getAttendanceAdjustmentRequestId() { return attendanceAdjustmentRequestId; }
    public void setAttendanceAdjustmentRequestId(Long attendanceAdjustmentRequestId) { this.attendanceAdjustmentRequestId = attendanceAdjustmentRequestId; }
    public Long getAttendanceId() { return attendanceId; }
    public void setAttendanceId(Long attendanceId) { this.attendanceId = attendanceId; }
    public String getFieldName() { return fieldName; }
    public void setFieldName(String fieldName) { this.fieldName = fieldName; }
    public String getOldValue() { return oldValue; }
    public void setOldValue(String oldValue) { this.oldValue = oldValue; }
    public String getNewValue() { return newValue; }
    public void setNewValue(String newValue) { this.newValue = newValue; }
    public Long getChangedBy() { return changedBy; }
    public void setChangedBy(Long changedBy) { this.changedBy = changedBy; }
    public Instant getChangedAt() { return changedAt; }
    public void setChangedAt(Instant changedAt) { this.changedAt = changedAt; }
}
