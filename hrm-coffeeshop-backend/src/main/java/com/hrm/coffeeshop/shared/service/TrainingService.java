package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.shared.dto.TrainingDto.AttemptRequest;
import com.hrm.coffeeshop.shared.dto.TrainingDto.CourseRequest;
import com.hrm.coffeeshop.shared.dto.TrainingDto.CourseView;
import com.hrm.coffeeshop.shared.dto.TrainingDto.EnrollRequest;
import com.hrm.coffeeshop.shared.dto.TrainingDto.MyTrainingView;
import com.hrm.coffeeshop.shared.dto.TrainingDto.RequirementView;
import com.hrm.coffeeshop.shared.dto.TrainingDto.ProgressView;

import com.hrm.coffeeshop.common.*;
import com.hrm.coffeeshop.domain.Employee;
import com.hrm.coffeeshop.domain.EmployeeTraining;
import com.hrm.coffeeshop.domain.PositionTrainingRequirement;
import com.hrm.coffeeshop.domain.TrainingAttempt;
import com.hrm.coffeeshop.domain.TrainingCourse;
import com.hrm.coffeeshop.repository.EmployeeRepository;
import com.hrm.coffeeshop.repository.EmployeeTrainingRepository;
import com.hrm.coffeeshop.repository.PositionTrainingRequirementRepository;
import com.hrm.coffeeshop.repository.TrainingAttemptRepository;
import com.hrm.coffeeshop.repository.TrainingCourseRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZonedDateTime;
import java.util.*;

/**
 * Đào tạo (SRS 3.5, 7.4, 8.5, 9.7).
 * Bắt buộc theo CHỨC VỤ (PositionTrainingRequirement), không theo khóa học. Chỉ khóa có BlocksShiftAssignment
 * mới chặn nhận ca. Đạt có hạn hiệu lực (ValidityMonths); hết hạn thì coi như chưa đạt.
 */
@Service
public class TrainingService {
    public record Eligibility(boolean eligible, int required, int completed, List<Map<String, Object>> restrictions) {}

    private final TrainingCourseRepository courses;
    private final EmployeeTrainingRepository trainings;
    private final EmployeeRepository employees;
    private final PositionTrainingRequirementRepository requirements;
    private final TrainingAttemptRepository attempts;
    private final AuditService audit;
    private final Clock clock;

    public TrainingService(TrainingCourseRepository courses, EmployeeTrainingRepository trainings,
                           EmployeeRepository employees, PositionTrainingRequirementRepository requirements,
                           TrainingAttemptRepository attempts, AuditService audit, Clock clock) {
        this.courses = courses;
        this.trainings = trainings;
        this.employees = employees;
        this.requirements = requirements;
        this.attempts = attempts;
        this.audit = audit;
        this.clock = clock;
    }

    static CourseView view(TrainingCourse c) {
        return new CourseView(c.getCourseId(), c.getCourseCode(), c.getCourseName(), c.getDescription(),
                c.getPassingScore(), c.getValidityMonths(), c.getIsMandatoryTest(), c.getIsActive());
    }

    /** Đã đạt và còn hiệu lực tại thời điểm now. */
    private static boolean isValidPass(EmployeeTraining t, Instant now) {
        return t != null && "PASSED".equals(t.getTrainingStatus())
                && (t.getExpiresAt() == null || t.getExpiresAt().isAfter(now));
    }

    /** Trạng thái hiển thị: khóa đã đạt nhưng hết hạn hiệu lực là EXPIRED (SRS 8.5). */
    private static String statusOf(EmployeeTraining t, Instant now) {
        if ("PASSED".equals(t.getTrainingStatus()) && t.getExpiresAt() != null && !t.getExpiresAt().isAfter(now))
            return "EXPIRED";
        return t.getTrainingStatus();
    }

    /** Khóa bắt buộc đang hiệu lực của chức vụ nhân viên (courseId -> yêu cầu). */
    private Map<Integer, PositionTrainingRequirement> mandatoryFor(Employee e) {
        Map<Integer, PositionTrainingRequirement> out = new LinkedHashMap<>();
        if (e.getPositionId() == null) return out;
        LocalDate today = TimeUtils.today(clock);
        for (PositionTrainingRequirement r : requirements.findEffective(e.getPositionId(), today)) {
            if (Boolean.TRUE.equals(r.getIsMandatory())) out.put(r.getCourseId(), r);
        }
        return out;
    }

    private Map<Integer, TrainingCourse> courseMap() {
        Map<Integer, TrainingCourse> cs = new HashMap<>();
        courses.findAll().forEach(c -> cs.put(c.getCourseId(), c));
        return cs;
    }

    /**
     * Điều kiện nhận ca: mọi khóa có BlocksShiftAssignment đang hiệu lực của chức vụ phải đã đạt và còn hiệu lực.
     */
    @Transactional(readOnly = true)
    public Eligibility eligibility(Employee e) {
        Instant now = clock.instant();
        Map<Integer, TrainingCourse> cs = courseMap();
        Map<Integer, EmployeeTraining> mine = new HashMap<>();
        trainings.findByEmployeeId(e.getEmployeeId()).forEach(t -> mine.put(t.getCourseId(), t));
        List<Map<String, Object>> restrictions = new ArrayList<>();
        int required = 0, done = 0;
        for (PositionTrainingRequirement r : mandatoryFor(e).values()) {
            TrainingCourse c = cs.get(r.getCourseId());
            if (c == null || !Boolean.TRUE.equals(c.getIsActive())) continue;
            required++;
            EmployeeTraining t = mine.get(r.getCourseId());
            if (isValidPass(t, now)) { done++; continue; }
            if (Boolean.TRUE.equals(r.getBlocksShiftAssignment())) {
                String reason = t != null && "PASSED".equals(t.getTrainingStatus())
                        ? "Chứng chỉ đã hết hạn hiệu lực" : "Chưa hoàn thành khóa học bắt buộc";
                restrictions.add(BusinessException.details("courseId", c.getCourseId(), "courseName", c.getCourseName(),
                        "reason", reason));
            }
        }
        return new Eligibility(restrictions.isEmpty(), required, done, restrictions);
    }

    @Transactional(readOnly = true)
    public ProgressView progress(Long employeeId) {
        Employee e = employees.findById(employeeId).orElseThrow(() -> BusinessException.notFound("nhân viên"));
        Eligibility el = eligibility(e);
        return new ProgressView(employeeId, el.required(), el.completed(), el.required() - el.completed(),
                el.eligible() ? "ELIGIBLE" : "RESTRICTED", el.restrictions());
    }

    @Transactional(readOnly = true)
    public List<CourseView> listCourses(boolean includeInactive) {
        return (includeInactive ? courses.findAll() : courses.findByIsActiveTrue()).stream().map(TrainingService::view).toList();
    }

    @Transactional
    public CourseView createCourse(CourseRequest r) {
        if (courses.findByCourseCode(r.courseCode()).isPresent())
            throw new BusinessException(ErrorCode.CONFLICT, "Mã khóa học đã tồn tại");
        TrainingCourse c = new TrainingCourse();
        apply(c, r);
        courses.save(c);
        audit.log("TRAINING_COURSE_CREATE", "TrainingCourse", c.getCourseId(), null, view(c));
        return view(c);
    }

    @Transactional
    public CourseView updateCourse(Integer id, CourseRequest r) {
        TrainingCourse c = courses.findById(id).orElseThrow(() -> BusinessException.notFound("khóa học"));
        courses.findByCourseCode(r.courseCode()).filter(x -> !x.getCourseId().equals(id)).ifPresent(x -> {
            throw new BusinessException(ErrorCode.CONFLICT, "Mã khóa học đã tồn tại");
        });
        CourseView before = view(c);
        apply(c, r);
        audit.log("TRAINING_COURSE_UPDATE", "TrainingCourse", id, before, view(c));
        return view(c);
    }

    private void apply(TrainingCourse c, CourseRequest r) {
        c.setCourseCode(r.courseCode().trim());
        c.setCourseName(r.courseName().trim());
        c.setDescription(r.description());
        if (r.passScore() != null) c.setPassingScore(r.passScore());
        c.setValidityMonths(r.validityMonths());
        if (r.isMandatoryTest() != null) c.setIsMandatoryTest(r.isMandatoryTest());
        if (r.isActive() != null) c.setIsActive(r.isActive());
    }

    @Transactional(readOnly = true)
    public List<MyTrainingView> mine(Long employeeId) {
        Employee e = employees.findById(employeeId).orElseThrow(() -> BusinessException.notFound("nhân viên"));
        Instant now = clock.instant();
        Map<Integer, TrainingCourse> cs = courseMap();
        Set<Integer> mandatory = mandatoryFor(e).keySet();
        return trainings.findByEmployeeId(employeeId).stream().map(t -> {
            TrainingCourse c = cs.get(t.getCourseId());
            return new MyTrainingView(t.getCourseId(), c == null ? "" : c.getCourseName(),
                    mandatory.contains(t.getCourseId()), statusOf(t, now), t.getTestScore(),
                    TimeUtils.vn(t.getDueAt()), TimeUtils.vn(t.getCompletedAt()), TimeUtils.vn(t.getExpiresAt()));
        }).toList();
    }

    /**
     * Khóa bắt buộc đang hiệu lực của chính nhân viên, kể cả khóa chưa ghi danh.
     * Bỏ khóa không hoạt động, cùng quy tắc với điều kiện nhận ca. Không tự ghi danh: nhân viên ghi danh qua enroll.
     */
    @Transactional(readOnly = true)
    public List<RequirementView> myRequirements(Long employeeId) {
        Employee e = employees.findById(employeeId).orElseThrow(() -> BusinessException.notFound("nhân viên"));
        Instant now = clock.instant();
        Map<Integer, TrainingCourse> cs = courseMap();
        Map<Integer, EmployeeTraining> mine = new HashMap<>();
        trainings.findByEmployeeId(employeeId).forEach(t -> mine.put(t.getCourseId(), t));
        List<RequirementView> out = new ArrayList<>();
        for (PositionTrainingRequirement r : mandatoryFor(e).values()) {
            TrainingCourse c = cs.get(r.getCourseId());
            if (c == null || !Boolean.TRUE.equals(c.getIsActive())) continue;
            EmployeeTraining t = mine.get(r.getCourseId());
            out.add(new RequirementView(c.getCourseId(), c.getCourseName(),
                    Boolean.TRUE.equals(r.getBlocksShiftAssignment()),
                    t == null ? "NOT_ENROLLED" : statusOf(t, now),
                    isValidPass(t, now)));
        }
        return out;
    }

    @Transactional
    public MyTrainingView enroll(Integer courseId, EnrollRequest r) {
        AuthUser u = SecurityUtils.current();
        Long target;
        if (r == null || r.employeeId() == null) target = SecurityUtils.requireEmployeeId();
        else {
            if (!u.isStaffReviewer() && !r.employeeId().equals(u.employeeId())) throw BusinessException.forbidden("Bạn không thể đăng ký học thay người khác");
            target = r.employeeId();
        }
        Employee emp = employees.findById(target).orElseThrow(() -> BusinessException.notFound("nhân viên"));
        TrainingCourse c = courses.findById(courseId).filter(x -> Boolean.TRUE.equals(x.getIsActive()))
                .orElseThrow(() -> BusinessException.notFound("khóa học"));
        if (trainings.findByEmployeeIdAndCourseId(target, courseId).isPresent())
            throw new BusinessException(ErrorCode.CONFLICT, "Nhân viên đã được ghi danh khóa học này");
        EmployeeTraining t = new EmployeeTraining();
        t.setEmployeeId(target);
        t.setCourseId(courseId);
        if (r != null && r.dueAt() != null) t.setDueAt(r.dueAt().toInstant());
        trainings.save(t);
        audit.log("TRAINING_ENROLL", "EmployeeTraining", t.getEmployeeTrainingId(), null, Map.of("employeeId", target, "courseId", courseId));
        return new MyTrainingView(courseId, c.getCourseName(), mandatoryFor(emp).containsKey(courseId), t.getTrainingStatus(),
                null, TimeUtils.vn(t.getDueAt()), null, null);
    }

    /**
     * Ghi một lượt thi (SRS 7.4 TrainingAttempt). Điểm do người được ủy quyền hoặc hệ thống LMS tin cậy nhập.
     * Khóa có IsMandatoryTest bắt buộc có điểm; khóa không có bài thi thì đạt khi ghi nhận.
     */
    @Transactional
    public MyTrainingView recordAttempt(Integer courseId, AttemptRequest r) {
        SecurityUtils.requirePermission(Permissions.TRAINING_MANAGE);
        TrainingCourse c = courses.findById(courseId).filter(x -> Boolean.TRUE.equals(x.getIsActive()))
                .orElseThrow(() -> BusinessException.notFound("khóa học"));
        Employee emp = employees.findById(r.employeeId()).orElseThrow(() -> BusinessException.notFound("nhân viên"));
        boolean scored = !Boolean.FALSE.equals(c.getIsMandatoryTest());
        if (scored && r.score() == null) throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Khóa học yêu cầu điểm thi");
        Instant now = clock.instant();
        EmployeeTraining t = trainings.findByEmployeeIdAndCourseId(r.employeeId(), courseId).orElseGet(() -> {
            EmployeeTraining n = new EmployeeTraining();
            n.setEmployeeId(r.employeeId());
            n.setCourseId(courseId);
            return n;
        });
        if (isValidPass(t, now)) throw BusinessException.invalidState("Nhân viên đã đạt khóa học này và còn hiệu lực");

        boolean passed = !scored || r.score().compareTo(c.getPassingScore()) >= 0;
        int attemptNo = (int) attempts.countByEmployeeIdAndCourseId(r.employeeId(), courseId) + 1;
        TrainingAttempt a = new TrainingAttempt();
        a.setEmployeeId(r.employeeId());
        a.setCourseId(courseId);
        a.setAttemptNo(attemptNo);
        a.setScore(r.score());
        a.setIsPassed(passed);
        a.setSource("MANUAL");
        a.setRecordedBy(SecurityUtils.current().userId());
        a.setRecordedAt(now);
        attempts.save(a);

        Map<String, Object> before = new LinkedHashMap<>();
        before.put("status", String.valueOf(t.getTrainingStatus()));
        before.put("score", String.valueOf(t.getTestScore()));
        t.setTestScore(r.score());
        t.setTrainingStatus(passed ? "PASSED" : "FAILED");
        if (passed) {
            t.setCompletedAt(now);
            t.setExpiresAt(c.getValidityMonths() == null ? null
                    : ZonedDateTime.ofInstant(now, TimeUtils.ZONE).plusMonths(c.getValidityMonths()).toInstant());
        }
        trainings.save(t);
        Map<String, Object> after = new LinkedHashMap<>();
        after.put("status", t.getTrainingStatus());
        after.put("attemptNo", attemptNo);
        after.put("courseId", courseId);
        if (r.score() != null) after.put("score", r.score());
        audit.log("TRAINING_ATTEMPT", "EmployeeTraining", t.getEmployeeTrainingId(), before, after);
        return new MyTrainingView(courseId, c.getCourseName(), mandatoryFor(emp).containsKey(courseId), t.getTrainingStatus(),
                t.getTestScore(), TimeUtils.vn(t.getDueAt()), TimeUtils.vn(t.getCompletedAt()), TimeUtils.vn(t.getExpiresAt()));
    }

    /** Chuyển khóa đã đạt nhưng hết hạn sang EXPIRED (chạy định kỳ bởi MaintenanceJob). */
    @Transactional
    public int expireOutdated() {
        List<EmployeeTraining> expired = trainings.findExpiredPassed(clock.instant());
        expired.forEach(t -> t.setTrainingStatus("EXPIRED"));
        if (!expired.isEmpty()) audit.log("TRAINING_EXPIRE", "EmployeeTraining", "batch", null, Map.of("count", expired.size()));
        return expired.size();
    }
}
