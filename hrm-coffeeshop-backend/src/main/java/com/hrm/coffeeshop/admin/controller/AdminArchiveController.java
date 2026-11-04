package com.hrm.coffeeshop.admin.controller;

import com.hrm.coffeeshop.common.*;
import com.hrm.coffeeshop.repository.*;
import com.hrm.coffeeshop.shared.service.AuditService;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import java.util.Map;

/** Removal from active catalogs preserves references used by historical records. */
@RestController
@Transactional
@PreAuthorize("hasRole('SYSTEM_ADMIN')")
public class AdminArchiveController {
    private final TrainingCourseRepository courses;
    private final ChecklistTemplateRepository templates;
    private final WorkShiftRepository shifts;
    private final SkillRepository skills;
    private final ReminderRuleRepository reminders;
    private final AuditService audit;
    public AdminArchiveController(TrainingCourseRepository courses, ChecklistTemplateRepository templates,
        WorkShiftRepository shifts, SkillRepository skills, ReminderRuleRepository reminders, AuditService audit) {
        this.courses=courses; this.templates=templates; this.shifts=shifts; this.skills=skills; this.reminders=reminders; this.audit=audit;
    }
    private ApiResponse<Map<String, Object>> archived(String type, Integer id) {
        audit.log("CATALOG_ARCHIVE", type, id, null, Map.of("isActive", false));
        return ApiResponse.ok("Đã ngừng sử dụng; lịch sử được giữ lại", Map.of("id", id, "isActive", false));
    }
    @DeleteMapping("/admin/training/courses/{id}")
    public ApiResponse<Map<String, Object>> course(@PathVariable Integer id) {
        var item=courses.findById(id).orElseThrow(()->BusinessException.notFound("khóa học")); item.setIsActive(false); return archived("TrainingCourse", id);
    }
    @DeleteMapping("/admin/checklist-templates/{id}")
    public ApiResponse<Map<String, Object>> template(@PathVariable Integer id) {
        var item=templates.findById(id).orElseThrow(()->BusinessException.notFound("mẫu checklist")); item.setIsActive(false); return archived("ChecklistTemplate", id);
    }
    @DeleteMapping("/work-shifts/{id}")
    @PreAuthorize("hasAnyRole('SYSTEM_ADMIN','STORE_MANAGER')")
    public ApiResponse<Map<String, Object>> shift(@PathVariable Integer id) {
        var item=shifts.findById(id).orElseThrow(()->BusinessException.notFound("ca làm")); item.setIsActive(false); return archived("WorkShift", id);
    }
    @DeleteMapping("/admin/skills/{id}")
    public ApiResponse<Map<String, Object>> skill(@PathVariable Integer id) {
        var item=skills.findById(id).orElseThrow(()->BusinessException.notFound("kỹ năng")); item.setIsActive(false); return archived("Skill", id);
    }
    @DeleteMapping("/admin/reminder-rules/{id}")
    public ApiResponse<Map<String, Object>> reminder(@PathVariable String id) {
        var item=reminders.findByRuleCode(id).orElseThrow(()->BusinessException.notFound("quy tắc nhắc việc")); item.setIsActive(false); return archived("ReminderRule", item.getReminderRuleId());
    }
}
