package com.hrm.coffeeshop.repository;

import com.hrm.coffeeshop.domain.*;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import jakarta.persistence.LockModeType;
import java.time.*;
import java.util.*;

public interface PayrollPeriodRepository extends JpaRepository<PayrollPeriod, Long> {

    List<PayrollPeriod> findAllByOrderByStartDateDesc();
    Optional<PayrollPeriod> findByPeriodCode(String code);

    @Query("select case when count(p) > 0 then true else false end from PayrollPeriod p where p.startDate <= :end and p.endDate >= :start")
    boolean existsOverlap(@Param("start") LocalDate start, @Param("end") LocalDate end);

    /**
     * Khóa dòng kỳ công (UPDLOCK) đến hết transaction. Chốt kỳ, mở lại và mọi thao tác đổi công
     * đều khóa kỳ này TRƯỚC khi đọc/ghi bản ghi công, nên chúng được tuần tự hóa với nhau.
     */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select p from PayrollPeriod p where p.payrollPeriodId = :id")
    Optional<PayrollPeriod> findByIdForUpdate(@Param("id") Long id);

    /** Khóa kỳ công chứa ngày làm việc. Các kỳ không chồng lấn nên tối đa một bản ghi. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select p from PayrollPeriod p where p.startDate <= :d and p.endDate >= :d")
    List<PayrollPeriod> findCoveringForUpdate(@Param("d") LocalDate d);
}
