package com.hrm.coffeeshop.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;

/** Sinh từ infra/sqlserver/config.sql bởi tools/gen_entities.py. */
@Entity
@Table(name = "ViolationExplanation")
public class ViolationExplanation {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "ViolationExplanationId")
    private Long violationExplanationId;
    @Column(name = "ViolationEventId")
    private Long violationEventId;
    @Column(name = "EmployeeId")
    private Long employeeId;
    @Column(name = "Explanation")
    private String explanation;
    @Column(name = "SubmittedAt")
    private Instant submittedAt;
    @Column(name = "EvidenceStorageKey")
    private String evidenceStorageKey;
    @Column(name = "CreatedAt")
    private Instant createdAt = Instant.now();

    public ViolationExplanation() {}

    public Long getViolationExplanationId() { return violationExplanationId; }
    public void setViolationExplanationId(Long violationExplanationId) { this.violationExplanationId = violationExplanationId; }
    public Long getViolationEventId() { return violationEventId; }
    public void setViolationEventId(Long violationEventId) { this.violationEventId = violationEventId; }
    public Long getEmployeeId() { return employeeId; }
    public void setEmployeeId(Long employeeId) { this.employeeId = employeeId; }
    public String getExplanation() { return explanation; }
    public void setExplanation(String explanation) { this.explanation = explanation; }
    public Instant getSubmittedAt() { return submittedAt; }
    public void setSubmittedAt(Instant submittedAt) { this.submittedAt = submittedAt; }
    public String getEvidenceStorageKey() { return evidenceStorageKey; }
    public void setEvidenceStorageKey(String evidenceStorageKey) { this.evidenceStorageKey = evidenceStorageKey; }
    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
}
