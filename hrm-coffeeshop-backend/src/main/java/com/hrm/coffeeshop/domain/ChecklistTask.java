package com.hrm.coffeeshop.domain;

import jakarta.persistence.*;
import java.io.Serializable;
import java.math.BigDecimal;
import java.time.*;
import java.util.Objects;

/** Sinh tự động từ DDL bởi tools/gen_entities.py - đừng sửa tay. */
@Entity
@Table(name = "ChecklistTask")
public class ChecklistTask {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "ChecklistTaskId")
    private Long checklistTaskId;
    @Column(name = "ChecklistTemplateId")
    private Integer checklistTemplateId;
    @Column(name = "ShiftAssignmentId")
    private Long shiftAssignmentId;
    @Column(name = "EmployeeId")
    private Long employeeId;
    @Column(name = "DueAt")
    private Instant dueAt;
    @Column(name = "StartedAt")
    private Instant startedAt;
    @Column(name = "SubmittedAt")
    private Instant submittedAt;
    @Column(name = "RunStatus")
    private String runStatus = "PENDING";
    @Column(name = "ManagerStatus")
    private String managerStatus = "NOT_REQUIRED";
    @Column(name = "ChecklistInstanceId")
    private Long checklistInstanceId;

    public ChecklistTask() {}

    public Long getChecklistTaskId() { return checklistTaskId; }
    public void setChecklistTaskId(Long checklistTaskId) { this.checklistTaskId = checklistTaskId; }
    public Integer getChecklistTemplateId() { return checklistTemplateId; }
    public void setChecklistTemplateId(Integer checklistTemplateId) { this.checklistTemplateId = checklistTemplateId; }
    public Long getShiftAssignmentId() { return shiftAssignmentId; }
    public void setShiftAssignmentId(Long shiftAssignmentId) { this.shiftAssignmentId = shiftAssignmentId; }
    public Long getEmployeeId() { return employeeId; }
    public void setEmployeeId(Long employeeId) { this.employeeId = employeeId; }
    public Instant getDueAt() { return dueAt; }
    public void setDueAt(Instant dueAt) { this.dueAt = dueAt; }
    public Instant getStartedAt() { return startedAt; }
    public void setStartedAt(Instant startedAt) { this.startedAt = startedAt; }
    public Instant getSubmittedAt() { return submittedAt; }
    public void setSubmittedAt(Instant submittedAt) { this.submittedAt = submittedAt; }
    public String getRunStatus() { return runStatus; }
    public void setRunStatus(String runStatus) { this.runStatus = runStatus; }
    public String getManagerStatus() { return managerStatus; }
    public void setManagerStatus(String managerStatus) { this.managerStatus = managerStatus; }
    public Long getChecklistInstanceId() { return checklistInstanceId; }
    public void setChecklistInstanceId(Long checklistInstanceId) { this.checklistInstanceId = checklistInstanceId; }
}
