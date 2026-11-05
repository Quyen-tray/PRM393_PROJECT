package com.hrm.coffeeshop.domain;

import jakarta.persistence.*;
import java.io.Serializable;
import java.math.BigDecimal;
import java.time.*;
import java.util.Objects;

/** Sinh tự động từ DDL bởi tools/gen_entities.py - đừng sửa tay. */
@Entity
@Table(name = "PayrollPeriod")
public class PayrollPeriod {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "PayrollPeriodId")
    private Long payrollPeriodId;
    @Column(name = "PeriodCode")
    private String periodCode;
    @Column(name = "StartDate")
    private LocalDate startDate;
    @Column(name = "EndDate")
    private LocalDate endDate;
    @Column(name = "PeriodStatus")
    private String periodStatus = "OPEN";
    @Column(name = "CreatedBy")
    private Long createdBy;
    @Column(name = "CreatedAt")
    private Instant createdAt = Instant.now();
    @Column(name = "ManagerApprovedBy")
    private Long managerApprovedBy;
    @Column(name = "ManagerApprovedAt")
    private Instant managerApprovedAt;
    @Column(name = "HrApprovedBy")
    private Long hrApprovedBy;
    @Column(name = "HrApprovedAt")
    private Instant hrApprovedAt;
    @Column(name = "LockedBy")
    private Long lockedBy;
    @Column(name = "LockedAt")
    private Instant lockedAt;
    @Column(name = "ReopenedAt")
    private Instant reopenedAt;
    @Column(name = "Note")
    private String note;

    public PayrollPeriod() {}

    public Long getPayrollPeriodId() { return payrollPeriodId; }
    public void setPayrollPeriodId(Long payrollPeriodId) { this.payrollPeriodId = payrollPeriodId; }
    public String getPeriodCode() { return periodCode; }
    public void setPeriodCode(String periodCode) { this.periodCode = periodCode; }
    public LocalDate getStartDate() { return startDate; }
    public void setStartDate(LocalDate startDate) { this.startDate = startDate; }
    public LocalDate getEndDate() { return endDate; }
    public void setEndDate(LocalDate endDate) { this.endDate = endDate; }
    public String getPeriodStatus() { return periodStatus; }
    public void setPeriodStatus(String periodStatus) { this.periodStatus = periodStatus; }
    public Long getCreatedBy() { return createdBy; }
    public void setCreatedBy(Long createdBy) { this.createdBy = createdBy; }
    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
    public Long getManagerApprovedBy() { return managerApprovedBy; }
    public void setManagerApprovedBy(Long managerApprovedBy) { this.managerApprovedBy = managerApprovedBy; }
    public Instant getManagerApprovedAt() { return managerApprovedAt; }
    public void setManagerApprovedAt(Instant managerApprovedAt) { this.managerApprovedAt = managerApprovedAt; }
    public Long getHrApprovedBy() { return hrApprovedBy; }
    public void setHrApprovedBy(Long hrApprovedBy) { this.hrApprovedBy = hrApprovedBy; }
    public Instant getHrApprovedAt() { return hrApprovedAt; }
    public void setHrApprovedAt(Instant hrApprovedAt) { this.hrApprovedAt = hrApprovedAt; }
    public Long getLockedBy() { return lockedBy; }
    public void setLockedBy(Long lockedBy) { this.lockedBy = lockedBy; }
    public Instant getLockedAt() { return lockedAt; }
    public void setLockedAt(Instant lockedAt) { this.lockedAt = lockedAt; }
    public Instant getReopenedAt() { return reopenedAt; }
    public void setReopenedAt(Instant reopenedAt) { this.reopenedAt = reopenedAt; }
    public String getNote() { return note; }
    public void setNote(String note) { this.note = note; }
}
