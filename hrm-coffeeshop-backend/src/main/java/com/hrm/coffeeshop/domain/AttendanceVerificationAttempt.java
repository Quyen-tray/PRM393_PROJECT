package com.hrm.coffeeshop.domain;

import jakarta.persistence.*;

import java.time.Instant;

/** B-17: lần xác minh GPS/khuôn mặt thất bại. Không phải bản ghi công; dùng cho đối soát, giải trình và phát hiện giả lập. */
@Entity
@Table(name = "AttendanceVerificationAttempt")
public class AttendanceVerificationAttempt {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "AttemptId")
    private Long attemptId;
    @Column(name = "EmployeeId")
    private Long employeeId;
    @Column(name = "ShiftAssignmentId")
    private Long shiftAssignmentId;
    @Column(name = "EventType")
    private String eventType;
    @Column(name = "VerificationType")
    private String verificationType;
    @Column(name = "FailureCode")
    private String failureCode;
    @Column(name = "DeviceId")
    private Long deviceId;
    @Column(name = "AttemptedAt")
    private Instant attemptedAt;

    public AttendanceVerificationAttempt() {}

    public Long getAttemptId() { return attemptId; }
    public Long getEmployeeId() { return employeeId; }
    public void setEmployeeId(Long v) { employeeId = v; }
    public Long getShiftAssignmentId() { return shiftAssignmentId; }
    public void setShiftAssignmentId(Long v) { shiftAssignmentId = v; }
    public String getEventType() { return eventType; }
    public void setEventType(String v) { eventType = v; }
    public String getVerificationType() { return verificationType; }
    public void setVerificationType(String v) { verificationType = v; }
    public String getFailureCode() { return failureCode; }
    public void setFailureCode(String v) { failureCode = v; }
    public Long getDeviceId() { return deviceId; }
    public void setDeviceId(Long v) { deviceId = v; }
    public Instant getAttemptedAt() { return attemptedAt; }
    public void setAttemptedAt(Instant v) { attemptedAt = v; }
}
