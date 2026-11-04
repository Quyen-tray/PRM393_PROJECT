package com.hrm.coffeeshop.domain;

import jakarta.persistence.*;
import java.io.Serializable;
import java.math.BigDecimal;
import java.time.*;
import java.util.Objects;

/** Sinh tự động từ DDL bởi tools/gen_entities.py - đừng sửa tay. */
@Entity
@Table(name = "UserRole")
@IdClass(UserRole.Pk.class)
public class UserRole {
    public static class Pk implements Serializable {
        private Long userId;
        private Integer roleId;
        public Pk() {}
        public Pk(Long userId, Integer roleId) {
            this.userId = userId;
            this.roleId = roleId;
        }
        public Long getUserId() { return userId; }
        public void setUserId(Long v) { this.userId = v; }
        public Integer getRoleId() { return roleId; }
        public void setRoleId(Integer v) { this.roleId = v; }
        @Override public boolean equals(Object o) {
            if (this == o) return true;
            if (!(o instanceof Pk other)) return false;
            return Objects.equals(userId, other.userId) && Objects.equals(roleId, other.roleId);
        }
        @Override public int hashCode() { return Objects.hash(userId, roleId); }
    }

    @Id
    @Column(name = "UserId")
    private Long userId;
    @Id
    @Column(name = "RoleId")
    private Integer roleId;
    @Column(name = "AssignedAt")
    private Instant assignedAt = Instant.now();

    public UserRole() {}

    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }
    public Integer getRoleId() { return roleId; }
    public void setRoleId(Integer roleId) { this.roleId = roleId; }
    public Instant getAssignedAt() { return assignedAt; }
    public void setAssignedAt(Instant assignedAt) { this.assignedAt = assignedAt; }
}
