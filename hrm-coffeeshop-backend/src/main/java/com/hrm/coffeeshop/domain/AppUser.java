package com.hrm.coffeeshop.domain;

import jakarta.persistence.*;
import java.io.Serializable;
import java.math.BigDecimal;
import java.time.*;
import java.util.Objects;

/** Sinh tự động từ DDL bởi tools/gen_entities.py - đừng sửa tay. */
@Entity
@Table(name = "AppUser")
public class AppUser {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "UserId")
    private Long userId;
    @Column(name = "GoogleSubject")
    private String googleSubject;
    @Column(name = "Email")
    private String email;
    @Column(name = "DisplayName")
    private String displayName;
    @Column(name = "AvatarUrl")
    private String avatarUrl;
    @Column(name = "PhoneNumber")
    private String phoneNumber;
    @Column(name = "UserStatus")
    private String userStatus = "ACTIVE";
    @Column(name = "LastLoginAt")
    private Instant lastLoginAt;
    @Column(name = "CreatedAt")
    private Instant createdAt = Instant.now();
    @Column(name = "UpdatedAt")
    private Instant updatedAt = Instant.now();

    public AppUser() {}

    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }
    public String getGoogleSubject() { return googleSubject; }
    public void setGoogleSubject(String googleSubject) { this.googleSubject = googleSubject; }
    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
    public String getDisplayName() { return displayName; }
    public void setDisplayName(String displayName) { this.displayName = displayName; }
    public String getAvatarUrl() { return avatarUrl; }
    public void setAvatarUrl(String avatarUrl) { this.avatarUrl = avatarUrl; }
    public String getPhoneNumber() { return phoneNumber; }
    public void setPhoneNumber(String phoneNumber) { this.phoneNumber = phoneNumber; }
    public String getUserStatus() { return userStatus; }
    public void setUserStatus(String userStatus) { this.userStatus = userStatus; }
    public Instant getLastLoginAt() { return lastLoginAt; }
    public void setLastLoginAt(Instant lastLoginAt) { this.lastLoginAt = lastLoginAt; }
    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Instant updatedAt) { this.updatedAt = updatedAt; }

    @PreUpdate
    void touch() { this.updatedAt = Instant.now(); }
}
