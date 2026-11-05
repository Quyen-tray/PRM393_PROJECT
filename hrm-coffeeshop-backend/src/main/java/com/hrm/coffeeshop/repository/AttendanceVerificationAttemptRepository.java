package com.hrm.coffeeshop.repository;

import com.hrm.coffeeshop.domain.AttendanceVerificationAttempt;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;

public interface AttendanceVerificationAttemptRepository extends JpaRepository<AttendanceVerificationAttempt, Long> {

    @Modifying
    @Query("delete from AttendanceVerificationAttempt a where a.attemptedAt < :cutoff")
    int purgeBefore(@Param("cutoff") Instant cutoff);
}
