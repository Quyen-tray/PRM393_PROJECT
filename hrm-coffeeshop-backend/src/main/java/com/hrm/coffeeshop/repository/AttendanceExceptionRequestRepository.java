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

public interface AttendanceExceptionRequestRepository extends JpaRepository<AttendanceExceptionRequest, Long> {

    boolean existsByEmployeeIdAndShiftAssignmentIdAndRequestTypeAndRequestStatus(Long employeeId, Long shiftAssignmentId, String type, String status);
    Page<AttendanceExceptionRequest> findByRequestStatus(String status, Pageable p);
    List<AttendanceExceptionRequest> findByShiftAssignmentIdInAndRequestStatus(Collection<Long> scheduleIds, String status);
    List<AttendanceExceptionRequest> findByShiftAssignmentIdInAndRequestType(Collection<Long> scheduleIds, String type);
    long countByRequestStatus(String status);
    List<AttendanceExceptionRequest> findTop50ByEmployeeIdOrderBySubmittedAtDesc(Long employeeId);

    @Query("select e from AttendanceExceptionRequest e where e.retainUntil is not null and e.retainUntil < :today "
         + "and e.evidenceStorageKey is not null and e.evidenceStorageKey <> 'PURGED'")
    List<AttendanceExceptionRequest> findExpiredEvidence(@Param("today") LocalDate today);
}
