package com.hrm.coffeeshop.domain;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "AttendanceSpotCheck")
public class AttendanceSpotCheck {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "SpotCheckId")
    private Long spotCheckId;

    @Column(name = "AttendanceId", nullable = false, unique = true)
    private Long attendanceId;

    @Column(name = "EmployeeId", nullable = false)
    private Long employeeId;

    @Column(name = "ShiftAssignmentId", nullable = false)
    private Long shiftAssignmentId;

    @Column(name = "IsSelected", nullable = false)
    private Boolean selected = Boolean.FALSE;

    @Column(name = "Status", nullable = false)
    private String status = "NOT_SELECTED";

    @Column(name = "ScheduledAt")
    private Instant scheduledAt;

    @Column(name = "RequestedAt")
    private Instant requestedAt;

    @Column(name = "ResponseDeadlineAt")
    private Instant responseDeadlineAt;

    @Column(name = "RespondedAt")
    private Instant respondedAt;

    @Column(name = "ResponseIdempotencyKey")
    private String responseIdempotencyKey;

    @Column(name = "CreatedAt", nullable = false)
    private Instant createdAt = Instant.now();

    public Long getSpotCheckId() { return spotCheckId; }
    public Long getAttendanceId() { return attendanceId; }
    public void setAttendanceId(Long attendanceId) { this.attendanceId = attendanceId; }
    public Long getEmployeeId() { return employeeId; }
    public void setEmployeeId(Long employeeId) { this.employeeId = employeeId; }
    public Long getShiftAssignmentId() { return shiftAssignmentId; }
    public void setShiftAssignmentId(Long shiftAssignmentId) { this.shiftAssignmentId = shiftAssignmentId; }
    public Boolean getSelected() { return selected; }
    public void setSelected(Boolean selected) { this.selected = selected; }
    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }
    public Instant getScheduledAt() { return scheduledAt; }
    public void setScheduledAt(Instant scheduledAt) { this.scheduledAt = scheduledAt; }
    public Instant getRequestedAt() { return requestedAt; }
    public void setRequestedAt(Instant requestedAt) { this.requestedAt = requestedAt; }
    public Instant getResponseDeadlineAt() { return responseDeadlineAt; }
    public void setResponseDeadlineAt(Instant responseDeadlineAt) { this.responseDeadlineAt = responseDeadlineAt; }
    public Instant getRespondedAt() { return respondedAt; }
    public void setRespondedAt(Instant respondedAt) { this.respondedAt = respondedAt; }
    public String getResponseIdempotencyKey() { return responseIdempotencyKey; }
    public void setResponseIdempotencyKey(String responseIdempotencyKey) { this.responseIdempotencyKey = responseIdempotencyKey; }
    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
}
