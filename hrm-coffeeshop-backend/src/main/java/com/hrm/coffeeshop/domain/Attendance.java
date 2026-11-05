package com.hrm.coffeeshop.domain;

import jakarta.persistence.*;
import java.io.Serializable;
import java.math.BigDecimal;
import java.time.*;
import java.util.Objects;

/** Sinh tự động từ DDL bởi tools/gen_entities.py - đừng sửa tay. */
@Entity
@Table(name = "Attendance")
public class Attendance {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "AttendanceId")
    private Long attendanceId;
    @Column(name = "ShiftAssignmentId")
    private Long shiftAssignmentId;
    @Column(name = "EmployeeId")
    private Long employeeId;
    @Column(name = "CheckInAt")
    private Instant checkInAt;
    @Column(name = "CheckOutAt")
    private Instant checkOutAt;
    @Column(name = "CheckInLatitude")
    private BigDecimal checkInLatitude;
    @Column(name = "CheckInLongitude")
    private BigDecimal checkInLongitude;
    @Column(name = "CheckInAccuracyM")
    private BigDecimal checkInAccuracyM;
    @Column(name = "CheckOutLatitude")
    private BigDecimal checkOutLatitude;
    @Column(name = "CheckOutLongitude")
    private BigDecimal checkOutLongitude;
    @Column(name = "CheckOutAccuracyM")
    private BigDecimal checkOutAccuracyM;
    @Column(name = "CheckInMethod")
    private String checkInMethod;
    @Column(name = "CheckOutMethod")
    private String checkOutMethod;
    @Column(name = "CheckInFaceStatus")
    private String checkInFaceStatus;
    @Column(name = "CheckOutFaceStatus")
    private String checkOutFaceStatus;
    @Column(name = "AttendanceStatus")
    private String attendanceStatus = "IN_PROGRESS";
    @Column(name = "LateMinutes")
    private Integer lateMinutes = 0;
    @Column(name = "EarlyLeaveMinutes")
    private Integer earlyLeaveMinutes = 0;
    @Column(name = "WorkedMinutes")
    private Integer workedMinutes;
    @Column(name = "ApprovedOTMinutes")
    private Integer approvedOTMinutes = 0;
    @Column(name = "ManagerReviewedBy")
    private Long managerReviewedBy;
    @Column(name = "ManagerReviewedAt")
    private Instant managerReviewedAt;
    @Column(name = "PayrollStatus")
    private String payrollStatus = "OPEN";
    @Column(name = "Note")
    private String note;
    @Column(name = "CreatedAt")
    private Instant createdAt = Instant.now();
    @Column(name = "UpdatedAt")
    private Instant updatedAt = Instant.now();
    @Column(name = "CheckInIdempotencyKey")
    private String checkInIdempotencyKey;
    @Column(name = "CheckOutIdempotencyKey")
    private String checkOutIdempotencyKey;
    @Column(name = "CheckInDeviceId")
    private Long checkInDeviceId;
    @Column(name = "CheckOutDeviceId")
    private Long checkOutDeviceId;
    @Column(name = "GraceApplied")
    private Boolean graceApplied = Boolean.FALSE;

    public Attendance() {}

    public Long getAttendanceId() { return attendanceId; }
    public void setAttendanceId(Long attendanceId) { this.attendanceId = attendanceId; }
    public Long getShiftAssignmentId() { return shiftAssignmentId; }
    public void setShiftAssignmentId(Long shiftAssignmentId) { this.shiftAssignmentId = shiftAssignmentId; }
    public Long getEmployeeId() { return employeeId; }
    public void setEmployeeId(Long employeeId) { this.employeeId = employeeId; }
    public Instant getCheckInAt() { return checkInAt; }
    public void setCheckInAt(Instant checkInAt) { this.checkInAt = checkInAt; }
    public Instant getCheckOutAt() { return checkOutAt; }
    public void setCheckOutAt(Instant checkOutAt) { this.checkOutAt = checkOutAt; }
    public BigDecimal getCheckInLatitude() { return checkInLatitude; }
    public void setCheckInLatitude(BigDecimal checkInLatitude) { this.checkInLatitude = checkInLatitude; }
    public BigDecimal getCheckInLongitude() { return checkInLongitude; }
    public void setCheckInLongitude(BigDecimal checkInLongitude) { this.checkInLongitude = checkInLongitude; }
    public BigDecimal getCheckInAccuracyM() { return checkInAccuracyM; }
    public void setCheckInAccuracyM(BigDecimal checkInAccuracyM) { this.checkInAccuracyM = checkInAccuracyM; }
    public BigDecimal getCheckOutLatitude() { return checkOutLatitude; }
    public void setCheckOutLatitude(BigDecimal checkOutLatitude) { this.checkOutLatitude = checkOutLatitude; }
    public BigDecimal getCheckOutLongitude() { return checkOutLongitude; }
    public void setCheckOutLongitude(BigDecimal checkOutLongitude) { this.checkOutLongitude = checkOutLongitude; }
    public BigDecimal getCheckOutAccuracyM() { return checkOutAccuracyM; }
    public void setCheckOutAccuracyM(BigDecimal checkOutAccuracyM) { this.checkOutAccuracyM = checkOutAccuracyM; }
    public String getCheckInMethod() { return checkInMethod; }
    public void setCheckInMethod(String checkInMethod) { this.checkInMethod = checkInMethod; }
    public String getCheckOutMethod() { return checkOutMethod; }
    public void setCheckOutMethod(String checkOutMethod) { this.checkOutMethod = checkOutMethod; }
    public String getCheckInFaceStatus() { return checkInFaceStatus; }
    public void setCheckInFaceStatus(String checkInFaceStatus) { this.checkInFaceStatus = checkInFaceStatus; }
    public String getCheckOutFaceStatus() { return checkOutFaceStatus; }
    public void setCheckOutFaceStatus(String checkOutFaceStatus) { this.checkOutFaceStatus = checkOutFaceStatus; }
    public String getAttendanceStatus() { return attendanceStatus; }
    public void setAttendanceStatus(String attendanceStatus) { this.attendanceStatus = attendanceStatus; }
    public Integer getLateMinutes() { return lateMinutes; }
    public void setLateMinutes(Integer lateMinutes) { this.lateMinutes = lateMinutes; }
    public Integer getEarlyLeaveMinutes() { return earlyLeaveMinutes; }
    public void setEarlyLeaveMinutes(Integer earlyLeaveMinutes) { this.earlyLeaveMinutes = earlyLeaveMinutes; }
    public Integer getWorkedMinutes() { return workedMinutes; }
    public void setWorkedMinutes(Integer workedMinutes) { this.workedMinutes = workedMinutes; }
    public Integer getApprovedOTMinutes() { return approvedOTMinutes; }
    public void setApprovedOTMinutes(Integer approvedOTMinutes) { this.approvedOTMinutes = approvedOTMinutes; }
    public Long getManagerReviewedBy() { return managerReviewedBy; }
    public void setManagerReviewedBy(Long managerReviewedBy) { this.managerReviewedBy = managerReviewedBy; }
    public Instant getManagerReviewedAt() { return managerReviewedAt; }
    public void setManagerReviewedAt(Instant managerReviewedAt) { this.managerReviewedAt = managerReviewedAt; }
    public String getPayrollStatus() { return payrollStatus; }
    public void setPayrollStatus(String payrollStatus) { this.payrollStatus = payrollStatus; }
    public String getNote() { return note; }
    public void setNote(String note) { this.note = note; }
    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Instant updatedAt) { this.updatedAt = updatedAt; }
    public String getCheckInIdempotencyKey() { return checkInIdempotencyKey; }
    public void setCheckInIdempotencyKey(String checkInIdempotencyKey) { this.checkInIdempotencyKey = checkInIdempotencyKey; }
    public String getCheckOutIdempotencyKey() { return checkOutIdempotencyKey; }
    public void setCheckOutIdempotencyKey(String checkOutIdempotencyKey) { this.checkOutIdempotencyKey = checkOutIdempotencyKey; }
    public Long getCheckInDeviceId() { return checkInDeviceId; }
    public void setCheckInDeviceId(Long checkInDeviceId) { this.checkInDeviceId = checkInDeviceId; }
    public Long getCheckOutDeviceId() { return checkOutDeviceId; }
    public void setCheckOutDeviceId(Long checkOutDeviceId) { this.checkOutDeviceId = checkOutDeviceId; }
    public Boolean getGraceApplied() { return graceApplied; }
    public void setGraceApplied(Boolean graceApplied) { this.graceApplied = graceApplied; }

    @PreUpdate
    void touch() { this.updatedAt = Instant.now(); }
}
