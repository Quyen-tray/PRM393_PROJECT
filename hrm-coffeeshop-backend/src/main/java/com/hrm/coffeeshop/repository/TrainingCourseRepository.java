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

public interface TrainingCourseRepository extends JpaRepository<TrainingCourse, Integer> {

    Optional<TrainingCourse> findByCourseCode(String code);

    @Query("select c from TrainingCourse c where c.isActive = true")
    List<TrainingCourse> findByIsActiveTrue();
}
