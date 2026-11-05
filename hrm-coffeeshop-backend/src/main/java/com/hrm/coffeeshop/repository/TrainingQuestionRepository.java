package com.hrm.coffeeshop.repository;
import com.hrm.coffeeshop.domain.TrainingQuestion;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
public interface TrainingQuestionRepository extends JpaRepository<TrainingQuestion,Long> {
    List<TrainingQuestion> findByCourseIdAndIsActiveTrueOrderBySortOrderAscQuestionIdAsc(Integer courseId);
    List<TrainingQuestion> findByCourseIdOrderBySortOrderAscQuestionIdAsc(Integer courseId);
}
