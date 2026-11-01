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

public interface ChecklistTemplateRepository extends JpaRepository<ChecklistTemplate, Integer> {

    @Query("select t from ChecklistTemplate t where t.storeId = :storeId and t.isActive = true order by t.checklistName")
    List<ChecklistTemplate> findByStoreIdAndIsActiveTrue(@Param("storeId") Integer storeId);

    @Query("select t from ChecklistTemplate t where t.storeId = :storeId order by t.checklistName")
    List<ChecklistTemplate> findByStoreId(@Param("storeId") Integer storeId);

    /** Mọi version của một mã mẫu (BR-CHK-01). */
    List<ChecklistTemplate> findByStoreIdAndChecklistCode(Integer storeId, String code);

    Optional<ChecklistTemplate> findFirstByStoreIdAndChecklistCodeOrderByVersionDesc(Integer storeId, String code);
}
