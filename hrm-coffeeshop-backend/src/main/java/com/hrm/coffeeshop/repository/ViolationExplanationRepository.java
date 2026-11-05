package com.hrm.coffeeshop.repository;

import com.hrm.coffeeshop.domain.ViolationExplanation;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface ViolationExplanationRepository extends JpaRepository<ViolationExplanation, Long> {
    List<ViolationExplanation> findByViolationEventIdOrderByCreatedAtAsc(Long violationEventId);
}
