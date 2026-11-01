package com.hrm.coffeeshop.domain;

import jakarta.persistence.*;
import java.io.Serializable;
import java.math.BigDecimal;
import java.time.*;
import java.util.Objects;

/** Sinh tự động từ DDL bởi tools/gen_entities.py - đừng sửa tay. */
@Entity
@Table(name = "AttendanceExceptionRequest")
public class AttendanceExceptionRequest {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "ExceptionRequestId")
    private Long exceptionRequestId;
    @Version
    @Column(name = "RowVersion")
    private Long rowVersion = 0L;
    @Column(name = "EmployeeId")
    private Long employeeId;
    @Column(name = "ShiftAssignmentId")
    private Long shiftAssignmentId;
    @Column(name = "AttendanceId")
    private Long attendanceId;
    @Column(name = "RequestType")
    private String requestType;
    @Column(name = "RequestedCheckInAt")
    private Instant requestedCheckInAt;
    @Column(name = "RequestedCheckOutAt")
    private Instant requestedCheckOutAt;
    @Column(name = "Reason")
    private String reason;
    @Column(name = "RequestStatus")
    private String requestStatus = "PENDING";
    @Column(name = "SubmittedAt")
    private Instant submittedAt = Instant.now();
    @Column(name = "ReviewedBy")
    private Long reviewedBy;
    @Column(name = "ReviewedAt")
    private Instant reviewedAt;
    @Column(name = "ReviewNote")
    private String reviewNote;
    @Column(name = "EvidenceStorageKey")
    private String evidenceStorageKey;
    @Column(name = "RetainUntil")
    private LocalDate retainUntil;

    public AttendanceExceptionRequest() {}

    public Long getExceptionRequestId() { return exceptionRequestId; }
    public void setExceptionRequestId(Long exceptionRequestId) { this.exceptionRequestId = exceptionRequestId; }
    public Long getRowVersion() { return rowVersion; }
    public void setRowVersion(Long rowVersion) { this.rowVersion = rowVersion; }
    public Long getEmployeeId() { return employeeId; }
    public void setEmployeeId(Long employeeId) { this.employeeId = employeeId; }
    public Long getShiftAssignmentId() { return shiftAssignmentId; }
    public void setShiftAssignmentId(Long shiftAssignmentId) { this.shiftAssignmentId = shiftAssignmentId; }
    public Long getAttendanceId() { return attendanceId; }
    public void setAttendanceId(Long attendanceId) { this.attendanceId = attendanceId; }
    public String getRequestType() { return requestType; }
    public void setRequestType(String requestType) { this.requestType = requestType; }
    public Instant getRequestedCheckInAt() { return requestedCheckInAt; }
    public void setRequestedCheckInAt(Instant requestedCheckInAt) { this.requestedCheckInAt = requestedCheckInAt; }
    public Instant getRequestedCheckOutAt() { return requestedCheckOutAt; }
    public void setRequestedCheckOutAt(Instant requestedCheckOutAt) { this.requestedCheckOutAt = requestedCheckOutAt; }
    public String getReason() { return reason; }
    public void setReason(String reason) { this.reason = reason; }
    public String getRequestStatus() { return requestStatus; }
    public void setRequestStatus(String requestStatus) { this.requestStatus = requestStatus; }
    public Instant getSubmittedAt() { return submittedAt; }
    public void setSubmittedAt(Instant submittedAt) { this.submittedAt = submittedAt; }
    public Long getReviewedBy() { return reviewedBy; }
    public void setReviewedBy(Long reviewedBy) { this.reviewedBy = reviewedBy; }
    public Instant getReviewedAt() { return reviewedAt; }
    public void setReviewedAt(Instant reviewedAt) { this.reviewedAt = reviewedAt; }
    public String getReviewNote() { return reviewNote; }
    public void setReviewNote(String reviewNote) { this.reviewNote = reviewNote; }
    public String getEvidenceStorageKey() { return evidenceStorageKey; }
    public void setEvidenceStorageKey(String evidenceStorageKey) { this.evidenceStorageKey = evidenceStorageKey; }
    public LocalDate getRetainUntil() { return retainUntil; }
    public void setRetainUntil(LocalDate retainUntil) { this.retainUntil = retainUntil; }
}
