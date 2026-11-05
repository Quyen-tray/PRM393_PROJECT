package com.hrm.coffeeshop.domain;

import jakarta.persistence.*;
import java.io.Serializable;
import java.math.BigDecimal;
import java.time.*;
import java.util.Objects;

/** Sinh tự động từ DDL bởi tools/gen_entities.py - đừng sửa tay. */
@Entity
@Table(name = "AttendanceVerification")
public class AttendanceVerification {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "VerificationId")
    private Long verificationId;
    @Column(name = "AttendanceId")
    private Long attendanceId;
    @Column(name = "DeviceId")
    private Long deviceId;
    @Column(name = "VerificationType")
    private String verificationType;
    @Column(name = "EventType")
    private String eventType;
    @Column(name = "Latitude")
    private BigDecimal latitude;
    @Column(name = "Longitude")
    private BigDecimal longitude;
    @Column(name = "AccuracyMeters")
    private BigDecimal accuracyMeters;
    @Column(name = "DistanceMeters")
    private BigDecimal distanceMeters;
    @Column(name = "EvidenceStorageKey")
    private String evidenceStorageKey;
    @Column(name = "VerificationStatus")
    private String verificationStatus;
    @Column(name = "FailureReason")
    private String failureReason;
    @Column(name = "VerifiedAt")
    private Instant verifiedAt;
    @Column(name = "ContentHash")
    private String contentHash;
    @Column(name = "AiProvider")
    private String aiProvider;
    @Column(name = "AiResultJson")
    private String aiResultJson;
    @Column(name = "RetainUntil")
    private LocalDate retainUntil;
    @Column(name = "CreatedAt")
    private Instant createdAt = Instant.now();

    public AttendanceVerification() {}

    public Long getVerificationId() { return verificationId; }
    public void setVerificationId(Long verificationId) { this.verificationId = verificationId; }
    public Long getAttendanceId() { return attendanceId; }
    public void setAttendanceId(Long attendanceId) { this.attendanceId = attendanceId; }
    public Long getDeviceId() { return deviceId; }
    public void setDeviceId(Long deviceId) { this.deviceId = deviceId; }
    public String getVerificationType() { return verificationType; }
    public void setVerificationType(String verificationType) { this.verificationType = verificationType; }
    public String getEventType() { return eventType; }
    public void setEventType(String eventType) { this.eventType = eventType; }
    public BigDecimal getLatitude() { return latitude; }
    public void setLatitude(BigDecimal latitude) { this.latitude = latitude; }
    public BigDecimal getLongitude() { return longitude; }
    public void setLongitude(BigDecimal longitude) { this.longitude = longitude; }
    public BigDecimal getAccuracyMeters() { return accuracyMeters; }
    public void setAccuracyMeters(BigDecimal accuracyMeters) { this.accuracyMeters = accuracyMeters; }
    public BigDecimal getDistanceMeters() { return distanceMeters; }
    public void setDistanceMeters(BigDecimal distanceMeters) { this.distanceMeters = distanceMeters; }
    public String getEvidenceStorageKey() { return evidenceStorageKey; }
    public void setEvidenceStorageKey(String evidenceStorageKey) { this.evidenceStorageKey = evidenceStorageKey; }
    public String getVerificationStatus() { return verificationStatus; }
    public void setVerificationStatus(String verificationStatus) { this.verificationStatus = verificationStatus; }
    public String getFailureReason() { return failureReason; }
    public void setFailureReason(String failureReason) { this.failureReason = failureReason; }
    public Instant getVerifiedAt() { return verifiedAt; }
    public void setVerifiedAt(Instant verifiedAt) { this.verifiedAt = verifiedAt; }
    public String getContentHash() { return contentHash; }
    public void setContentHash(String contentHash) { this.contentHash = contentHash; }
    public String getAiProvider() { return aiProvider; }
    public void setAiProvider(String aiProvider) { this.aiProvider = aiProvider; }
    public String getAiResultJson() { return aiResultJson; }
    public void setAiResultJson(String aiResultJson) { this.aiResultJson = aiResultJson; }
    public LocalDate getRetainUntil() { return retainUntil; }
    public void setRetainUntil(LocalDate retainUntil) { this.retainUntil = retainUntil; }
    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
}
