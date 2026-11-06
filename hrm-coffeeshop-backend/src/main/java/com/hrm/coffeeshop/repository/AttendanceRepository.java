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

public interface AttendanceRepository extends JpaRepository<Attendance, Long> {

    Optional<Attendance> findByShiftAssignmentId(Long shiftAssignmentId);
    @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
    @Query("select a from Attendance a where a.attendanceId = :id")
    Optional<Attendance> findByIdForUpdate(@Param("id") Long id);
    List<Attendance> findByShiftAssignmentIdIn(Collection<Long> scheduleIds);

    /**
     * Ngày làm việc của bản ghi công, đọc MÀ KHÔNG nạp entity Attendance. Dùng để khóa kỳ công
     * trước khi nạp bản ghi (tránh ghi đè bằng trạng thái cũ đã đọc trước khi có khóa).
     * empId = 0L: không lọc theo nhân viên.
     */
    @Query("select s.workDate from ShiftAssignment s, Attendance a where a.shiftAssignmentId = s.shiftAssignmentId "
         + "and a.attendanceId = :id and (:empId = 0L or a.employeeId = :empId)")
    Optional<LocalDate> findWorkDateOfAttendance(@Param("id") Long id, @Param("empId") long empId);

    @Query("select count(a) from Attendance a where a.employeeId = :employeeId and a.graceApplied = true "
         + "and a.checkInAt >= :from and a.checkInAt < :to and a.attendanceId <> :excludeId")
    long countGraceUsed(@Param("employeeId") Long employeeId, @Param("from") Instant from,
                        @Param("to") Instant to, @Param("excludeId") Long excludeId);

    @Query("select a from Attendance a where (:employeeId = 0L or a.employeeId = :employeeId) "
         + "and (:status = '' or a.attendanceStatus = :status or (:status = 'CHECKED_IN' and a.checkInAt is not null and a.checkOutAt is null) or (:status = 'CHECKED_OUT' and a.checkOutAt is not null) or (:status = 'FINALIZED' and a.payrollStatus = 'LOCKED') or (:status = 'EARLY_LEAVE' and a.earlyLeaveMinutes > 0) or (:status = 'LATE' and a.lateMinutes > 0)) "
         + "and a.shiftAssignmentId in (select s.shiftAssignmentId from ShiftAssignment s where s.workDate between :from and :to)")
    Page<Attendance> searchByWorkDate(@Param("employeeId") Long employeeId, @Param("status") String status,
                                            @Param("from") LocalDate from, @Param("to") LocalDate to, Pageable p);
}
