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

public interface AuditLogRepository extends JpaRepository<AuditLog, Long> {

    @Query("select a from AuditLog a where (:entityType = '' or a.entityType = :entityType) "
         + "and (:actionCode = '' or a.actionCode = :actionCode) and a.createdAt >= :from and a.createdAt < :to")
    Page<AuditLog> search(@Param("entityType") String entityType, @Param("actionCode") String actionCode,
                          @Param("from") Instant from, @Param("to") Instant to, Pageable p);
}
