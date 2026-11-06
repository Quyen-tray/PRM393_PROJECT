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

public interface ChecklistTaskRepository extends JpaRepository<ChecklistTask, Long> {

    List<ChecklistTask> findByEmployeeIdOrderByDueAtDescChecklistTaskIdDesc(Long employeeId);
    boolean existsByChecklistTemplateId(Integer templateId);
    boolean existsByChecklistTemplateIdAndShiftAssignmentId(Integer templateId, Long shiftAssignmentId);
    List<ChecklistTask> findByEmployeeIdAndRunStatusOrderByDueAtDescChecklistTaskIdDesc(Long employeeId, String status);
    long countByRunStatus(String status);
    List<ChecklistTask> findByDueAtBetween(Instant from, Instant to);
    List<ChecklistTask> findByDueAtGreaterThanEqualAndDueAtLessThan(Instant from, Instant to);

    @Query("select r from ChecklistTask r where r.employeeId = :employeeId and r.runStatus in :statuses order by r.dueAt desc, r.checklistTaskId desc")
    List<ChecklistTask> findMine(@Param("employeeId") Long employeeId, @Param("statuses") Collection<String> statuses);

    @Query("select r from ChecklistTask r where (:status = '' or r.runStatus = :status)")
    Page<ChecklistTask> searchByStatus(@Param("status") String status, Pageable p);

    @Query("select r from ChecklistTask r where r.runStatus in :statuses and r.dueAt >= :from and r.dueAt <= :to")
    List<ChecklistTask> findDueBetween(@Param("from") Instant from, @Param("to") Instant to,
                                      @Param("statuses") Collection<String> statuses);

    @Query("select r from ChecklistTask r where r.runStatus in :statuses and r.dueAt <= :now and r.dueAt >= :since")
    List<ChecklistTask> findOverdue(@Param("now") Instant now, @Param("since") Instant since,
                                   @Param("statuses") Collection<String> statuses);
}
