package com.hrm.coffeeshop.repository;

import com.hrm.coffeeshop.domain.AttendanceSpotCheck;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface AttendanceSpotCheckRepository extends JpaRepository<AttendanceSpotCheck, Long> {
    Optional<AttendanceSpotCheck> findByAttendanceId(Long attendanceId);
    Optional<AttendanceSpotCheck> findByAttendanceIdAndStatus(Long attendanceId, String status);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select s from AttendanceSpotCheck s where s.attendanceId = :attendanceId")
    Optional<AttendanceSpotCheck> findByAttendanceIdForUpdate(@Param("attendanceId") Long attendanceId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select s from AttendanceSpotCheck s where s.spotCheckId = :id")
    Optional<AttendanceSpotCheck> findByIdForUpdate(@Param("id") Long id);

    @Query("select s from AttendanceSpotCheck s where s.status = 'SCHEDULED' and s.scheduledAt <= :now order by s.scheduledAt")
    List<AttendanceSpotCheck> findDueScheduled(@Param("now") Instant now);

    @Query("select s from AttendanceSpotCheck s where s.status = 'REQUESTED' and s.responseDeadlineAt <= :now order by s.responseDeadlineAt")
    List<AttendanceSpotCheck> findExpiredRequests(@Param("now") Instant now);
}
