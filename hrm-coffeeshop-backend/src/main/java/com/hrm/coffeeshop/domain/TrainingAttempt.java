package com.hrm.coffeeshop.domain;

import jakarta.persistence.*;
import java.io.Serializable;
import java.math.BigDecimal;
import java.time.*;
import java.util.Objects;

/** Sinh tự động từ DDL bởi tools/gen_entities.py - đừng sửa tay. */
@Entity
@Table(name = "TrainingAttempt")
public class TrainingAttempt {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "AttemptId")
    private Long attemptId;
    @Column(name = "EmployeeId")
    private Long employeeId;
    @Column(name = "CourseId")
    private Integer courseId;
    @Column(name = "AttemptNo")
    private Integer attemptNo;
    @Column(name = "Score")
    private BigDecimal score;
    @Column(name = "IsPassed")
    private Boolean isPassed;
    @Column(name = "Source")
    private String source = "MANUAL";
    @Column(name = "RecordedBy")
    private Long recordedBy;
    @Column(name = "RecordedAt")
    private Instant recordedAt = Instant.now();
    @Column(name = "AnswersJson", columnDefinition = "nvarchar(max)")
    private String answersJson;

    public TrainingAttempt() {}
    public String getAnswersJson() { return answersJson; }
    public void setAnswersJson(String v) { answersJson = v; }

    public Long getAttemptId() { return attemptId; }
    public void setAttemptId(Long attemptId) { this.attemptId = attemptId; }
    public Long getEmployeeId() { return employeeId; }
    public void setEmployeeId(Long employeeId) { this.employeeId = employeeId; }
    public Integer getCourseId() { return courseId; }
    public void setCourseId(Integer courseId) { this.courseId = courseId; }
    public Integer getAttemptNo() { return attemptNo; }
    public void setAttemptNo(Integer attemptNo) { this.attemptNo = attemptNo; }
    public BigDecimal getScore() { return score; }
    public void setScore(BigDecimal score) { this.score = score; }
    public Boolean getIsPassed() { return isPassed; }
    public void setIsPassed(Boolean isPassed) { this.isPassed = isPassed; }
    public String getSource() { return source; }
    public void setSource(String source) { this.source = source; }
    public Long getRecordedBy() { return recordedBy; }
    public void setRecordedBy(Long recordedBy) { this.recordedBy = recordedBy; }
    public Instant getRecordedAt() { return recordedAt; }
    public void setRecordedAt(Instant recordedAt) { this.recordedAt = recordedAt; }
}
