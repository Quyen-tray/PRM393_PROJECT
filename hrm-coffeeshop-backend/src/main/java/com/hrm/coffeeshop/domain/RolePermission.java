package com.hrm.coffeeshop.domain;

import jakarta.persistence.*;
import java.io.Serializable;
import java.math.BigDecimal;
import java.time.*;
import java.util.Objects;

/** Sinh tự động từ DDL bởi tools/gen_entities.py - đừng sửa tay. */
@Entity
@Table(name = "RolePermission")
@IdClass(RolePermission.Pk.class)
public class RolePermission {
    public static class Pk implements Serializable {
        private Integer roleId;
        private Integer permissionId;
        public Pk() {}
        public Pk(Integer roleId, Integer permissionId) {
            this.roleId = roleId;
            this.permissionId = permissionId;
        }
        public Integer getRoleId() { return roleId; }
        public void setRoleId(Integer v) { this.roleId = v; }
        public Integer getPermissionId() { return permissionId; }
        public void setPermissionId(Integer v) { this.permissionId = v; }
        @Override public boolean equals(Object o) {
            if (this == o) return true;
            if (!(o instanceof Pk other)) return false;
            return Objects.equals(roleId, other.roleId) && Objects.equals(permissionId, other.permissionId);
        }
        @Override public int hashCode() { return Objects.hash(roleId, permissionId); }
    }

    @Id
    @Column(name = "RoleId")
    private Integer roleId;
    @Id
    @Column(name = "PermissionId")
    private Integer permissionId;

    public RolePermission() {}

    public Integer getRoleId() { return roleId; }
    public void setRoleId(Integer roleId) { this.roleId = roleId; }
    public Integer getPermissionId() { return permissionId; }
    public void setPermissionId(Integer permissionId) { this.permissionId = permissionId; }
}
