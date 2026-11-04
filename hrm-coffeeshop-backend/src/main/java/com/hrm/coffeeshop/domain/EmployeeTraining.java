package com.hrm.coffeeshop.domain;

import jakarta.persistence.*;
import java.io.Serializable;
import java.math.BigDecimal;
import java.time.*;
import java.util.Objects;

/** Sinh tự động từ DDL bởi tools/gen_entities.py - đừng sửa tay. */
@Entity
@Table(name = "EmployeeTraining")
public class EmployeeTraining {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "EmployeeTrainingId")
    private Long employeeTrainingId;
    @Column(name = "EmployeeId")
    private Long employeeId;
    @Column(name = "CourseId")
    private Integer courseId;
    @Column(name = "AssignedAt")
    private Instant assignedAt = Instant.now();
    @Column(name = "DueAt")
    private Instant dueAt;
    @Column(name = "CompletedAt")
    private Instant completedAt;
    @Column(name = "ExpiresAt")
    private Instant expiresAt;
    @Column(name = "TestScore")
    private BigDecimal testScore;
    @Column(name = "TrainingStatus")
    private String trainingStatus = "NOT_STARTED";
    @Column(name = "CompletionSubmittedAt")
    private Instant completionSubmittedAt;
    @Column(name = "CompletionRequestNote")
    private String completionRequestNote;
    @Column(name = "CompletionReviewedAt")
    private Instant completionReviewedAt;
    @Column(name = "CompletionReviewedBy")
    private Long completionReviewedBy;
    @Column(name = "CompletionReviewNote")
    private String completionReviewNote;

    public EmployeeTraining() {}

    public Long getEmployeeTrainingId() { return employeeTrainingId; }
    public void setEmployeeTrainingId(Long employeeTrainingId) { this.employeeTrainingId = employeeTrainingId; }
    public Long getEmployeeId() { return employeeId; }
    public void setEmployeeId(Long employeeId) { this.employeeId = employeeId; }
    public Integer getCourseId() { return courseId; }
    public void setCourseId(Integer courseId) { this.courseId = courseId; }
    public Instant getAssignedAt() { return assignedAt; }
    public void setAssignedAt(Instant assignedAt) { this.assignedAt = assignedAt; }
    public Instant getDueAt() { return dueAt; }
    public void setDueAt(Instant dueAt) { this.dueAt = dueAt; }
    public Instant getCompletedAt() { return completedAt; }
    public void setCompletedAt(Instant completedAt) { this.completedAt = completedAt; }
    public Instant getExpiresAt() { return expiresAt; }
    public void setExpiresAt(Instant expiresAt) { this.expiresAt = expiresAt; }
    public BigDecimal getTestScore() { return testScore; }
    public void setTestScore(BigDecimal testScore) { this.testScore = testScore; }
    public String getTrainingStatus() { return trainingStatus; }
    public void setTrainingStatus(String trainingStatus) { this.trainingStatus = trainingStatus; }
    public Instant getCompletionSubmittedAt() { return completionSubmittedAt; }
    public void setCompletionSubmittedAt(Instant completionSubmittedAt) { this.completionSubmittedAt = completionSubmittedAt; }
    public String getCompletionRequestNote() { return completionRequestNote; }
    public void setCompletionRequestNote(String completionRequestNote) { this.completionRequestNote = completionRequestNote; }
    public Instant getCompletionReviewedAt() { return completionReviewedAt; }
    public void setCompletionReviewedAt(Instant completionReviewedAt) { this.completionReviewedAt = completionReviewedAt; }
    public Long getCompletionReviewedBy() { return completionReviewedBy; }
    public void setCompletionReviewedBy(Long completionReviewedBy) { this.completionReviewedBy = completionReviewedBy; }
    public String getCompletionReviewNote() { return completionReviewNote; }
    public void setCompletionReviewNote(String completionReviewNote) { this.completionReviewNote = completionReviewNote; }
}
