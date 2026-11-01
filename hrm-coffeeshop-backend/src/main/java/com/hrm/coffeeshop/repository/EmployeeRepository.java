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

public interface EmployeeRepository extends JpaRepository<Employee, Long> {

    Optional<Employee> findByUserId(Long userId);
    Optional<Employee> findByEmployeeCode(String employeeCode);
    List<Employee> findByPositionId(Integer positionId);

    /** Khóa dòng nhân viên khi phân ca: hai thao tác phân ca cùng nhân viên phải xếp hàng. */
    @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
    @Query("select e from Employee e where e.employeeId = :id")
    Optional<Employee> findByIdForUpdate(@Param("id") Long id);

    @Query("select e from Employee e where (:status = '' or e.employmentStatus = :status) "
         + "and (:jobTitle = '' or e.jobTitle = :jobTitle) "
         + "and (:q = '' or lower(e.employeeCode) like lower(concat('%', :q, '%')) "
         + "or exists (select 1 from AppUser u where u.userId = e.userId and lower(u.displayName) like lower(concat('%', :q, '%'))))")
    Page<Employee> search(@Param("q") String q, @Param("status") String status,
                                 @Param("jobTitle") String jobTitle, Pageable p);
}
