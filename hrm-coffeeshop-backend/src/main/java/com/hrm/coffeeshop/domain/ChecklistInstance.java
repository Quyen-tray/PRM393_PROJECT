package com.hrm.coffeeshop.domain;

import jakarta.persistence.*;
import java.io.Serializable;
import java.math.BigDecimal;
import java.time.*;
import java.util.Objects;

/** Sinh tự động từ DDL bởi tools/gen_entities.py - đừng sửa tay. */
@Entity
@Table(name = "ChecklistInstance")
public class ChecklistInstance {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "ChecklistInstanceId")
    private Long checklistInstanceId;
    @Column(name = "ChecklistTemplateId")
    private Integer checklistTemplateId;
    @Column(name = "WorkDate")
    private LocalDate workDate;
    @Column(name = "WorkShiftId")
    private Integer workShiftId;
    @Column(name = "CreatedAt")
    private Instant createdAt = Instant.now();

    public ChecklistInstance() {}

    public Long getChecklistInstanceId() { return checklistInstanceId; }
    public void setChecklistInstanceId(Long checklistInstanceId) { this.checklistInstanceId = checklistInstanceId; }
    public Integer getChecklistTemplateId() { return checklistTemplateId; }
    public void setChecklistTemplateId(Integer checklistTemplateId) { this.checklistTemplateId = checklistTemplateId; }
    public LocalDate getWorkDate() { return workDate; }
    public void setWorkDate(LocalDate workDate) { this.workDate = workDate; }
    public Integer getWorkShiftId() { return workShiftId; }
    public void setWorkShiftId(Integer workShiftId) { this.workShiftId = workShiftId; }
    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
}
