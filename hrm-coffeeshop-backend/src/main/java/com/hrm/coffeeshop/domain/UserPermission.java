package com.hrm.coffeeshop.domain;

import jakarta.persistence.*;
import java.io.Serializable;
import java.math.BigDecimal;
import java.time.*;
import java.util.Objects;

/** Sinh tự động từ DDL bởi tools/gen_entities.py - đừng sửa tay. */
@Entity
@Table(name = "UserPermission")
@IdClass(UserPermission.Pk.class)
public class UserPermission {
    public static class Pk implements Serializable {
        private Long userId;
        private Integer permissionId;
        public Pk() {}
        public Pk(Long userId, Integer permissionId) {
            this.userId = userId;
            this.permissionId = permissionId;
        }
        public Long getUserId() { return userId; }
        public void setUserId(Long v) { this.userId = v; }
        public Integer getPermissionId() { return permissionId; }
        public void setPermissionId(Integer v) { this.permissionId = v; }
        @Override public boolean equals(Object o) {
            if (this == o) return true;
            if (!(o instanceof Pk other)) return false;
            return Objects.equals(userId, other.userId) && Objects.equals(permissionId, other.permissionId);
        }
        @Override public int hashCode() { return Objects.hash(userId, permissionId); }
    }

    @Id
    @Column(name = "UserId")
    private Long userId;
    @Id
    @Column(name = "PermissionId")
    private Integer permissionId;
    @Column(name = "GrantedBy")
    private Long grantedBy;
    @Column(name = "GrantedAt")
    private Instant grantedAt = Instant.now();

    public UserPermission() {}

    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }
    public Integer getPermissionId() { return permissionId; }
    public void setPermissionId(Integer permissionId) { this.permissionId = permissionId; }
    public Long getGrantedBy() { return grantedBy; }
    public void setGrantedBy(Long grantedBy) { this.grantedBy = grantedBy; }
    public Instant getGrantedAt() { return grantedAt; }
    public void setGrantedAt(Instant grantedAt) { this.grantedAt = grantedAt; }
}
