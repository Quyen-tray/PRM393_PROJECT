package com.hrm.coffeeshop.domain;

import jakarta.persistence.*;
import java.io.Serializable;
import java.math.BigDecimal;
import java.time.*;
import java.util.Objects;

/** Sinh tự động từ DDL bởi tools/gen_entities.py - đừng sửa tay. */
@Entity
@Table(name = "ChecklistTemplate")
public class ChecklistTemplate {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "ChecklistTemplateId")
    private Integer checklistTemplateId;
    @Column(name = "StoreId")
    private Integer storeId;
    @Column(name = "ChecklistCode")
    private String checklistCode;
    @Column(name = "ChecklistName")
    private String checklistName;
    @Column(name = "ChecklistType")
    private String checklistType;
    @Column(name = "IsManagerApprovalRequired")
    private Boolean isManagerApprovalRequired = Boolean.FALSE;
    @Column(name = "Version")
    private Integer version = 1;
    @Column(name = "IsActive")
    private Boolean isActive = Boolean.TRUE;

    public ChecklistTemplate() {}

    public Integer getChecklistTemplateId() { return checklistTemplateId; }
    public void setChecklistTemplateId(Integer checklistTemplateId) { this.checklistTemplateId = checklistTemplateId; }
    public Integer getStoreId() { return storeId; }
    public void setStoreId(Integer storeId) { this.storeId = storeId; }
    public String getChecklistCode() { return checklistCode; }
    public void setChecklistCode(String checklistCode) { this.checklistCode = checklistCode; }
    public String getChecklistName() { return checklistName; }
    public void setChecklistName(String checklistName) { this.checklistName = checklistName; }
    public String getChecklistType() { return checklistType; }
    public void setChecklistType(String checklistType) { this.checklistType = checklistType; }
    public Boolean getIsManagerApprovalRequired() { return isManagerApprovalRequired; }
    public void setIsManagerApprovalRequired(Boolean isManagerApprovalRequired) { this.isManagerApprovalRequired = isManagerApprovalRequired; }
    public Integer getVersion() { return version; }
    public void setVersion(Integer version) { this.version = version; }
    public Boolean getIsActive() { return isActive; }
    public void setIsActive(Boolean isActive) { this.isActive = isActive; }
}
