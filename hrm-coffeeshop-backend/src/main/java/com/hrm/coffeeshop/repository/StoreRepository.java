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

public interface StoreRepository extends JpaRepository<Store, Integer> {

    Optional<Store> findFirstByIsActiveTrueOrderByStoreIdAsc();

    /** Khóa dòng cửa hàng (PESSIMISTIC_WRITE) đến hết transaction: dùng để tuần tự hóa việc tạo kỳ công. */
    @org.springframework.data.jpa.repository.Lock(jakarta.persistence.LockModeType.PESSIMISTIC_WRITE)
    @Query("select s from Store s where s.storeId = :id")
    Optional<Store> findByIdForUpdate(@Param("id") Integer id);
}
