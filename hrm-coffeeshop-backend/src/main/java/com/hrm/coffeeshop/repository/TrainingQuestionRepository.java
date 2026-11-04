package com.hrm.coffeeshop.repository;

import com.hrm.coffeeshop.domain.TrainingQuestion;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface TrainingQuestionRepository extends JpaRepository<TrainingQuestion, Long> {
    List<TrainingQuestion> findByCourseIdOrderBySortOrderAscQuestionIdAsc(Integer courseId);
    List<TrainingQuestion> findByCourseIdAndIsActiveTrueOrderBySortOrderAscQuestionIdAsc(Integer courseId);
    void deleteByCourseId(Integer courseId);
}
