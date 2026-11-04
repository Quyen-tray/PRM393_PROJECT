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

public interface EmployeeDocumentRepository extends JpaRepository<EmployeeDocument, Long> {

    List<EmployeeDocument> findByEmployeeId(Long employeeId);

    List<EmployeeDocument> findByEmployeeIdOrderByUploadedAtDesc(Long employeeId);

    boolean existsByEmployeeIdAndDocumentTypeIdAndReviewStatus(Long employeeId, Integer documentTypeId, String status);

    long countByReviewStatus(String status);

    @Modifying
    @Query("""
                update EmployeeDocument d
                set d.reviewStatus = 'EXPIRED'
                where d.reviewStatus = 'APPROVED'
                  and d.expiresAt is not null
                  and d.expiresAt < :today
            """)
    int markExpired(@Param("today") LocalDate today);

    List<EmployeeDocument> findTop100ByReviewStatusOrderByUploadedAtAsc(String status);
}
