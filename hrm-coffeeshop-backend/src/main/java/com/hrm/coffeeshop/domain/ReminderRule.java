package com.hrm.coffeeshop.domain;

import jakarta.persistence.*;
import java.io.Serializable;
import java.math.BigDecimal;
import java.time.*;
import java.util.Objects;

/** Sinh tự động từ DDL bởi tools/gen_entities.py - đừng sửa tay. */
@Entity
@Table(name = "ReminderRule")
public class ReminderRule {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "ReminderRuleId")
    private Integer reminderRuleId;
    @Column(name = "RuleCode")
    private String ruleCode;
    @Column(name = "RuleName")
    private String ruleName;
    @Column(name = "LeadMinutes")
    private Integer leadMinutes;
    @Column(name = "IntervalMinutes")
    private Integer intervalMinutes;
    @Column(name = "MaxAttempts")
    private Integer maxAttempts;
    @Column(name = "IsActive")
    private Boolean isActive = Boolean.TRUE;

    public ReminderRule() {}

    public Integer getReminderRuleId() { return reminderRuleId; }
    public void setReminderRuleId(Integer reminderRuleId) { this.reminderRuleId = reminderRuleId; }
    public String getRuleCode() { return ruleCode; }
    public void setRuleCode(String ruleCode) { this.ruleCode = ruleCode; }
    public String getRuleName() { return ruleName; }
    public void setRuleName(String ruleName) { this.ruleName = ruleName; }
    public Integer getLeadMinutes() { return leadMinutes; }
    public void setLeadMinutes(Integer leadMinutes) { this.leadMinutes = leadMinutes; }
    public Integer getIntervalMinutes() { return intervalMinutes; }
    public void setIntervalMinutes(Integer intervalMinutes) { this.intervalMinutes = intervalMinutes; }
    public Integer getMaxAttempts() { return maxAttempts; }
    public void setMaxAttempts(Integer maxAttempts) { this.maxAttempts = maxAttempts; }
    public Boolean getIsActive() { return isActive; }
    public void setIsActive(Boolean isActive) { this.isActive = isActive; }
}
