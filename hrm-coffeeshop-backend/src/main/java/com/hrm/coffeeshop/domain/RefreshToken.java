package com.hrm.coffeeshop.domain;

import jakarta.persistence.*;
import java.io.Serializable;
import java.math.BigDecimal;
import java.time.*;
import java.util.Objects;

/** Sinh tự động từ DDL bởi tools/gen_entities.py - đừng sửa tay. */
@Entity
@Table(name = "RefreshToken")
public class RefreshToken {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "RefreshTokenId")
    private Long refreshTokenId;
    @Column(name = "UserId")
    private Long userId;
    @Column(name = "TokenHash")
    private String tokenHash;
    @Column(name = "ExpiresAt")
    private Instant expiresAt;
    @Column(name = "RevokedAt")
    private Instant revokedAt;
    @Column(name = "CreatedAt")
    private Instant createdAt = Instant.now();

    public RefreshToken() {}

    public Long getRefreshTokenId() { return refreshTokenId; }
    public void setRefreshTokenId(Long refreshTokenId) { this.refreshTokenId = refreshTokenId; }
    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }
    public String getTokenHash() { return tokenHash; }
    public void setTokenHash(String tokenHash) { this.tokenHash = tokenHash; }
    public Instant getExpiresAt() { return expiresAt; }
    public void setExpiresAt(Instant expiresAt) { this.expiresAt = expiresAt; }
    public Instant getRevokedAt() { return revokedAt; }
    public void setRevokedAt(Instant revokedAt) { this.revokedAt = revokedAt; }
    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
}
