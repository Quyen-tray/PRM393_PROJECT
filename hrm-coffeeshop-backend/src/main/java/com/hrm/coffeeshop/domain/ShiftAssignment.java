package com.hrm.coffeeshop.domain;

import jakarta.persistence.*;
import java.io.Serializable;
import java.math.BigDecimal;
import java.time.*;
import java.util.Objects;

/** Sinh tự động từ DDL bởi tools/gen_entities.py - đừng sửa tay. */
@Entity
@Table(name = "ShiftAssignment")
public class ShiftAssignment {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "ShiftAssignmentId")
    private Long shiftAssignmentId;
    @Column(name = "EmployeeId")
    private Long employeeId;
    @Column(name = "WorkShiftId")
    private Integer workShiftId;
    @Column(name = "WorkDate")
    private LocalDate workDate;
    @Column(name = "PlannedStartAt")
    private Instant plannedStartAt;
    @Column(name = "PlannedEndAt")
    private Instant plannedEndAt;
    @Column(name = "ScheduleStatus")
    private String scheduleStatus = "PUBLISHED";
    @Column(name = "CreatedBy")
    private Long createdBy;
    @Column(name = "CreatedAt")
    private Instant createdAt = Instant.now();
    @Column(name = "UpdatedAt")
    private Instant updatedAt = Instant.now();
    @Column(name = "Note")
    private String note;

    public ShiftAssignment() {}

    public Long getShiftAssignmentId() { return shiftAssignmentId; }
    public void setShiftAssignmentId(Long shiftAssignmentId) { this.shiftAssignmentId = shiftAssignmentId; }
    public Long getEmployeeId() { return employeeId; }
    public void setEmployeeId(Long employeeId) { this.employeeId = employeeId; }
    public Integer getWorkShiftId() { return workShiftId; }
    public void setWorkShiftId(Integer workShiftId) { this.workShiftId = workShiftId; }
    public LocalDate getWorkDate() { return workDate; }
    public void setWorkDate(LocalDate workDate) { this.workDate = workDate; }
    public Instant getPlannedStartAt() { return plannedStartAt; }
    public void setPlannedStartAt(Instant plannedStartAt) { this.plannedStartAt = plannedStartAt; }
    public Instant getPlannedEndAt() { return plannedEndAt; }
    public void setPlannedEndAt(Instant plannedEndAt) { this.plannedEndAt = plannedEndAt; }
    public String getScheduleStatus() { return scheduleStatus; }
    public void setScheduleStatus(String scheduleStatus) { this.scheduleStatus = scheduleStatus; }
    public Long getCreatedBy() { return createdBy; }
    public void setCreatedBy(Long createdBy) { this.createdBy = createdBy; }
    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Instant updatedAt) { this.updatedAt = updatedAt; }
    public String getNote() { return note; }
    public void setNote(String note) { this.note = note; }

    @PreUpdate
    void touch() { this.updatedAt = Instant.now(); }
}
