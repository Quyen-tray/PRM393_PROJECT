package com.hrm.coffeeshop.domain;

import jakarta.persistence.*;
import java.io.Serializable;
import java.math.BigDecimal;
import java.time.*;
import java.util.Objects;

/** Sinh tự động từ DDL bởi tools/gen_entities.py - đừng sửa tay. */
@Entity
@Table(name = "ChecklistTaskItem")
public class ChecklistTaskItem {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "ChecklistTaskItemId")
    private Long checklistTaskItemId;
    @Column(name = "ChecklistTaskId")
    private Long checklistTaskId;
    @Column(name = "ChecklistTemplateItemId")
    private Integer checklistTemplateItemId;
    @Column(name = "IsCompleted")
    private Boolean isCompleted = Boolean.FALSE;
    @Column(name = "CompletedAt")
    private Instant completedAt;
    @Column(name = "CompletedBy")
    private Long completedBy;
    @Column(name = "Note")
    private String note;

    public ChecklistTaskItem() {}

    public Long getChecklistTaskItemId() { return checklistTaskItemId; }
    public void setChecklistTaskItemId(Long checklistTaskItemId) { this.checklistTaskItemId = checklistTaskItemId; }
    public Long getChecklistTaskId() { return checklistTaskId; }
    public void setChecklistTaskId(Long checklistTaskId) { this.checklistTaskId = checklistTaskId; }
    public Integer getChecklistTemplateItemId() { return checklistTemplateItemId; }
    public void setChecklistTemplateItemId(Integer checklistTemplateItemId) { this.checklistTemplateItemId = checklistTemplateItemId; }
    public Boolean getIsCompleted() { return isCompleted; }
    public void setIsCompleted(Boolean isCompleted) { this.isCompleted = isCompleted; }
    public Instant getCompletedAt() { return completedAt; }
    public void setCompletedAt(Instant completedAt) { this.completedAt = completedAt; }
    public Long getCompletedBy() { return completedBy; }
    public void setCompletedBy(Long completedBy) { this.completedBy = completedBy; }
    public String getNote() { return note; }
    public void setNote(String note) { this.note = note; }
}
