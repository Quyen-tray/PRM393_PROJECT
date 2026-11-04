package com.hrm.coffeeshop.domain;

import jakarta.persistence.*;

@Entity
@Table(name = "TrainingQuestion")
public class TrainingQuestion {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "QuestionId")
    private Long questionId;

    @Column(name = "CourseId", nullable = false)
    private Integer courseId;

    @Column(name = "QuestionText", nullable = false, length = 1000)
    private String questionText;

    @Column(name = "OptionA", nullable = false, length = 300)
    private String optionA;

    @Column(name = "OptionB", nullable = false, length = 300)
    private String optionB;

    @Column(name = "OptionC", nullable = false, length = 300)
    private String optionC;

    @Column(name = "OptionD", nullable = false, length = 300)
    private String optionD;

    @Column(name = "CorrectOption", nullable = false, length = 1)
    private String correctOption;

    @Column(name = "SortOrder", nullable = false)
    private Integer sortOrder = 1;

    @Column(name = "IsActive", nullable = false)
    private Boolean isActive = Boolean.TRUE;

    public Long getQuestionId() { return questionId; }
    public void setQuestionId(Long questionId) { this.questionId = questionId; }
    public Integer getCourseId() { return courseId; }
    public void setCourseId(Integer courseId) { this.courseId = courseId; }
    public String getQuestionText() { return questionText; }
    public void setQuestionText(String questionText) { this.questionText = questionText; }
    public String getOptionA() { return optionA; }
    public void setOptionA(String optionA) { this.optionA = optionA; }
    public String getOptionB() { return optionB; }
    public void setOptionB(String optionB) { this.optionB = optionB; }
    public String getOptionC() { return optionC; }
    public void setOptionC(String optionC) { this.optionC = optionC; }
    public String getOptionD() { return optionD; }
    public void setOptionD(String optionD) { this.optionD = optionD; }
    public String getCorrectOption() { return correctOption; }
    public void setCorrectOption(String correctOption) { this.correctOption = correctOption; }
    public Integer getSortOrder() { return sortOrder; }
    public void setSortOrder(Integer sortOrder) { this.sortOrder = sortOrder; }
    public Boolean getIsActive() { return isActive; }
    public void setIsActive(Boolean isActive) { this.isActive = isActive; }
}
