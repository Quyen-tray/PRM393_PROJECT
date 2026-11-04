package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.common.*;
import com.hrm.coffeeshop.domain.Employee;
import com.hrm.coffeeshop.domain.EmployeeSkill;
import com.hrm.coffeeshop.domain.Skill;
import com.hrm.coffeeshop.repository.EmployeeRepository;
import com.hrm.coffeeshop.repository.EmployeeSkillRepository;
import com.hrm.coffeeshop.repository.SkillRepository;
import com.hrm.coffeeshop.shared.dto.SkillDto.AssessRequest;
import com.hrm.coffeeshop.shared.dto.SkillDto.AssessmentView;
import com.hrm.coffeeshop.shared.dto.SkillDto.SkillRequest;
import com.hrm.coffeeshop.shared.dto.SkillDto.SkillView;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/** FR-012: danh mục kỹ năng + đánh giá kỹ năng theo nhân viên (giữ lịch sử, mức 1–5). */
@Service
public class SkillService {
    private final SkillRepository skills;
    private final EmployeeSkillRepository assessments;
    private final EmployeeRepository employees;
    private final AuditService audit;

    public SkillService(SkillRepository skills, EmployeeSkillRepository assessments,
                        EmployeeRepository employees, AuditService audit) {
        this.skills = skills;
        this.assessments = assessments;
        this.employees = employees;
        this.audit = audit;
    }

    @Transactional(readOnly = true)
    public List<SkillView> list() { return skills.findActive().stream().map(SkillService::view).toList(); }

    @Transactional
    public SkillView create(SkillRequest r) {
        String code = r.skillCode().trim().toUpperCase();
        if (skills.existsBySkillCode(code)) throw new BusinessException(ErrorCode.CONFLICT, "Mã kỹ năng đã tồn tại");
        Skill s = new Skill();
        s.setSkillCode(code);
        s.setSkillName(r.skillName().trim());
        s.setDescription(r.description() == null || r.description().isBlank() ? null : r.description().trim());
        skills.save(s);
        audit.log("SKILL_CREATE", "Skill", s.getSkillId(), null, Map.of("code", code, "name", s.getSkillName()));
        return view(s);
    }

    /** Người đánh giá cần TRAINING_MANAGE (kiểm ở controller) và không được tự đánh giá chính mình. */
    @Transactional
    public AssessmentView assess(Long employeeId, AssessRequest r) {
        AuthUser cu = SecurityUtils.current();
        Employee e = employees.findById(employeeId).orElseThrow(() -> BusinessException.notFound("nhân viên"));
        if (e.getEmployeeId().equals(cu.employeeId()))
            throw BusinessException.rule("Không thể tự đánh giá kỹ năng của chính mình");
        Skill s = skills.findById(r.skillId()).filter(x -> Boolean.TRUE.equals(x.getIsActive()))
                .orElseThrow(() -> BusinessException.notFound("kỹ năng"));
        EmployeeSkill a = new EmployeeSkill();
        a.setEmployeeId(employeeId);
        a.setSkillId(s.getSkillId());
        a.setSkillLevel(r.level());
        a.setNote(r.note() == null || r.note().isBlank() ? null : r.note().trim());
        a.setAssessedBy(cu.userId());
        assessments.save(a);
        audit.log("SKILL_ASSESS", "Employee", employeeId, null,
                Map.of("skillId", s.getSkillId(), "level", r.level()));
        return view(a, s.getSkillName());
    }

    /** Lịch sử đánh giá (mới nhất trước). Bản thân hoặc người có EMPLOYEE_VIEW. */
    @Transactional(readOnly = true)
    public List<AssessmentView> history(Long employeeId) {
        AuthUser cu = SecurityUtils.current();
        employees.findById(employeeId).orElseThrow(() -> BusinessException.notFound("nhân viên"));
        if (!employeeId.equals(cu.employeeId()) && !cu.hasPermission(Permissions.EMPLOYEE_VIEW))
            throw BusinessException.forbidden("Bạn không có quyền xem kỹ năng của nhân viên này");
        Map<Integer, String> names = new HashMap<>();
        skills.findAll().forEach(s -> names.put(s.getSkillId(), s.getSkillName()));
        return assessments.findByEmployeeIdOrderByAssessedAtDesc(employeeId).stream()
                .map(a -> view(a, names.get(a.getSkillId()))).toList();
    }

    private static SkillView view(Skill s) {
        return new SkillView(s.getSkillId(), s.getSkillCode(), s.getSkillName(), s.getDescription());
    }

    private static AssessmentView view(EmployeeSkill a, String skillName) {
        return new AssessmentView(a.getAssessmentId(), a.getEmployeeId(), a.getSkillId(), skillName, a.getSkillLevel(),
                a.getNote(), a.getAssessedBy(), a.getAssessedAt());
    }
}
