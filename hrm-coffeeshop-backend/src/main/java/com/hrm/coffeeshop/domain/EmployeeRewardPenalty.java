package com.hrm.coffeeshop.domain;

import jakarta.persistence.*;
import java.io.Serializable;
import java.math.BigDecimal;
import java.time.*;
import java.util.Objects;

/** Sinh tự động từ DDL bởi tools/gen_entities.py - đừng sửa tay. */
@Entity
@Table(name = "EmployeeRewardPenalty")
public class EmployeeRewardPenalty {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "RewardPenaltyId")
    private Long rewardPenaltyId;
    @Version
    @Column(name = "RowVersion")
    private Long rowVersion;
    @Column(name = "DecisionType")
    private String decisionType;
    @Column(name = "EmployeeId")
    private Long employeeId;
    @Column(name = "RuleId")
    private Integer ruleId;
    @Column(name = "ViolationEventId")
    private Long violationEventId;
    @Column(name = "EffectiveDate")
    private Instant effectiveDate = Instant.now();
    @Column(name = "Details")
    private String details;
    @Column(name = "Amount")
    private BigDecimal amount;
    @Column(name = "DecisionStatus")
    private String decisionStatus = "PENDING";
    @Column(name = "ProposedBy")
    private Long proposedBy;
    @Column(name = "ApprovedBy")
    private Long approvedBy;
    @Column(name = "ApprovedAt")
    private Instant approvedAt;
    @Column(name = "ReviewNote")
    private String reviewNote;

    public EmployeeRewardPenalty() {}

    public Long getRewardPenaltyId() { return rewardPenaltyId; }
    public void setRewardPenaltyId(Long rewardPenaltyId) { this.rewardPenaltyId = rewardPenaltyId; }
    public Long getRowVersion() { return rowVersion; }
    public void setRowVersion(Long rowVersion) { this.rowVersion = rowVersion; }
    public String getDecisionType() { return decisionType; }
    public void setDecisionType(String decisionType) { this.decisionType = decisionType; }
    public Long getEmployeeId() { return employeeId; }
    public void setEmployeeId(Long employeeId) { this.employeeId = employeeId; }
    public Integer getRuleId() { return ruleId; }
    public void setRuleId(Integer ruleId) { this.ruleId = ruleId; }
    public Long getViolationEventId() { return violationEventId; }
    public void setViolationEventId(Long violationEventId) { this.violationEventId = violationEventId; }
    public Instant getEffectiveDate() { return effectiveDate; }
    public void setEffectiveDate(Instant effectiveDate) { this.effectiveDate = effectiveDate; }
    public String getDetails() { return details; }
    public void setDetails(String details) { this.details = details; }
    public BigDecimal getAmount() { return amount; }
    public void setAmount(BigDecimal amount) { this.amount = amount; }
    public String getDecisionStatus() { return decisionStatus; }
    public void setDecisionStatus(String decisionStatus) { this.decisionStatus = decisionStatus; }
    public Long getProposedBy() { return proposedBy; }
    public void setProposedBy(Long proposedBy) { this.proposedBy = proposedBy; }
    public Long getApprovedBy() { return approvedBy; }
    public void setApprovedBy(Long approvedBy) { this.approvedBy = approvedBy; }
    public Instant getApprovedAt() { return approvedAt; }
    public void setApprovedAt(Instant approvedAt) { this.approvedAt = approvedAt; }
    public String getReviewNote() { return reviewNote; }
    public void setReviewNote(String reviewNote) { this.reviewNote = reviewNote; }
}
