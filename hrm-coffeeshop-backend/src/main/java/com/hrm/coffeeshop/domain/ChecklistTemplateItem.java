package com.hrm.coffeeshop.domain;

import jakarta.persistence.*;
import java.io.Serializable;
import java.math.BigDecimal;
import java.time.*;
import java.util.Objects;

/** Sinh tự động từ DDL bởi tools/gen_entities.py - đừng sửa tay. */
@Entity
@Table(name = "ChecklistTemplateItem")
public class ChecklistTemplateItem {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "ChecklistTemplateItemId")
    private Integer checklistTemplateItemId;
    @Column(name = "ChecklistTemplateId")
    private Integer checklistTemplateId;
    @Column(name = "ItemName")
    private String itemName;
    @Column(name = "Instructions")
    private String instructions;
    @Column(name = "IsMandatory")
    private Boolean isMandatory = Boolean.TRUE;
    @Column(name = "RequiresEvidence")
    private Boolean requiresEvidence = Boolean.FALSE;
    @Column(name = "RequiresManagerApproval")
    private Boolean requiresManagerApproval = Boolean.FALSE;
    @Column(name = "SortOrder")
    private Integer sortOrder = 1;

    public ChecklistTemplateItem() {}

    public Integer getChecklistTemplateItemId() { return checklistTemplateItemId; }
    public void setChecklistTemplateItemId(Integer checklistTemplateItemId) { this.checklistTemplateItemId = checklistTemplateItemId; }
    public Integer getChecklistTemplateId() { return checklistTemplateId; }
    public void setChecklistTemplateId(Integer checklistTemplateId) { this.checklistTemplateId = checklistTemplateId; }
    public String getItemName() { return itemName; }
    public void setItemName(String itemName) { this.itemName = itemName; }
    public String getInstructions() { return instructions; }
    public void setInstructions(String instructions) { this.instructions = instructions; }
    public Boolean getIsMandatory() { return isMandatory; }
    public void setIsMandatory(Boolean isMandatory) { this.isMandatory = isMandatory; }
    public Boolean getRequiresEvidence() { return requiresEvidence; }
    public void setRequiresEvidence(Boolean requiresEvidence) { this.requiresEvidence = requiresEvidence; }
    public Boolean getRequiresManagerApproval() { return requiresManagerApproval; }
    public void setRequiresManagerApproval(Boolean requiresManagerApproval) { this.requiresManagerApproval = requiresManagerApproval; }
    public Integer getSortOrder() { return sortOrder; }
    public void setSortOrder(Integer sortOrder) { this.sortOrder = sortOrder; }
}
