package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.common.*;
import com.hrm.coffeeshop.domain.*;
import com.hrm.coffeeshop.repository.*;
import com.hrm.coffeeshop.shared.dto.TrainingDto.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.*;
import java.util.*;

@Service
public class TrainingService {
    public record Eligibility(boolean eligible,int required,int completed,List<Map<String,Object>> restrictions) {}
    private final TrainingCourseRepository courses;
    private final EmployeeTrainingRepository trainings;
    private final EmployeeRepository employees;
    private final AppUserRepository users;
    private final PositionTrainingRequirementRepository requirements;
    private final TrainingAttemptRepository attempts;
    private final AuditService audit;
    private final NotificationService notifications;
    private final Clock clock;

    public TrainingService(TrainingCourseRepository courses,EmployeeTrainingRepository trainings,EmployeeRepository employees,
                           AppUserRepository users,PositionTrainingRequirementRepository requirements,TrainingAttemptRepository attempts,
                           AuditService audit,NotificationService notifications,Clock clock) {
        this.courses=courses;this.trainings=trainings;this.employees=employees;this.users=users;
        this.requirements=requirements;this.attempts=attempts;this.audit=audit;this.notifications=notifications;this.clock=clock;
    }
    public static CourseView view(TrainingCourse c) {
        return new CourseView(c.getCourseId(),c.getCourseCode(),c.getCourseName(),c.getDescription(),
                c.getPassingScore(),c.getValidityMonths(),c.getIsMandatoryTest(),c.getIsActive());
    }
    static boolean validPass(EmployeeTraining t,Instant now) {
        return t!=null && "PASSED".equals(t.getTrainingStatus()) && (t.getExpiresAt()==null || t.getExpiresAt().isAfter(now));
    }
    static String statusOf(EmployeeTraining t,Instant now) {
        return "PASSED".equals(t.getTrainingStatus()) && t.getExpiresAt()!=null && !t.getExpiresAt().isAfter(now)
                ? "EXPIRED" : t.getTrainingStatus();
    }
    private Set<Integer> mandatory(Employee e) {
        Set<Integer> ids=new LinkedHashSet<>();
        if(e.getPositionId()!=null) requirements.findEffective(e.getPositionId(),TimeUtils.today(clock)).stream()
                .filter(r->Boolean.TRUE.equals(r.getIsMandatory())).forEach(r->ids.add(r.getCourseId()));
        return ids;
    }
    private Map<Integer,TrainingCourse> courseMap() {
        Map<Integer,TrainingCourse> map=new LinkedHashMap<>();courses.findAll().forEach(c->map.put(c.getCourseId(),c));return map;
    }
    @Transactional(readOnly=true)
    public Eligibility eligibility(Employee employee) {
        Map<Integer,TrainingCourse> map=courseMap();
        Map<Integer,EmployeeTraining> mine=new HashMap<>();
        trainings.findByEmployeeId(employee.getEmployeeId()).forEach(t->mine.put(t.getCourseId(),t));
        int required=0,done=0;
        for(Integer id:mandatory(employee)) {
            TrainingCourse c=map.get(id);if(c==null || !Boolean.TRUE.equals(c.getIsActive())) continue;
            required++;if(validPass(mine.get(id),clock.instant())) done++;
        }
        // Requirements describe learning progress; they do not block attendance or assignment.
        return new Eligibility(true,required,done,List.of());
    }
    @Transactional(readOnly=true)
    public ProgressView progress(Long employeeId) {
        Employee e=employee(employeeId); Eligibility el=eligibility(e);
        return new ProgressView(employeeId,el.required(),el.completed(),el.required()-el.completed(),"ELIGIBLE",List.of());
    }
    @Transactional(readOnly=true)
    public List<CourseView> listCourses(boolean includeInactive) {
        return (includeInactive?courses.findAll():courses.findByIsActiveTrue()).stream().map(TrainingService::view).toList();
    }
    @Transactional
    public CourseView createCourse(CourseRequest r) {
        if(courses.findByCourseCode(r.courseCode().trim()).isPresent()) throw new BusinessException(ErrorCode.CONFLICT,"Mã khóa học đã tồn tại");
        TrainingCourse c=new TrainingCourse();apply(c,r);courses.save(c);
        audit.log("TRAINING_COURSE_CREATE","TrainingCourse",c.getCourseId(),null,view(c));return view(c);
    }
    @Transactional
    public CourseView updateCourse(Integer id,CourseRequest r) {
        TrainingCourse c=course(id);
        courses.findByCourseCode(r.courseCode().trim()).filter(x->!x.getCourseId().equals(id)).ifPresent(x->{
            throw new BusinessException(ErrorCode.CONFLICT,"Mã khóa học đã tồn tại");
        });
        CourseView before=view(c);apply(c,r);audit.log("TRAINING_COURSE_UPDATE","TrainingCourse",id,before,view(c));return view(c);
    }
    private void apply(TrainingCourse c,CourseRequest r) {
        c.setCourseCode(r.courseCode().trim());c.setCourseName(r.courseName().trim());c.setDescription(r.description());
        if(r.passScore()!=null)c.setPassingScore(r.passScore());c.setValidityMonths(r.validityMonths());
        if(r.isMandatoryTest()!=null)c.setIsMandatoryTest(r.isMandatoryTest());
        if(r.isActive()!=null)c.setIsActive(r.isActive());
    }
    private MyTrainingView enrollmentView(EmployeeTraining t,TrainingCourse c,Employee e) {
        return new MyTrainingView(t.getEmployeeTrainingId(),t.getCourseId(),c.getCourseName(),mandatory(e).contains(t.getCourseId()),
                statusOf(t,clock.instant()),t.getTestScore(),TimeUtils.vn(t.getDueAt()),TimeUtils.vn(t.getCompletedAt()),
                TimeUtils.vn(t.getExpiresAt()),TimeUtils.vn(t.getCompletionReviewedAt()),t.getCompletionReviewNote());
    }
    @Transactional(readOnly=true)
    public List<MyTrainingView> mine(Long employeeId) {
        Employee e=employee(employeeId);Map<Integer,TrainingCourse> map=courseMap();
        return trainings.findByEmployeeId(employeeId).stream().filter(t->map.containsKey(t.getCourseId()))
                .map(t->enrollmentView(t,map.get(t.getCourseId()),e)).toList();
    }
    @Transactional(readOnly=true)
    public List<RequirementView> myRequirements(Long employeeId) {
        Employee e=employee(employeeId);Map<Integer,TrainingCourse> map=courseMap();
        Map<Integer,EmployeeTraining> mine=new HashMap<>();
        trainings.findByEmployeeId(employeeId).forEach(t->mine.put(t.getCourseId(),t));
        return mandatory(e).stream().map(map::get).filter(Objects::nonNull).filter(c->Boolean.TRUE.equals(c.getIsActive()))
                .map(c->{EmployeeTraining t=mine.get(c.getCourseId());return new RequirementView(c.getCourseId(),c.getCourseName(),
                        false,t==null?"NOT_ENROLLED":statusOf(t,clock.instant()),validPass(t,clock.instant()));}).toList();
    }
    @Transactional
    public MyTrainingView enroll(Integer courseId,EnrollRequest r) {
        AuthUser actor=SecurityUtils.current();
        Long id=r==null||r.employeeId()==null?SecurityUtils.requireEmployeeId():r.employeeId();
        if(!Objects.equals(id,actor.employeeId())&&!actor.isStaffReviewer())throw BusinessException.forbidden("Không thể ghi danh thay người khác");
        Employee e=employee(id);TrainingCourse c=course(courseId);
        if(!Boolean.TRUE.equals(c.getIsActive()))throw BusinessException.invalidState("Khóa học đã ngưng");
        if(trainings.findByEmployeeIdAndCourseId(id,courseId).isPresent())throw new BusinessException(ErrorCode.CONFLICT,"Đã ghi danh khóa học này");
        EmployeeTraining t=new EmployeeTraining();t.setEmployeeId(id);t.setCourseId(courseId);
        if(r!=null&&r.dueAt()!=null)t.setDueAt(r.dueAt().toInstant());trainings.saveAndFlush(t);
        audit.log("TRAINING_ENROLL","EmployeeTraining",t.getEmployeeTrainingId(),null,Map.of("employeeId",id,"courseId",courseId));
        if(Boolean.FALSE.equals(c.getIsMandatoryTest())) notifications.notifyReviewers(
                Set.of(Roles.SYSTEM_ADMIN),Set.of(Permissions.TRAINING_MANAGE),"TRAINING_PENDING_REVIEW",
                "Đăng ký đào tạo cần xác nhận",c.getCourseName(),"EmployeeTraining",t.getEmployeeTrainingId());
        return enrollmentView(t,c,e);
    }
    private void requireReviewer() {
        AuthUser actor=SecurityUtils.current();
        if(!actor.hasRole(Roles.SYSTEM_ADMIN)&&!actor.hasPermission(Permissions.TRAINING_MANAGE))
            throw BusinessException.forbidden("Không đủ quyền xác nhận đào tạo");
    }

    @Transactional(readOnly=true)
    public MyTrainingView enrollment(Long id) {
        EmployeeTraining t=trainings.findById(id).orElseThrow(()->BusinessException.notFound("đăng ký đào tạo"));
        if(!Objects.equals(t.getEmployeeId(),SecurityUtils.current().employeeId())) requireReviewer();
        return enrollmentView(t,course(t.getCourseId()),employee(t.getEmployeeId()));
    }
    private CompletionReviewView completionView(EmployeeTraining t) {
        Employee e=employee(t.getEmployeeId());TrainingCourse c=course(t.getCourseId());
        String name=users.findById(e.getUserId()).map(AppUser::getDisplayName).orElse(e.getEmployeeCode());
        return new CompletionReviewView(t.getEmployeeTrainingId(),e.getEmployeeId(),e.getEmployeeCode(),name,
                c.getCourseId(),c.getCourseName(),TimeUtils.vn(t.getAssignedAt()),statusOf(t,clock.instant()),t.getCompletionReviewNote());
    }
    @Transactional(readOnly=true)
    public List<CompletionReviewView> pendingCompletionReviews() {
        requireReviewer();Map<Integer,TrainingCourse> map=courseMap();
        return trainings.findAll().stream().filter(t->{
            TrainingCourse c=map.get(t.getCourseId());return c!=null&&Boolean.TRUE.equals(c.getIsActive())
                    &&Boolean.FALSE.equals(c.getIsMandatoryTest())&&!validPass(t,clock.instant());
        }).sorted(Comparator.comparing(EmployeeTraining::getAssignedAt,Comparator.nullsLast(Comparator.naturalOrder())))
                .map(this::completionView).toList();
    }
    @Transactional(readOnly=true)
    public CompletionReviewView completionDetail(Long id) {
        requireReviewer();return completionView(trainings.findById(id).orElseThrow(()->BusinessException.notFound("đăng ký đào tạo")));
    }
    @Transactional
    public MyTrainingView approveCompletion(Long id,String note) {return review(id,true,note);}
    @Transactional
    public MyTrainingView markNotComplete(Long id,String reason) {
        if(reason==null||reason.isBlank())throw new BusinessException(ErrorCode.VALIDATION_ERROR,"Cần lý do chưa hoàn thành");
        return review(id,false,reason);
    }
    private MyTrainingView review(Long id,boolean passed,String note) {
        requireReviewer();
        EmployeeTraining first=trainings.findById(id).orElseThrow(()->BusinessException.notFound("đăng ký đào tạo"));
        EmployeeTraining t=trainings.lockEnrollment(first.getEmployeeId(),first.getCourseId()).orElseThrow();
        TrainingCourse c=course(t.getCourseId());Employee e=employee(t.getEmployeeId());
        if(Objects.equals(e.getUserId(),SecurityUtils.current().userId()))throw BusinessException.forbidden("Không thể tự duyệt đào tạo của mình");
        if(!Boolean.TRUE.equals(c.getIsActive())||!Boolean.FALSE.equals(c.getIsMandatoryTest()))
            throw BusinessException.invalidState("Chỉ xác nhận thủ công khóa đang hoạt động không có quiz");
        if(validPass(t,clock.instant()))throw BusinessException.invalidState("Khóa học đã đạt và còn hiệu lực");
        String before=t.getTrainingStatus();Instant now=clock.instant();
        t.setTrainingStatus(passed?"PASSED":"IN_PROGRESS");t.setTestScore(null);
        t.setCompletedAt(passed?now:null);t.setExpiresAt(passed?expiry(c,now):null);
        t.setCompletionReviewedAt(now);t.setCompletionReviewedBy(SecurityUtils.current().userId());t.setCompletionReviewNote(note);
        trainings.saveAndFlush(t);
        audit.log(passed?"TRAINING_COMPLETION_APPROVE":"TRAINING_COMPLETION_NOT_COMPLETE","EmployeeTraining",id,
                Map.of("status",before),Map.of("status",t.getTrainingStatus(),"note",note==null?"":note));
        notifications.notify(e.getUserId(),"TRAINING_REVIEWED","Kết quả xác nhận đào tạo",
                c.getCourseName()+": "+(passed?"Đã hoàn thành":"Cần tiếp tục học")+(note==null?"":" — "+note),
                "EmployeeTraining",id,null);
        return enrollmentView(t,c,e);
    }
    @Transactional
    public MyTrainingView recordAttempt(Integer courseId,AttemptRequest r) {
        SecurityUtils.requirePermission(Permissions.TRAINING_MANAGE);
        TrainingCourse c=course(courseId);Employee e=employee(r.employeeId());
        if(Objects.equals(e.getUserId(),SecurityUtils.current().userId()))
            throw BusinessException.forbidden("Không thể tự ghi nhận kết quả đào tạo của chính mình");
        if(!Boolean.TRUE.equals(c.getIsActive()))throw BusinessException.invalidState("Khóa học đã ngưng");
        boolean scored=!Boolean.FALSE.equals(c.getIsMandatoryTest());
        if(scored&&(r.score()==null||r.note()==null||r.note().isBlank()))
            throw new BusinessException(ErrorCode.VALIDATION_ERROR,"Nhập điểm thủ công cần điểm và lý do ghi nhận ngoại lệ");
        EmployeeTraining t=trainings.lockEnrollment(e.getEmployeeId(),courseId).orElseGet(()->{
            EmployeeTraining n=new EmployeeTraining();n.setEmployeeId(e.getEmployeeId());n.setCourseId(courseId);return trainings.saveAndFlush(n);
        });
        if(validPass(t,clock.instant()))throw BusinessException.invalidState("Khóa học đã đạt và còn hiệu lực");
        boolean passed=!scored||r.score().compareTo(c.getPassingScore())>=0;Instant now=clock.instant();
        TrainingAttempt a=new TrainingAttempt();a.setEmployeeId(e.getEmployeeId());a.setCourseId(courseId);
        a.setAttemptNo(Math.toIntExact(attempts.countByEmployeeIdAndCourseId(e.getEmployeeId(),courseId))+1);
        a.setScore(r.score());a.setIsPassed(passed);a.setSource("MANUAL");a.setRecordedBy(SecurityUtils.current().userId());
        a.setAnswersJson(r.note());attempts.save(a);
        t.setTestScore(r.score());t.setTrainingStatus(passed?"PASSED":"FAILED");
        t.setCompletedAt(passed?now:null);t.setExpiresAt(passed?expiry(c,now):null);trainings.save(t);
        audit.log("TRAINING_ATTEMPT","EmployeeTraining",t.getEmployeeTrainingId(),null,Map.of("passed",passed,"source","MANUAL"));
        notifications.notify(e.getUserId(),"TRAINING_RESULT","Kết quả đào tạo",c.getCourseName(), "EmployeeTraining",t.getEmployeeTrainingId(),null);
        return enrollmentView(t,c,e);
    }
    static Instant expiry(TrainingCourse c,Instant now) {
        return c.getValidityMonths()==null?null:ZonedDateTime.ofInstant(now,TimeUtils.ZONE).plusMonths(c.getValidityMonths()).toInstant();
    }
    private Employee employee(Long id){return employees.findById(id).orElseThrow(()->BusinessException.notFound("nhân viên"));}
    private TrainingCourse course(Integer id){return courses.findById(id).orElseThrow(()->BusinessException.notFound("khóa học"));}
    @Transactional
    public int expireOutdated() {
        List<EmployeeTraining> expired=trainings.findExpiredPassed(clock.instant());expired.forEach(t->t.setTrainingStatus("EXPIRED"));
        return expired.size();
    }
}
