package com.hrm.coffeeshop.domain;

import jakarta.persistence.*;
import java.io.Serializable;
import java.math.BigDecimal;
import java.time.*;
import java.util.Objects;

/** Sinh tự động từ DDL bởi tools/gen_entities.py - đừng sửa tay. */
@Entity
@Table(name = "Store")
public class Store {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "StoreId")
    private Integer storeId;
    @Column(name = "StoreCode")
    private String storeCode;
    @Column(name = "Name")
    private String name;
    @Column(name = "AddressLine")
    private String addressLine;
    @Column(name = "Latitude")
    private BigDecimal latitude;
    @Column(name = "Longitude")
    private BigDecimal longitude;
    @Column(name = "AttendanceRadiusMeters")
    private Integer attendanceRadiusMeters = 30;
    @Column(name = "CheckInEarlyMinutes")
    private Integer checkInEarlyMinutes = 15;
    @Column(name = "GraceMinutes")
    private Integer graceMinutes = 5;
    @Column(name = "MonthlyGraceLimit")
    private Integer monthlyGraceLimit = 3;
    @Column(name = "PhotoRetentionMonths")
    private Integer photoRetentionMonths = 12;
    @Column(name = "GpsMaxAccuracyMeters")
    private Integer gpsMaxAccuracyMeters = 50;
    @Column(name = "DirectorApprovalThreshold")
    private Integer directorApprovalThreshold = 0;
    @Column(name = "IsActive")
    private Boolean isActive = Boolean.TRUE;
    @Column(name = "CreatedAt")
    private Instant createdAt = Instant.now();

    public Store() {}

    public Integer getStoreId() { return storeId; }
    public void setStoreId(Integer storeId) { this.storeId = storeId; }
    public String getStoreCode() { return storeCode; }
    public void setStoreCode(String storeCode) { this.storeCode = storeCode; }
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    public String getAddressLine() { return addressLine; }
    public void setAddressLine(String addressLine) { this.addressLine = addressLine; }
    public BigDecimal getLatitude() { return latitude; }
    public void setLatitude(BigDecimal latitude) { this.latitude = latitude; }
    public BigDecimal getLongitude() { return longitude; }
    public void setLongitude(BigDecimal longitude) { this.longitude = longitude; }
    public Integer getAttendanceRadiusMeters() { return attendanceRadiusMeters; }
    public void setAttendanceRadiusMeters(Integer attendanceRadiusMeters) { this.attendanceRadiusMeters = attendanceRadiusMeters; }
    public Integer getCheckInEarlyMinutes() { return checkInEarlyMinutes; }
    public void setCheckInEarlyMinutes(Integer checkInEarlyMinutes) { this.checkInEarlyMinutes = checkInEarlyMinutes; }
    public Integer getGraceMinutes() { return graceMinutes; }
    public void setGraceMinutes(Integer graceMinutes) { this.graceMinutes = graceMinutes; }
    public Integer getMonthlyGraceLimit() { return monthlyGraceLimit; }
    public void setMonthlyGraceLimit(Integer monthlyGraceLimit) { this.monthlyGraceLimit = monthlyGraceLimit; }
    public Integer getPhotoRetentionMonths() { return photoRetentionMonths; }
    public void setPhotoRetentionMonths(Integer photoRetentionMonths) { this.photoRetentionMonths = photoRetentionMonths; }
    public Integer getGpsMaxAccuracyMeters() { return gpsMaxAccuracyMeters; }
    public void setGpsMaxAccuracyMeters(Integer gpsMaxAccuracyMeters) { this.gpsMaxAccuracyMeters = gpsMaxAccuracyMeters; }
    public Integer getDirectorApprovalThreshold() { return directorApprovalThreshold; }
    public void setDirectorApprovalThreshold(Integer directorApprovalThreshold) { this.directorApprovalThreshold = directorApprovalThreshold; }
    public Boolean getIsActive() { return isActive; }
    public void setIsActive(Boolean isActive) { this.isActive = isActive; }
    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
}
