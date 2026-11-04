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

public interface EmployeeTrainingRepository extends JpaRepository<EmployeeTraining, Long> {

    List<EmployeeTraining> findByEmployeeId(Long employeeId);
    Optional<EmployeeTraining> findByEmployeeIdAndCourseId(Long employeeId, Integer courseId);

    @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
    @Query("select t from EmployeeTraining t where t.employeeId = :employeeId and t.courseId = :courseId")
    Optional<EmployeeTraining> lockEnrollment(@Param("employeeId") Long employeeId, @Param("courseId") Integer courseId);

    /** Khóa đã đạt nhưng hết hạn hiệu lực: chuyển sang EXPIRED (SRS 8.5). */
    @Query("select t from EmployeeTraining t where t.trainingStatus = 'PASSED' "
         + "and t.expiresAt is not null and t.expiresAt < :now")
    List<EmployeeTraining> findExpiredPassed(@Param("now") Instant now);
}
