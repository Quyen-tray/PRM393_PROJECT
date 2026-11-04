package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.shared.dto.JobPositionDto.DocRequirementItem;
import com.hrm.coffeeshop.shared.dto.JobPositionDto.DocRequirementView;
import com.hrm.coffeeshop.shared.dto.JobPositionDto.DocRequirementsRequest;
import com.hrm.coffeeshop.shared.dto.JobPositionDto.PositionRequest;
import com.hrm.coffeeshop.shared.dto.JobPositionDto.PositionView;
import com.hrm.coffeeshop.shared.dto.JobPositionDto.TrainingRequirementItem;
import com.hrm.coffeeshop.shared.dto.JobPositionDto.TrainingRequirementView;
import com.hrm.coffeeshop.shared.dto.JobPositionDto.TrainingRequirementsRequest;

import com.hrm.coffeeshop.common.*;
import com.hrm.coffeeshop.domain.*;
import com.hrm.coffeeshop.repository.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDate;
import java.util.*;

/** Chức vụ và bộ yêu cầu hồ sơ/đào tạo theo chức vụ (SRS 7.3, 7.4, 9.3, 9.4, 9.7). */
@Service
public class JobPositionService {
    private final JobPositionRepository positions;
    private final PositionDocumentRequirementRepository docReqs;
    private final PositionTrainingRequirementRepository trainReqs;
    private final DocumentTypeRepository types;
    private final TrainingCourseRepository courses;
    private final EmployeeRepository employees;
    private final AuditService audit;
    private final Clock clock;

    public JobPositionService(JobPositionRepository positions, PositionDocumentRequirementRepository docReqs,
                              PositionTrainingRequirementRepository trainReqs, DocumentTypeRepository types,
                              TrainingCourseRepository courses, EmployeeRepository employees,
                              AuditService audit, Clock clock) {
        this.positions = positions;
        this.docReqs = docReqs;
        this.trainReqs = trainReqs;
        this.types = types;
        this.courses = courses;
        this.employees = employees;
        this.audit = audit;
        this.clock = clock;
    }

    static PositionView view(JobPosition p) {
        return new PositionView(p.getPositionId(), p.getPositionCode(), p.getPositionName(), p.getDescription(), p.getIsActive());
    }

    @Transactional(readOnly = true)
    public List<PositionView> list(boolean includeInactive) {
        List<JobPosition> all = includeInactive ? positions.findAll() : positions.findByIsActiveTrueOrderByPositionNameAsc();
        return all.stream().sorted(Comparator.comparing(JobPosition::getPositionName)).map(JobPositionService::view).toList();
    }

    @Transactional
    public PositionView create(PositionRequest r) {
        String code = r.positionCode().trim();
        String name = r.positionName().trim();
        if (positions.findByPositionCode(code).isPresent())
            throw new BusinessException(ErrorCode.CONFLICT, "Mã chức vụ đã tồn tại");
        if (positions.findByPositionName(name).isPresent())
            throw new BusinessException(ErrorCode.CONFLICT, "Tên chức vụ đã tồn tại");
        JobPosition p = new JobPosition();
        p.setPositionCode(code);
        p.setPositionName(name);
        p.setDescription(r.description());
        if (r.isActive() != null) p.setIsActive(r.isActive());
        positions.save(p);
        audit.log("JOB_POSITION_CREATE", "JobPosition", p.getPositionId(), null, view(p));
        return view(p);
    }

    @Transactional
    public PositionView update(Integer id, PositionRequest r) {
        JobPosition p = requirePosition(id);
        String code = r.positionCode().trim();
        String name = r.positionName().trim();
        positions.findByPositionCode(code).filter(x -> !x.getPositionId().equals(id)).ifPresent(x -> {
            throw new BusinessException(ErrorCode.CONFLICT, "Mã chức vụ đã tồn tại");
        });
        positions.findByPositionName(name).filter(x -> !x.getPositionId().equals(id)).ifPresent(x -> {
            throw new BusinessException(ErrorCode.CONFLICT, "Tên chức vụ đã tồn tại");
        });
        PositionView before = view(p);
        p.setPositionCode(code);
        p.setPositionName(name);
        p.setDescription(r.description());
        if (r.isActive() != null) p.setIsActive(r.isActive());
        p.setUpdatedAt(clock.instant());
        // Nhãn JobTitle của nhân viên luôn khớp tên chức vụ
        for (Employee e : employees.findByPositionId(id)) e.setJobTitle(name);
        audit.log("JOB_POSITION_UPDATE", "JobPosition", id, before, view(p));
        return view(p);
    }

    // ---------- Bộ hồ sơ theo chức vụ ----------

    @Transactional(readOnly = true)
    public List<DocRequirementView> documentRequirements(Integer positionId) {
        requirePosition(positionId);
        Map<Integer, DocumentType> tm = typeMap();
        return docReqs.findByPositionIdOrderByEffectiveFromAsc(positionId).stream()
                .map(r -> new DocRequirementView(r.getRequirementId(),
                        tm.get(r.getDocumentTypeId()) == null ? null : DocumentService.view(tm.get(r.getDocumentTypeId())),
                        r.getIsMandatory(), r.getEffectiveFrom(), r.getEffectiveTo()))
                .toList();
    }

    /** Thay toàn bộ bộ hồ sơ của chức vụ. Trạng thái cũ được ghi vào audit trước khi thay. */
    @Transactional
    public List<DocRequirementView> replaceDocumentRequirements(Integer positionId, DocRequirementsRequest r) {
        requirePosition(positionId);
        Map<Integer, DocumentType> tm = typeMap();
        Set<String> seen = new HashSet<>();
        for (DocRequirementItem it : r.requirements()) {
            DocumentType t = tm.get(it.documentTypeId());
            if (t == null || !Boolean.TRUE.equals(t.getIsActive()))
                throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Loại hồ sơ không tồn tại hoặc đã ngưng: " + it.documentTypeId());
            checkWindow(it.effectiveFrom(), it.effectiveTo());
            if (!seen.add(it.documentTypeId() + "|" + it.effectiveFrom()))
                throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Trùng loại hồ sơ và ngày hiệu lực trong bộ yêu cầu");
        }
        List<DocRequirementView> before = documentRequirements(positionId);
        docReqs.deleteAll(docReqs.findByPositionIdOrderByEffectiveFromAsc(positionId));
        docReqs.flush();
        for (DocRequirementItem it : r.requirements()) {
            PositionDocumentRequirement n = new PositionDocumentRequirement();
            n.setPositionId(positionId);
            n.setDocumentTypeId(it.documentTypeId());
            n.setIsMandatory(it.isMandatory() == null || it.isMandatory());
            n.setEffectiveFrom(it.effectiveFrom());
            n.setEffectiveTo(it.effectiveTo());
            docReqs.save(n);
        }
        docReqs.flush();
        List<DocRequirementView> after = documentRequirements(positionId);
        audit.log("POSITION_DOCUMENT_REQUIREMENTS", "JobPosition", positionId, before, after);
        return after;
    }

    // ---------- Khóa đào tạo theo chức vụ ----------

    @Transactional(readOnly = true)
    public List<TrainingRequirementView> trainingRequirements(Integer positionId) {
        requirePosition(positionId);
        Map<Integer, TrainingCourse> cm = courseMap();
        return trainReqs.findByPositionIdOrderByEffectiveFromAsc(positionId).stream()
                .map(r -> trainView(r, cm)).toList();
    }

    /** Thay toàn bộ khóa được theo dõi cho chức vụ; đào tạo không chặn phân ca. */
    @Transactional
    public List<TrainingRequirementView> replaceTrainingRequirements(Integer positionId, TrainingRequirementsRequest r) {
        requirePosition(positionId);
        Map<Integer, TrainingCourse> cm = courseMap();
        Set<String> seen = new HashSet<>();
        for (TrainingRequirementItem it : r.requirements()) {
            if (!cm.containsKey(it.courseId()))
                throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Khóa học không tồn tại: " + it.courseId());
            checkWindow(it.effectiveFrom(), it.effectiveTo());
            if (!seen.add(it.courseId() + "|" + it.effectiveFrom()))
                throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Trùng khóa học và ngày hiệu lực trong bộ yêu cầu");
        }
        List<TrainingRequirementView> before = trainingRequirements(positionId);
        trainReqs.deleteAll(trainReqs.findByPositionIdOrderByEffectiveFromAsc(positionId));
        trainReqs.flush();
        for (TrainingRequirementItem it : r.requirements()) {
            PositionTrainingRequirement n = new PositionTrainingRequirement();
            n.setPositionId(positionId);
            n.setCourseId(it.courseId());
            n.setIsMandatory(it.isMandatory() == null || it.isMandatory());
            n.setBlocksShiftAssignment(false);
            n.setEffectiveFrom(it.effectiveFrom());
            n.setEffectiveTo(it.effectiveTo());
            trainReqs.save(n);
        }
        trainReqs.flush();
        List<TrainingRequirementView> after = trainingRequirements(positionId);
        audit.log("POSITION_TRAINING_REQUIREMENTS", "JobPosition", positionId, before, after);
        return after;
    }

    // ---------- helpers ----------

    private JobPosition requirePosition(Integer id) {
        return positions.findById(id).orElseThrow(() -> BusinessException.notFound("chức vụ"));
    }

    private static void checkWindow(LocalDate from, LocalDate to) {
        if (to != null && to.isBefore(from))
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Ngày hết hiệu lực phải sau hoặc bằng ngày có hiệu lực");
    }

    private Map<Integer, DocumentType> typeMap() {
        Map<Integer, DocumentType> tm = new HashMap<>();
        types.findAll().forEach(t -> tm.put(t.getDocumentTypeId(), t));
        return tm;
    }

    private Map<Integer, TrainingCourse> courseMap() {
        Map<Integer, TrainingCourse> cm = new HashMap<>();
        courses.findAll().forEach(c -> cm.put(c.getCourseId(), c));
        return cm;
    }

    private static TrainingRequirementView trainView(PositionTrainingRequirement r, Map<Integer, TrainingCourse> cm) {
        TrainingCourse c = cm.get(r.getCourseId());
        return new TrainingRequirementView(r.getRequirementId(), r.getCourseId(), c == null ? null : c.getCourseName(),
                r.getIsMandatory(), false, r.getEffectiveFrom(), r.getEffectiveTo());
    }
}
