package com.hrm.coffeeshop.domain;

import jakarta.persistence.*;
import java.io.Serializable;
import java.math.BigDecimal;
import java.time.*;
import java.util.Objects;

/** Sinh tự động từ DDL bởi tools/gen_entities.py - đừng sửa tay. */
@Entity
@Table(name = "PositionTrainingRequirement")
public class PositionTrainingRequirement {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "RequirementId")
    private Integer requirementId;
    @Column(name = "PositionId")
    private Integer positionId;
    @Column(name = "CourseId")
    private Integer courseId;
    @Column(name = "IsMandatory")
    private Boolean isMandatory = Boolean.TRUE;
    @Column(name = "BlocksShiftAssignment")
    private Boolean blocksShiftAssignment = Boolean.FALSE;
    @Column(name = "EffectiveFrom")
    private LocalDate effectiveFrom;
    @Column(name = "EffectiveTo")
    private LocalDate effectiveTo;

    public PositionTrainingRequirement() {}

    public Integer getRequirementId() { return requirementId; }
    public void setRequirementId(Integer requirementId) { this.requirementId = requirementId; }
    public Integer getPositionId() { return positionId; }
    public void setPositionId(Integer positionId) { this.positionId = positionId; }
    public Integer getCourseId() { return courseId; }
    public void setCourseId(Integer courseId) { this.courseId = courseId; }
    public Boolean getIsMandatory() { return isMandatory; }
    public void setIsMandatory(Boolean isMandatory) { this.isMandatory = isMandatory; }
    public Boolean getBlocksShiftAssignment() { return blocksShiftAssignment; }
    public void setBlocksShiftAssignment(Boolean blocksShiftAssignment) { this.blocksShiftAssignment = blocksShiftAssignment; }
    public LocalDate getEffectiveFrom() { return effectiveFrom; }
    public void setEffectiveFrom(LocalDate effectiveFrom) { this.effectiveFrom = effectiveFrom; }
    public LocalDate getEffectiveTo() { return effectiveTo; }
    public void setEffectiveTo(LocalDate effectiveTo) { this.effectiveTo = effectiveTo; }
}
