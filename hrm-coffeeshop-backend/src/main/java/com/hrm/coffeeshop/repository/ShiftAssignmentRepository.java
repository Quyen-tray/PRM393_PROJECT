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

public interface ShiftAssignmentRepository extends JpaRepository<ShiftAssignment, Long> {

    List<ShiftAssignment> findByEmployeeIdAndWorkDateBetweenOrderByPlannedStartAtAsc(Long employeeId, LocalDate from, LocalDate to);

    @Query("select s from ShiftAssignment s where s.employeeId = :employeeId and s.scheduleStatus in ('DRAFT','PUBLISHED','COMPLETED') "
         + "and s.plannedStartAt < :end and s.plannedEndAt > :start and s.shiftAssignmentId <> :excludeId")
    List<ShiftAssignment> findOverlapping(@Param("employeeId") Long employeeId, @Param("start") Instant start,
                                           @Param("end") Instant end, @Param("excludeId") Long excludeId);

    @Query("select s from ShiftAssignment s where s.workDate between :from and :to "
         + "and (:employeeId = 0L or s.employeeId = :employeeId) order by s.plannedStartAt")
    Page<ShiftAssignment> search(@Param("from") LocalDate from, @Param("to") LocalDate to,
                                  @Param("employeeId") Long employeeId, Pageable p);

    @Query("select s from ShiftAssignment s where s.scheduleStatus in ('PUBLISHED','COMPLETED') "
         + "and s.workDate between :from and :to and (:shiftId = 0 or s.workShiftId = :shiftId) "
         + "and (:employeeId = 0L or s.employeeId = :employeeId)")
    List<ShiftAssignment> findForStats(@Param("from") LocalDate from, @Param("to") LocalDate to,
                                        @Param("shiftId") Integer shiftId, @Param("employeeId") Long employeeId);

    @Query("select s from ShiftAssignment s where s.scheduleStatus = 'PUBLISHED' "
         + "and s.plannedStartAt >= :from and s.plannedStartAt <= :to")
    List<ShiftAssignment> findStartingBetween(@Param("from") Instant from, @Param("to") Instant to);

    /** Khóa dòng phân ca (PESSIMISTIC_WRITE) để tuần tự hóa các thao tác tạo OT trên cùng một ca. */
    @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
    @Query("select s from ShiftAssignment s where s.shiftAssignmentId = :id")
    Optional<ShiftAssignment> findByIdForUpdate(@Param("id") Long id);
}
