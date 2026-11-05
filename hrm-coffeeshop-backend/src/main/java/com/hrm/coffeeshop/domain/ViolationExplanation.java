package com.hrm.coffeeshop.domain;

import jakarta.persistence.*;
import java.time.Instant;

/** Append-only employee explanation; reviewing a violation never rewrites employee evidence. */
@Entity
@Table(name = "ViolationExplanation")
public class ViolationExplanation {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "ExplanationId") private Long explanationId;
    @Column(name = "ViolationEventId", nullable = false) private Long violationEventId;
    @Column(name = "EmployeeId", nullable = false) private Long employeeId;
    @Column(name = "Reason", nullable = false) private String reason;
    @Column(name = "EvidenceStorageKey") private String evidenceStorageKey;
    @Column(name = "CreatedAt", nullable = false) private Instant createdAt;
    public Long getExplanationId() { return explanationId; }
    public Long getViolationEventId() { return violationEventId; }
    public void setViolationEventId(Long value) { violationEventId = value; }
    public Long getEmployeeId() { return employeeId; }
    public void setEmployeeId(Long value) { employeeId = value; }
    public String getReason() { return reason; }
    public void setReason(String value) { reason = value; }
    public String getEvidenceStorageKey() { return evidenceStorageKey; }
    public void setEvidenceStorageKey(String value) { evidenceStorageKey = value; }
    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant value) { createdAt = value; }
}
