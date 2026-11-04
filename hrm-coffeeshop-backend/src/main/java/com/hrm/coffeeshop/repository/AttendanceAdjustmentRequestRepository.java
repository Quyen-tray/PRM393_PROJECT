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

public interface AttendanceAdjustmentRequestRepository extends JpaRepository<AttendanceAdjustmentRequest, Long> {

    @Query("select case when count(a) > 0 then true else false end from AttendanceAdjustmentRequest a "
         + "where a.attendanceId = :attendanceId and (a.managerStatus = 'PENDING' or (a.managerStatus = 'APPROVED' and a.hrStatus = 'PENDING'))")
    boolean existsPending(@Param("attendanceId") Long attendanceId);

    @Query("select case when count(a) > 0 then true else false end from AttendanceAdjustmentRequest a "
         + "where a.attendanceId = :attendanceId and a.fieldName = :field "
         + "and (a.managerStatus = 'PENDING' or (a.managerStatus = 'APPROVED' and a.hrStatus = 'PENDING'))")
    boolean existsPendingField(@Param("attendanceId") Long attendanceId, @Param("field") String field);

    Page<AttendanceAdjustmentRequest> findByManagerStatus(String managerStatus, Pageable p);
    Page<AttendanceAdjustmentRequest> findByManagerStatusAndHrStatus(String managerStatus, String hrStatus, Pageable p);
    Page<AttendanceAdjustmentRequest> findByRequestedBy(Long userId, Pageable p);
    List<AttendanceAdjustmentRequest> findByAttendanceIdIn(Collection<Long> attendanceIds);
    long countByManagerStatus(String managerStatus);
    long countByManagerStatusAndHrStatus(String managerStatus, String hrStatus);

    @Query("select a from AttendanceAdjustmentRequest a where a.managerStatus = 'REJECTED' or a.hrStatus = 'REJECTED'")
    Page<AttendanceAdjustmentRequest> findRejected(Pageable p);
}
