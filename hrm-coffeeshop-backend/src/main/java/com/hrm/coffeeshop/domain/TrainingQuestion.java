package com.hrm.coffeeshop.domain;
import jakarta.persistence.*;
@Entity
@Table(name="TrainingQuestion")
public class TrainingQuestion {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) @Column(name="QuestionId") private Long questionId;
    @Column(name="CourseId",nullable=false) private Integer courseId;
    @Column(name="QuestionText",nullable=false) private String questionText;
    @Column(name="OptionA",nullable=false) private String optionA;
    @Column(name="OptionB",nullable=false) private String optionB;
    @Column(name="OptionC",nullable=false) private String optionC;
    @Column(name="OptionD",nullable=false) private String optionD;
    @Column(name="CorrectOption",nullable=false) private String correctOption;
    @Column(name="SortOrder",nullable=false) private Integer sortOrder;
    @Column(name="IsActive",nullable=false) private Boolean isActive=true;
    public Long getQuestionId(){return questionId;} public void setQuestionId(Long v){questionId=v;}
    public Integer getCourseId(){return courseId;} public void setCourseId(Integer v){courseId=v;}
    public String getQuestionText(){return questionText;} public void setQuestionText(String v){questionText=v;}
    public String getOptionA(){return optionA;} public void setOptionA(String v){optionA=v;}
    public String getOptionB(){return optionB;} public void setOptionB(String v){optionB=v;}
    public String getOptionC(){return optionC;} public void setOptionC(String v){optionC=v;}
    public String getOptionD(){return optionD;} public void setOptionD(String v){optionD=v;}
    public String getCorrectOption(){return correctOption;} public void setCorrectOption(String v){correctOption=v;}
    public Integer getSortOrder(){return sortOrder;} public void setSortOrder(Integer v){sortOrder=v;}
    public Boolean getIsActive(){return isActive;} public void setIsActive(Boolean v){isActive=v;}
}
