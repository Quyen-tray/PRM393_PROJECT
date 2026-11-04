package com.hrm.coffeeshop.domain;

import jakarta.persistence.*;
import java.io.Serializable;
import java.math.BigDecimal;
import java.time.*;
import java.util.Objects;

/** Sinh tự động từ DDL bởi tools/gen_entities.py - đừng sửa tay. */
@Entity
@Table(name = "EmployeeSkill")
public class EmployeeSkill {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "AssessmentId")
    private Long assessmentId;
    @Column(name = "EmployeeId")
    private Long employeeId;
    @Column(name = "SkillId")
    private Integer skillId;
    @Column(name = "SkillLevel")
    private Integer skillLevel;
    @Column(name = "Note")
    private String note;
    @Column(name = "AssessedBy")
    private Long assessedBy;
    @Column(name = "AssessedAt")
    private Instant assessedAt = Instant.now();

    public EmployeeSkill() {}

    public Long getAssessmentId() { return assessmentId; }
    public void setAssessmentId(Long assessmentId) { this.assessmentId = assessmentId; }
    public Long getEmployeeId() { return employeeId; }
    public void setEmployeeId(Long employeeId) { this.employeeId = employeeId; }
    public Integer getSkillId() { return skillId; }
    public void setSkillId(Integer skillId) { this.skillId = skillId; }
    public Integer getSkillLevel() { return skillLevel; }
    public void setSkillLevel(Integer skillLevel) { this.skillLevel = skillLevel; }
    public String getNote() { return note; }
    public void setNote(String note) { this.note = note; }
    public Long getAssessedBy() { return assessedBy; }
    public void setAssessedBy(Long assessedBy) { this.assessedBy = assessedBy; }
    public Instant getAssessedAt() { return assessedAt; }
    public void setAssessedAt(Instant assessedAt) { this.assessedAt = assessedAt; }
}
