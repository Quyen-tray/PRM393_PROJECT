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

public interface PositionDocumentRequirementRepository extends JpaRepository<PositionDocumentRequirement, Integer> {

    List<PositionDocumentRequirement> findByPositionIdOrderByEffectiveFromAsc(Integer positionId);

    /** Yêu cầu đang hiệu lực tại ngày d (SRS 7.4). */
    @Query("select r from PositionDocumentRequirement r where r.positionId = :positionId "
         + "and r.effectiveFrom <= :d and (r.effectiveTo is null or r.effectiveTo >= :d)")
    List<PositionDocumentRequirement> findEffective(@Param("positionId") Integer positionId, @Param("d") LocalDate d);
}
