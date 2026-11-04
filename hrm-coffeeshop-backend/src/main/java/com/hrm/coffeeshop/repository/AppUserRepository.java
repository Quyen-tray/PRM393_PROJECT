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

public interface AppUserRepository extends JpaRepository<AppUser, Long> {

    Optional<AppUser> findByGoogleSubject(String googleSubject);
    Optional<AppUser> findByEmail(String email);

    @Query("select u from AppUser u where u.userStatus = 'ACTIVE' "
            + "and not exists (select e.employeeId from Employee e where e.userId = u.userId) "
            + "and (:q = '' or lower(u.email) like lower(concat('%', :q, '%')) or lower(u.displayName) like lower(concat('%', :q, '%')))")
    Page<AppUser> findLinkable(@Param("q") String query, Pageable pageable);

    @Query("select u.userId from AppUser u where u.userStatus = 'ACTIVE' and u.userId in "
         + "(select ur.userId from UserRole ur where ur.roleId in (select r.roleId from Role r where r.roleCode = :code))")
    List<Long> findActiveUserIdsByRoleCode(@Param("code") String code);

    /** Người dùng ACTIVE có quyền permCode (gán trực tiếp hoặc qua role đang hoạt động). */
    @Query("select u.userId from AppUser u where u.userStatus = 'ACTIVE' and ("
         + "u.userId in (select up.userId from UserPermission up where up.permissionId in "
         + "(select p.permissionId from Permission p where p.permissionCode = :code)) "
         + "or u.userId in (select ur.userId from UserRole ur where ur.roleId in "
         + "(select rp.roleId from RolePermission rp where rp.permissionId in "
         + "(select p2.permissionId from Permission p2 where p2.permissionCode = :code)) "
         + "and ur.roleId in (select r.roleId from Role r where r.isActive = true)))")
    List<Long> findActiveUserIdsByPermissionCode(@Param("code") String code);
}
