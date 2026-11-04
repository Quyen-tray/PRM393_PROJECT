package com.hrm.coffeeshop.shared.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.hrm.coffeeshop.common.*;
import com.hrm.coffeeshop.domain.*;
import com.hrm.coffeeshop.repository.*;
import com.hrm.coffeeshop.shared.dto.TrainingDto.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.math.*;
import java.time.*;
import java.util.*;

@Service
public class TrainingQuizService {
    private final TrainingCourseRepository courses;
    private final TrainingQuestionRepository questions;
    private final EmployeeTrainingRepository enrollments;
    private final TrainingAttemptRepository attempts;
    private final AuditService audit;
    private final ObjectMapper mapper;
    private final Clock clock;
    public TrainingQuizService(TrainingCourseRepository courses,TrainingQuestionRepository questions,
                               EmployeeTrainingRepository enrollments,TrainingAttemptRepository attempts,
                               AuditService audit,ObjectMapper mapper,Clock clock){
        this.courses=courses;this.questions=questions;this.enrollments=enrollments;this.attempts=attempts;
        this.audit=audit;this.mapper=mapper;this.clock=clock;
    }
    private TrainingCourse course(Integer id){
        TrainingCourse c=courses.findById(id).filter(x->Boolean.TRUE.equals(x.getIsActive()))
                .orElseThrow(()->BusinessException.notFound("khóa học"));
        if(!Boolean.TRUE.equals(c.getIsMandatoryTest()))throw BusinessException.invalidState("Khóa học không có bài trắc nghiệm");
        return c;
    }
    private List<TrainingQuestion> active(Integer id){
        List<TrainingQuestion> q=questions.findByCourseIdAndIsActiveTrueOrderBySortOrderAscQuestionIdAsc(id);
        if(q.isEmpty())throw BusinessException.invalidState("Khóa học chưa có câu hỏi");return q;
    }
    @Transactional(readOnly=true)
    public List<QuizQuestionView> quiz(Integer id){
        course(id);enrollments.findByEmployeeIdAndCourseId(SecurityUtils.requireEmployeeId(),id)
                .orElseThrow(()->BusinessException.invalidState("Hãy ghi danh trước khi làm bài"));
        return active(id).stream().map(q->new QuizQuestionView(q.getQuestionId(),q.getQuestionText(),List.of(
                new QuizOptionView("A",q.getOptionA()),new QuizOptionView("B",q.getOptionB()),
                new QuizOptionView("C",q.getOptionC()),new QuizOptionView("D",q.getOptionD())))).toList();
    }
    @Transactional
    public QuizResultView submit(Integer id,QuizSubmissionRequest r){
        Long employeeId=SecurityUtils.requireEmployeeId();TrainingCourse c=course(id);
        EmployeeTraining e=enrollments.lockEnrollment(employeeId,id)
                .orElseThrow(()->BusinessException.invalidState("Hãy ghi danh trước khi làm bài"));
        if(TrainingService.validPass(e,clock.instant()))throw BusinessException.invalidState("Khóa học đã đạt và còn hiệu lực");
        List<TrainingQuestion> bank=active(id);Map<Long,String> selections=new HashMap<>();
        for(QuizAnswerRequest a:r.answers()){
            if(selections.putIfAbsent(a.questionId(),a.selectedOption().trim().toUpperCase(Locale.ROOT))!=null)
                throw new BusinessException(ErrorCode.VALIDATION_ERROR,"Câu hỏi được trả lời trùng");
        }
        Set<Long> expected=new HashSet<>();bank.forEach(q->expected.add(q.getQuestionId()));
        if(!expected.equals(selections.keySet()))throw new BusinessException(ErrorCode.VALIDATION_ERROR,"Cần trả lời đúng và đầy đủ bộ câu hỏi hiện tại");
        List<QuizAnswerResultView> result=bank.stream().map(q->new QuizAnswerResultView(q.getQuestionId(),q.getQuestionText(),
                selections.get(q.getQuestionId()),q.getCorrectOption(),q.getCorrectOption().equals(selections.get(q.getQuestionId())))).toList();
        int correct=(int)result.stream().filter(QuizAnswerResultView::correct).count();
        BigDecimal score=BigDecimal.valueOf(correct).multiply(BigDecimal.valueOf(100))
                .divide(BigDecimal.valueOf(bank.size()),2,RoundingMode.HALF_UP);
        boolean passed=score.compareTo(c.getPassingScore())>=0;Instant now=clock.instant();
        TrainingAttempt a=new TrainingAttempt();a.setEmployeeId(employeeId);a.setCourseId(id);
        a.setAttemptNo(Math.toIntExact(attempts.countByEmployeeIdAndCourseId(employeeId,id))+1);
        a.setScore(score);a.setIsPassed(passed);a.setSource("QUIZ");a.setRecordedAt(now);a.setRecordedBy(SecurityUtils.current().userId());
        try {a.setAnswersJson(mapper.writeValueAsString(Map.of("courseName",c.getCourseName(),"passScore",c.getPassingScore(),"answers",result)));}
        catch(JsonProcessingException ex){throw new IllegalStateException("Cannot persist quiz snapshot",ex);}
        attempts.saveAndFlush(a);e.setTestScore(score);e.setTrainingStatus(passed?"PASSED":"FAILED");
        e.setCompletedAt(passed?now:null);e.setExpiresAt(passed?TrainingService.expiry(c,now):null);
        enrollments.save(e);audit.log("TRAINING_QUIZ_SUBMIT","TrainingAttempt",a.getAttemptId(),null,
                Map.of("score",score,"passed",passed,"attemptNo",a.getAttemptNo()));
        return new QuizResultView(a.getAttemptId(),id,c.getCourseName(),bank.size(),correct,score,c.getPassingScore(),
                passed,a.getAttemptNo(),e.getTrainingStatus(),result);
    }
    @Transactional(readOnly=true)
    public List<AttemptView> attempts(Integer id){
        return attempts.findByEmployeeIdAndCourseIdOrderByAttemptNoAsc(SecurityUtils.requireEmployeeId(),id).stream()
                .map(a->new AttemptView(a.getAttemptId(),id,a.getAttemptNo(),a.getScore(),Boolean.TRUE.equals(a.getIsPassed()),
                        a.getSource(),TimeUtils.vn(a.getRecordedAt()),a.getAnswersJson())).toList();
    }
    @Transactional(readOnly=true)
    public List<QuizAdminQuestionView> adminQuestions(Integer id){
        courses.findById(id).orElseThrow(()->BusinessException.notFound("khóa học"));
        return questions.findByCourseIdAndIsActiveTrueOrderBySortOrderAscQuestionIdAsc(id).stream().map(this::adminView).toList();
    }
    @Transactional
    public List<QuizAdminQuestionView> replaceQuestions(Integer id,QuizQuestionListRequest r){
        courses.findById(id).orElseThrow(()->BusinessException.notFound("khóa học"));
        Set<Integer> orders=new HashSet<>();
        for(QuizQuestionRequest q:r.questions())if(!orders.add(q.sortOrder()))
            throw new BusinessException(ErrorCode.VALIDATION_ERROR,"Thứ tự câu hỏi không được trùng");
        // Retain old question rows; attempts store an immutable answer snapshot.
        questions.findByCourseIdAndIsActiveTrueOrderBySortOrderAscQuestionIdAsc(id).forEach(q->q.setIsActive(false));
        questions.flush();
        for(QuizQuestionRequest q:r.questions()){
            TrainingQuestion n=new TrainingQuestion();n.setCourseId(id);n.setQuestionText(q.questionText().trim());
            n.setOptionA(q.optionA().trim());n.setOptionB(q.optionB().trim());n.setOptionC(q.optionC().trim());
            n.setOptionD(q.optionD().trim());n.setCorrectOption(q.correctOption());n.setSortOrder(q.sortOrder());questions.save(n);
        }
        questions.flush();audit.log("TRAINING_QUESTIONS_UPDATE","TrainingCourse",id,null,Map.of("questionCount",r.questions().size()));
        return adminQuestions(id);
    }
    @Transactional
    public QuizAdminQuestionView saveQuestion(Integer courseId, Long questionId, QuizQuestionRequest r) {
        courses.findById(courseId).orElseThrow(()->BusinessException.notFound("khóa học"));
        if(questionId != null) {
            TrainingQuestion previous = questions.findById(questionId)
                .filter(q->q.getCourseId().equals(courseId) && Boolean.TRUE.equals(q.getIsActive()))
                .orElseThrow(()->BusinessException.notFound("câu hỏi"));
            previous.setIsActive(false);
        }
        boolean duplicate = questions.findByCourseIdAndIsActiveTrueOrderBySortOrderAscQuestionIdAsc(courseId).stream()
            .anyMatch(q->!Objects.equals(q.getQuestionId(),questionId) && Objects.equals(q.getSortOrder(),r.sortOrder()));
        if(duplicate) throw new BusinessException(ErrorCode.VALIDATION_ERROR,"Thứ tự câu hỏi đã được sử dụng");
        TrainingQuestion q=new TrainingQuestion(); q.setCourseId(courseId); q.setQuestionText(r.questionText().trim());
        q.setOptionA(r.optionA().trim()); q.setOptionB(r.optionB().trim()); q.setOptionC(r.optionC().trim()); q.setOptionD(r.optionD().trim());
        q.setCorrectOption(r.correctOption()); q.setSortOrder(r.sortOrder()); questions.saveAndFlush(q);
        audit.log(questionId == null ? "TRAINING_QUESTION_CREATE" : "TRAINING_QUESTION_UPDATE","TrainingCourse",courseId,null,Map.of("questionId",q.getQuestionId()));
        return adminView(q);
    }
    @Transactional
    public void deleteQuestion(Integer courseId, Long questionId) {
        TrainingQuestion q=questions.findById(questionId).filter(x->x.getCourseId().equals(courseId) && Boolean.TRUE.equals(x.getIsActive()))
            .orElseThrow(()->BusinessException.notFound("câu hỏi"));
        q.setIsActive(false);
        audit.log("TRAINING_QUESTION_DELETE","TrainingCourse",courseId,null,Map.of("questionId",questionId));
    }
    private QuizAdminQuestionView adminView(TrainingQuestion q){
        return new QuizAdminQuestionView(q.getQuestionId(),q.getQuestionText(),q.getOptionA(),q.getOptionB(),q.getOptionC(),
                q.getOptionD(),q.getCorrectOption(),q.getSortOrder());
    }
}
