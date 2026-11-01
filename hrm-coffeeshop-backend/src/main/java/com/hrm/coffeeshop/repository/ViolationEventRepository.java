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

public interface ViolationEventRepository extends JpaRepository<ViolationEvent, Long> {

    boolean existsByEmployeeIdAndRuleIdAndAttendanceId(Long employeeId, Integer ruleId, Long attendanceId);
    boolean existsByEmployeeIdAndRuleIdAndChecklistTaskId(Long employeeId, Integer ruleId, Long checklistTaskId);
    long countByRecordStatus(String status);

    @Query("select d from ViolationEvent d where (:status = '' or d.recordStatus = :status) "
         + "and (:employeeId = 0L or d.employeeId = :employeeId)")
    Page<ViolationEvent> search(@Param("status") String status, @Param("employeeId") Long employeeId, Pageable p);
}
