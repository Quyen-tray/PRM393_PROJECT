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

public interface AttendanceVerificationRepository extends JpaRepository<AttendanceVerification, Long> {

    List<AttendanceVerification> findByAttendanceIdOrderByVerifiedAtAsc(Long attendanceId);
    boolean existsByEvidenceStorageKey(String evidenceStorageKey);

    @Query("select e from AttendanceVerification e where e.retainUntil is not null and e.retainUntil < :today "
         + "and e.evidenceStorageKey is not null and e.evidenceStorageKey <> 'PURGED'")
    List<AttendanceVerification> findExpired(@Param("today") LocalDate today);
}
