package com.hrm.coffeeshop.domain;

import jakarta.persistence.*;
import java.io.Serializable;
import java.math.BigDecimal;
import java.time.*;
import java.util.Objects;

/** Sinh tự động từ DDL bởi tools/gen_entities.py - đừng sửa tay. */
@Entity
@Table(name = "OvertimeRequest")
public class OvertimeRequest {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "OvertimeRequestId")
    private Long overtimeRequestId;
    @Version
    @Column(name = "RowVersion")
    private Long rowVersion;
    @Column(name = "ShiftAssignmentId")
    private Long shiftAssignmentId;
    @Column(name = "EmployeeId")
    private Long employeeId;
    @Column(name = "RequestedStartAt")
    private Instant requestedStartAt;
    @Column(name = "RequestedEndAt")
    private Instant requestedEndAt;
    @Column(name = "Reason")
    private String reason;
    @Column(name = "ApprovalStatus")
    private String approvalStatus = "PENDING";
    @Column(name = "RequestedAt")
    private Instant requestedAt = Instant.now();
    @Column(name = "ReviewedBy")
    private Long reviewedBy;
    @Column(name = "ReviewedAt")
    private Instant reviewedAt;
    @Column(name = "ReviewNote")
    private String reviewNote;

    public OvertimeRequest() {}

    public Long getOvertimeRequestId() { return overtimeRequestId; }
    public void setOvertimeRequestId(Long overtimeRequestId) { this.overtimeRequestId = overtimeRequestId; }
    public Long getRowVersion() { return rowVersion; }
    public void setRowVersion(Long rowVersion) { this.rowVersion = rowVersion; }
    public Long getShiftAssignmentId() { return shiftAssignmentId; }
    public void setShiftAssignmentId(Long shiftAssignmentId) { this.shiftAssignmentId = shiftAssignmentId; }
    public Long getEmployeeId() { return employeeId; }
    public void setEmployeeId(Long employeeId) { this.employeeId = employeeId; }
    public Instant getRequestedStartAt() { return requestedStartAt; }
    public void setRequestedStartAt(Instant requestedStartAt) { this.requestedStartAt = requestedStartAt; }
    public Instant getRequestedEndAt() { return requestedEndAt; }
    public void setRequestedEndAt(Instant requestedEndAt) { this.requestedEndAt = requestedEndAt; }
    public String getReason() { return reason; }
    public void setReason(String reason) { this.reason = reason; }
    public String getApprovalStatus() { return approvalStatus; }
    public void setApprovalStatus(String approvalStatus) { this.approvalStatus = approvalStatus; }
    public Instant getRequestedAt() { return requestedAt; }
    public void setRequestedAt(Instant requestedAt) { this.requestedAt = requestedAt; }
    public Long getReviewedBy() { return reviewedBy; }
    public void setReviewedBy(Long reviewedBy) { this.reviewedBy = reviewedBy; }
    public Instant getReviewedAt() { return reviewedAt; }
    public void setReviewedAt(Instant reviewedAt) { this.reviewedAt = reviewedAt; }
    public String getReviewNote() { return reviewNote; }
    public void setReviewNote(String reviewNote) { this.reviewNote = reviewNote; }
}
