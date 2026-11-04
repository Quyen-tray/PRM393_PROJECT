package com.hrm.coffeeshop.domain;

import jakarta.persistence.*;
import java.io.Serializable;
import java.math.BigDecimal;
import java.time.*;
import java.util.Objects;

/** Sinh tự động từ DDL bởi tools/gen_entities.py - đừng sửa tay. */
@Entity
@Table(name = "ChecklistReview")
public class ChecklistReview {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "ChecklistReviewId")
    private Long checklistReviewId;
    @Column(name = "ChecklistTaskId")
    private Long checklistTaskId;
    @Column(name = "ReviewerId")
    private Long reviewerId;
    @Column(name = "Decision")
    private String decision;
    @Column(name = "Reason")
    private String reason;
    @Column(name = "ReviewedAt")
    private Instant reviewedAt = Instant.now();

    public ChecklistReview() {}

    public Long getChecklistReviewId() { return checklistReviewId; }
    public void setChecklistReviewId(Long checklistReviewId) { this.checklistReviewId = checklistReviewId; }
    public Long getChecklistTaskId() { return checklistTaskId; }
    public void setChecklistTaskId(Long checklistTaskId) { this.checklistTaskId = checklistTaskId; }
    public Long getReviewerId() { return reviewerId; }
    public void setReviewerId(Long reviewerId) { this.reviewerId = reviewerId; }
    public String getDecision() { return decision; }
    public void setDecision(String decision) { this.decision = decision; }
    public String getReason() { return reason; }
    public void setReason(String reason) { this.reason = reason; }
    public Instant getReviewedAt() { return reviewedAt; }
    public void setReviewedAt(Instant reviewedAt) { this.reviewedAt = reviewedAt; }
}
