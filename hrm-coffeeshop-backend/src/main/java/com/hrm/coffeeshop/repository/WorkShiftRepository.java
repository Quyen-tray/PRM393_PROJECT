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

public interface WorkShiftRepository extends JpaRepository<WorkShift, Integer> {

    @Query("select s from WorkShift s where s.storeId = :storeId and s.isActive = true order by s.startTime")
    List<WorkShift> findByStoreIdAndIsActiveTrue(@Param("storeId") Integer storeId);

    @Query("select s from WorkShift s where s.storeId = :storeId order by s.startTime")
    List<WorkShift> findByStoreId(@Param("storeId") Integer storeId);

    Optional<WorkShift> findByStoreIdAndShiftCode(Integer storeId, String shiftCode);
}
