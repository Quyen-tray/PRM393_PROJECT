package com.hrm.coffeeshop.repository;

import com.hrm.coffeeshop.domain.*;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.time.*;
import java.util.*;

public interface PermissionRepository extends JpaRepository<Permission, Integer> {

    Optional<Permission> findByPermissionCode(String permissionCode);
    List<Permission> findByPermissionCodeIn(Collection<String> codes);

    /** Quyền hiệu lực = quyền gán trực tiếp ∪ quyền của các role đang hoạt động. */
    @Query("select distinct p.permissionCode from Permission p where p.permissionId in "
         + "(select up.permissionId from UserPermission up where up.userId = :userId) "
         + "or p.permissionId in (select rp.permissionId from RolePermission rp where rp.roleId in "
         + "(select ur.roleId from UserRole ur where ur.userId = :userId) "
         + "and rp.roleId in (select r.roleId from Role r where r.isActive = true))")
    List<String> findEffectiveCodesByUserId(@Param("userId") Long userId);

    /** Chỉ các quyền gán trực tiếp (không tính quyền từ role). */
    @Query("select p.permissionCode from Permission p where p.permissionId in "
         + "(select up.permissionId from UserPermission up where up.userId = :userId)")
    List<String> findDirectCodesByUserId(@Param("userId") Long userId);
}
