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

public interface AttendanceDeviceRepository extends JpaRepository<AttendanceDevice, Long> {

    boolean existsByEmployeeIdAndStatus(Long employeeId, String status);
    List<AttendanceDevice> findByEmployeeIdOrderByRequestedAtDesc(Long employeeId);
    Page<AttendanceDevice> findByStatusOrderByRequestedAtAsc(String status, Pageable p);
    long countByStatus(String status);

    @Query("select d from AttendanceDevice d where d.employeeId = :employeeId and d.status = 'ACTIVE'")
    Optional<AttendanceDevice> findActiveByEmployeeId(@Param("employeeId") Long employeeId);

    @Query("select d from AttendanceDevice d where d.deviceFingerprint = :hash and d.status = 'ACTIVE'")
    List<AttendanceDevice> findActiveByFingerprint(@Param("hash") String hash);
}
