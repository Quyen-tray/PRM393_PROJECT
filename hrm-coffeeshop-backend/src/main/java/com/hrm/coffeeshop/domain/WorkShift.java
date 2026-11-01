package com.hrm.coffeeshop.domain;

import jakarta.persistence.*;
import java.io.Serializable;
import java.math.BigDecimal;
import java.time.*;
import java.util.Objects;

/** Sinh tự động từ DDL bởi tools/gen_entities.py - đừng sửa tay. */
@Entity
@Table(name = "WorkShift")
public class WorkShift {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "WorkShiftId")
    private Integer workShiftId;
    @Column(name = "StoreId")
    private Integer storeId;
    @Column(name = "ShiftCode")
    private String shiftCode;
    @Column(name = "ShiftName")
    private String shiftName;
    @Column(name = "StartTime")
    private LocalTime startTime;
    @Column(name = "EndTime")
    private LocalTime endTime;
    @Column(name = "BreakMinutes")
    private Short breakMinutes = (short) 0;
    @Column(name = "EarlyCheckInMinutes")
    private Short earlyCheckInMinutes = (short) 30;
    @Column(name = "GraceMinutes")
    private Short graceMinutes = (short) 5;
    @Column(name = "IsActive")
    private Boolean isActive = Boolean.TRUE;

    public WorkShift() {}

    public Integer getWorkShiftId() { return workShiftId; }
    public void setWorkShiftId(Integer workShiftId) { this.workShiftId = workShiftId; }
    public Integer getStoreId() { return storeId; }
    public void setStoreId(Integer storeId) { this.storeId = storeId; }
    public String getShiftCode() { return shiftCode; }
    public void setShiftCode(String shiftCode) { this.shiftCode = shiftCode; }
    public String getShiftName() { return shiftName; }
    public void setShiftName(String shiftName) { this.shiftName = shiftName; }
    public LocalTime getStartTime() { return startTime; }
    public void setStartTime(LocalTime startTime) { this.startTime = startTime; }
    public LocalTime getEndTime() { return endTime; }
    public void setEndTime(LocalTime endTime) { this.endTime = endTime; }
    public Short getBreakMinutes() { return breakMinutes; }
    public void setBreakMinutes(Short breakMinutes) { this.breakMinutes = breakMinutes; }
    public Short getEarlyCheckInMinutes() { return earlyCheckInMinutes; }
    public void setEarlyCheckInMinutes(Short earlyCheckInMinutes) { this.earlyCheckInMinutes = earlyCheckInMinutes; }
    public Short getGraceMinutes() { return graceMinutes; }
    public void setGraceMinutes(Short graceMinutes) { this.graceMinutes = graceMinutes; }
    public Boolean getIsActive() { return isActive; }
    public void setIsActive(Boolean isActive) { this.isActive = isActive; }
}
