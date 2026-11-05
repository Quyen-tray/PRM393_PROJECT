package com.hrm.coffeeshop.domain;

import jakarta.persistence.*;
import java.io.Serializable;
import java.math.BigDecimal;
import java.time.*;
import java.util.Objects;

/** Sinh tự động từ DDL bởi tools/gen_entities.py - đừng sửa tay. */
@Entity
@Table(name = "TrainingCourse")
public class TrainingCourse {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "CourseId")
    private Integer courseId;
    @Column(name = "CourseCode")
    private String courseCode;
    @Column(name = "CourseName")
    private String courseName;
    @Column(name = "Description")
    private String description;
    @Column(name = "PassingScore")
    private BigDecimal passingScore = new BigDecimal("80");
    @Column(name = "ValidityMonths")
    private Integer validityMonths;
    @Column(name = "IsMandatoryTest")
    private Boolean isMandatoryTest = Boolean.TRUE;
    @Column(name = "IsActive")
    private Boolean isActive = Boolean.TRUE;

    public TrainingCourse() {}

    public Integer getCourseId() { return courseId; }
    public void setCourseId(Integer courseId) { this.courseId = courseId; }
    public String getCourseCode() { return courseCode; }
    public void setCourseCode(String courseCode) { this.courseCode = courseCode; }
    public String getCourseName() { return courseName; }
    public void setCourseName(String courseName) { this.courseName = courseName; }
    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
    public BigDecimal getPassingScore() { return passingScore; }
    public void setPassingScore(BigDecimal passingScore) { this.passingScore = passingScore; }
    public Integer getValidityMonths() { return validityMonths; }
    public void setValidityMonths(Integer validityMonths) { this.validityMonths = validityMonths; }
    public Boolean getIsMandatoryTest() { return isMandatoryTest; }
    public void setIsMandatoryTest(Boolean isMandatoryTest) { this.isMandatoryTest = isMandatoryTest; }
    public Boolean getIsActive() { return isActive; }
    public void setIsActive(Boolean isActive) { this.isActive = isActive; }
}
