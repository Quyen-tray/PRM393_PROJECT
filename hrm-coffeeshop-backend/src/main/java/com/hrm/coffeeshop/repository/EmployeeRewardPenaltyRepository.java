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

public interface EmployeeRewardPenaltyRepository extends JpaRepository<EmployeeRewardPenalty, Long> {

    long countByDecisionStatus(String status);

    @Query("select r from EmployeeRewardPenalty r where r.decisionStatus in ('APPROVED','APPLIED') "
         + "and r.effectiveDate >= :from and r.effectiveDate < :to")
    List<EmployeeRewardPenalty> findApprovedBetween(@Param("from") Instant from, @Param("to") Instant to);

    /** Lọc, sắp xếp và phân trang ngay trong SQL. Chuỗi rỗng hoặc 0 nghĩa là không lọc. */
    @Query(value = "select r from EmployeeRewardPenalty r where (:type = '' or r.decisionType = :type) "
                 + "and (:employeeId = 0L or r.employeeId = :employeeId) and (:status = '' or r.decisionStatus = :status)",
           countQuery = "select count(r) from EmployeeRewardPenalty r where (:type = '' or r.decisionType = :type) "
                 + "and (:employeeId = 0L or r.employeeId = :employeeId) and (:status = '' or r.decisionStatus = :status)")
    Page<EmployeeRewardPenalty> search(@Param("type") String type, @Param("employeeId") long employeeId,
                                       @Param("status") String status, Pageable p);
}
