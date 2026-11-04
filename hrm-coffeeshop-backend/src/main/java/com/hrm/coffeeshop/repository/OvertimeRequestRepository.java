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

public interface OvertimeRequestRepository extends JpaRepository<OvertimeRequest, Long> {

    List<OvertimeRequest> findByShiftAssignmentIdAndApprovalStatus(Long shiftAssignmentId, String status);
    List<OvertimeRequest> findByShiftAssignmentIdAndApprovalStatusIn(Long shiftAssignmentId, Collection<String> statuses);
    List<OvertimeRequest> findByShiftAssignmentIdInAndApprovalStatus(Collection<Long> scheduleIds, String status);
    Page<OvertimeRequest> findByApprovalStatus(String status, Pageable p);
    long countByApprovalStatus(String status);
    List<OvertimeRequest> findTop50ByEmployeeIdOrderByRequestedAtDesc(Long employeeId);
}
