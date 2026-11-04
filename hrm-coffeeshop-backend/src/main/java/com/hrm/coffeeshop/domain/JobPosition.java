package com.hrm.coffeeshop.domain;

import jakarta.persistence.*;
import java.io.Serializable;
import java.math.BigDecimal;
import java.time.*;
import java.util.Objects;

/** Sinh tự động từ DDL bởi tools/gen_entities.py - đừng sửa tay. */
@Entity
@Table(name = "JobPosition")
public class JobPosition {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "PositionId")
    private Integer positionId;
    @Column(name = "PositionCode")
    private String positionCode;
    @Column(name = "PositionName")
    private String positionName;
    @Column(name = "Description")
    private String description;
    @Column(name = "IsActive")
    private Boolean isActive = Boolean.TRUE;
    @Column(name = "CreatedAt")
    private Instant createdAt = Instant.now();
    @Column(name = "UpdatedAt")
    private Instant updatedAt = Instant.now();

    public JobPosition() {}

    public Integer getPositionId() { return positionId; }
    public void setPositionId(Integer positionId) { this.positionId = positionId; }
    public String getPositionCode() { return positionCode; }
    public void setPositionCode(String positionCode) { this.positionCode = positionCode; }
    public String getPositionName() { return positionName; }
    public void setPositionName(String positionName) { this.positionName = positionName; }
    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
    public Boolean getIsActive() { return isActive; }
    public void setIsActive(Boolean isActive) { this.isActive = isActive; }
    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Instant updatedAt) { this.updatedAt = updatedAt; }

    @PreUpdate
    void touch() { this.updatedAt = Instant.now(); }
}
