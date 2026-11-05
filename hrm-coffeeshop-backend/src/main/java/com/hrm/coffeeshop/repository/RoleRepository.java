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

public interface RoleRepository extends JpaRepository<Role, Integer> {

    Optional<Role> findByRoleCode(String roleCode);

    @Query("select r.roleCode from Role r where r.isActive = true and r.roleId in "
         + "(select ur.roleId from UserRole ur where ur.userId = :userId)")
    List<String> findActiveCodesByUserId(@Param("userId") Long userId);
}
