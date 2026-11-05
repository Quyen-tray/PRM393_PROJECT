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
    @Query("select d.employeeId from AttendanceDevice d where d.deviceId = :id")
    Optional<Long> employeeIdOfDevice(@Param("id") Long id);

    boolean existsByEmployeeIdAndStatus(Long employeeId, String status);
    List<AttendanceDevice> findByEmployeeIdOrderByRequestedAtDesc(Long employeeId);
    Page<AttendanceDevice> findByStatusOrderByRequestedAtAsc(String status, Pageable p);
    long countByStatus(String status);

    @Query("select d from AttendanceDevice d, Employee e, AppUser u " +
            "where d.employeeId=e.employeeId and e.userId=u.userId " +
            "and (:status='' or d.status=:status) and (:employeeId=0 or d.employeeId=:employeeId) " +
            "and (:q='' or lower(d.deviceName) like lower(concat('%',:q,'%')) " +
            "or lower(u.displayName) like lower(concat('%',:q,'%')) " +
            "or lower(e.employeeCode) like lower(concat('%',:q,'%')))")
    Page<AttendanceDevice> search(@Param("status") String status, @Param("employeeId") Long employeeId,
                                  @Param("q") String q, Pageable p);

    @Query("select d from AttendanceDevice d where d.employeeId = :employeeId and d.status = 'ACTIVE'")
    Optional<AttendanceDevice> findActiveByEmployeeId(@Param("employeeId") Long employeeId);

    @Query("select d from AttendanceDevice d where d.deviceFingerprint = :hash and d.status = 'ACTIVE'")
    List<AttendanceDevice> findActiveByFingerprint(@Param("hash") String hash);
}
