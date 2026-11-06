package com.hrm.coffeeshop.it;

import com.fasterxml.jackson.databind.*;
import com.hrm.coffeeshop.common.*;
import com.hrm.coffeeshop.config.JwtService;
import com.hrm.coffeeshop.domain.RefreshToken;
import com.hrm.coffeeshop.repository.RefreshTokenRepository;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.*;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;
import java.nio.file.*;
import java.time.*;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;

/** Real controllers, JWT authorization, services and local SQL Server. No mocked application beans. */
@AutoConfigureMockMvc
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
class V3WorkflowIT extends IntegrationTestBase {
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper mapper;
    @Autowired JwtService jwt;
    @Autowired RefreshTokenRepository refreshTokens;
    record Actor(long userId, Long employeeId, String token) {}
    String code() { return UUID.randomUUID().toString().substring(0,8); }
    Actor actor(String role, String... permissions) {
        long id=createUser("v3-"+code()+"@hrm.test");
        jdbc.update("INSERT INTO dbo.UserRole(UserId,RoleId) SELECT ?,RoleId FROM dbo.Role WHERE RoleCode=?",id,role);
        for (String permission:permissions) jdbc.update("INSERT INTO dbo.UserPermission(UserId,PermissionId) SELECT ?,PermissionId FROM dbo.Permission WHERE PermissionCode=?",id,permission);
        return new Actor(id,null,jwt.createAccessToken(id));
    }
    Actor employeeActor() {
        long id=userIdOfEmployee("NV001");return new Actor(id,employeeIdByCode("NV001"),jwt.createAccessToken(id));
    }
    JsonNode call(Actor actor,String method,String path,Object body,int status,String credential) throws Exception {
        var request=MockMvcRequestBuilders.request(org.springframework.http.HttpMethod.valueOf(method),"/api/v1"+path)
                .header("Authorization","Bearer "+jwt.createAccessToken(actor.userId()));
        if(credential!=null)request.header("X-Device-Credential",credential);
        if(body!=null)request.contentType(MediaType.APPLICATION_JSON).content(mapper.writeValueAsBytes(body));
        MvcResult result=mvc.perform(request).andReturn();
        JsonNode envelope=mapper.readTree(result.getResponse().getContentAsString());
        assertEquals(status,result.getResponse().getStatus(),method+" "+path+" "+envelope.path("message").asText());
        return envelope.path("data");
    }
    JsonNode call(Actor actor,String method,String path,Object body,int status) throws Exception { return call(actor,method,path,body,status,null); }
    long assign(Actor manager,long employeeId,String date,int shiftId) throws Exception {
        return call(manager,"POST","/shift-assignments",Map.of("employeeId",employeeId,"workShiftId",shiftId,"workDate",date),201).path("assignmentId").asLong();
    }
    long course(Actor admin,boolean quiz) throws Exception {
        return call(admin,"POST","/admin/training/courses",Map.of("courseCode","V3-"+code(),"courseName","Khóa kiểm thử V3","description","Nội dung hướng dẫn","passScore",70,"validityMonths",12,"isMandatoryTest",quiz,"isActive",true),201).path("courseId").asLong();
    }
    @Test @Order(1)
    void deviceBindingAndOvernightAttendanceAreEnforcedThroughHttp() throws Exception {
        clock.setAt(vn(2037,2,10,22,5));Actor manager=actor(Roles.STORE_MANAGER);Actor employee=employeeActor();
        String credential="v3-installation-"+UUID.randomUUID();
        var registration=call(employee,"POST","/attendance/devices/register",Map.of("deviceFingerprint",credential,"platform","ANDROID","deviceLabel","Máy kiểm thử"),201);
        long device=registration.path("deviceId").asLong();assertEquals("PENDING",registration.path("status").asText());
        assertEquals(device,call(employee,"POST","/attendance/devices/register",Map.of("deviceFingerprint",credential,"platform","ANDROID","deviceLabel","Máy kiểm thử"),201).path("deviceId").asLong());
        call(employee,"POST","/attendance/devices/"+device+"/approve",Map.of(),403);
        call(manager,"POST","/attendance/devices/"+device+"/approve",Map.of(),200);
        Actor deviceReviewer=actor(Roles.EMPLOYEE,Permissions.DEVICE_APPROVE);
        JsonNode activeDevices=call(deviceReviewer,"GET","/attendance/devices?status=ACTIVE&employeeId="+employee.employeeId()+"&q=kiểm",null,200);
        assertEquals(1,activeDevices.path("totalElements").asInt());
        assertEquals(device,activeDevices.path("items").get(0).path("deviceId").asLong());
        assertFalse(activeDevices.path("items").get(0).has("deviceFingerprint"));
        call(employee,"GET","/attendance/devices",null,403);
        call(deviceReviewer,"GET","/attendance/devices?status=UNKNOWN",null,400);
        assertEquals(device,call(employee,"GET","/attendance/devices/current",null,200,credential).path("deviceId").asLong());
        long shift=call(manager,"POST","/work-shifts",Map.of("shiftCode","N-"+code(),"shiftName","Ca qua đêm","startTime","22:00","endTime","06:00","breakMinutes",0,"earlyCheckInMinutes",15,"graceMinutes",5,"isActive",true),201).path("shiftId").asLong();
        long assignment=assign(manager,employee.employeeId(),"2037-02-10",(int)shift);
        JsonNode current=call(employee,"GET","/attendance/me/current",null,200,credential);
        assertEquals(assignment,current.path("shiftAssignmentId").asLong());assertTrue(current.path("canCheckIn").asBoolean());
        assertEquals("2037-02-11T06:00:00+07:00",current.path("plannedEndAt").asText());
        var body=new LinkedHashMap<String,Object>();body.put("shiftAssignmentId",assignment);body.put("deviceId",device);
        body.put("location",onSite());body.put("photoEvidence",uploadPhoto(employee.employeeId(),LocalDate.of(2037,2,10)));body.put("idempotencyKey","in-"+code());
        call(employee,"POST","/attendance/check-in",body,422,"different-installation");
        JsonNode first=call(employee,"POST","/attendance/check-in",body,200,credential);
        long attendance=first.path("attendanceId").asLong();
        assertEquals(attendance,call(employee,"POST","/attendance/check-in",body,200,credential).path("attendanceId").asLong());
        clock.setAt(vn(2037,2,11,2,0));assertTrue(call(employee,"GET","/attendance/me/current",null,200,credential).path("canCheckOut").asBoolean());
        clock.setAt(vn(2037,2,11,6,0));body.remove("shiftAssignmentId");body.put("attendanceId",attendance);body.put("location",onSite());body.put("idempotencyKey","out-"+code());
        body.put("photoEvidence",uploadPhoto(employee.employeeId(),LocalDate.of(2037,2,11)));
        call(employee,"POST","/attendance/check-out",body,200,credential);assertEquals(1,countAttendanceOfShift(assignment));
    }
    @Test @Order(2)
    void quizIsServerGradedAndPreservesAttemptSnapshots() throws Exception {
        clock.setAt(vn(2037,3,1,10,0));Actor admin=actor(Roles.SYSTEM_ADMIN);Actor employee=employeeActor();long course=course(admin,true);
        var question=Map.of("questionText","Rửa tay khi nào?","optionA","Trước khi pha chế","optionB","Không cần","optionC","Chỉ cuối ca","optionD","Một lần mỗi tuần","correctOption","A","sortOrder",1);
        call(admin,"PUT","/admin/training/courses/"+course+"/questions",Map.of("questions",List.of(question)),200);
        call(employee,"POST","/training/courses/"+course+"/enroll",Map.of(),201);
        JsonNode quiz=call(employee,"GET","/training/courses/"+course+"/quiz",null,200);assertFalse(quiz.toString().contains("correctOption"));
        long questionId=quiz.get(0).path("questionId").asLong();
        JsonNode failed=call(employee,"POST","/training/courses/"+course+"/quiz-attempts",Map.of("answers",List.of(Map.of("questionId",questionId,"selectedOption","B"))),201);
        assertFalse(failed.path("passed").asBoolean());assertEquals(0,failed.path("score").asInt());
        JsonNode passed=call(employee,"POST","/training/courses/"+course+"/quiz-attempts",Map.of("answers",List.of(Map.of("questionId",questionId,"selectedOption","A"))),201);
        assertTrue(passed.path("passed").asBoolean());assertEquals(100,passed.path("score").asInt());
        call(employee,"POST","/training/courses/"+course+"/quiz-attempts",Map.of("answers",List.of(Map.of("questionId",questionId,"selectedOption","A"))),409);
        assertEquals(2,call(employee,"GET","/training/courses/"+course+"/attempts/me",null,200).size());
        String snapshot=jdbc.queryForObject("SELECT AnswersJson FROM dbo.TrainingAttempt WHERE AttemptId=?",String.class,passed.path("attemptId").asLong());assertTrue(snapshot.contains("Rửa tay"));
    }
    @Test @Order(3)
    void completionAndDocumentReviewsUseActualPermissions() throws Exception {
        clock.setAt(vn(2037,3,2,10,0));Actor admin=actor(Roles.SYSTEM_ADMIN);Actor employee=employeeActor();Actor reviewer=actor(Roles.EMPLOYEE,Permissions.TRAINING_MANAGE,Permissions.DOCUMENT_REVIEW);
        long course=course(admin,false);long enrollment=call(employee,"POST","/training/courses/"+course+"/enroll",Map.of(),201).path("employeeTrainingId").asLong();
        call(employee,"POST","/training/completion-reviews/"+enrollment+"/approve",Map.of(),403);
        call(reviewer,"POST","/training/completion-reviews/"+enrollment+"/not-complete",Map.of("reason","Cần thực hành thêm"),200);
        call(admin,"POST","/training/completion-reviews/"+enrollment+"/approve",Map.of("note","Đã xác nhận thực hành"),200);
        assertEquals("PASSED",call(employee,"GET","/training/enrollments/"+enrollment,null,200).path("status").asText());
        long type=call(admin,"POST","/admin/document-types",Map.of("documentCode","D-"+code(),"documentName","Giấy tờ kiểm thử","isActive",true),201).path("documentTypeId").asLong();
        String key="private-documents/employee-"+employee.employeeId()+"/"+code()+".pdf";storage.store(key,"%PDF-1.4\nTest".getBytes(java.nio.charset.StandardCharsets.UTF_8));
        long document=call(employee,"POST","/employees/me/documents",Map.of("documentTypeId",type,"storageKey",key),201).path("documentId").asLong();
        assertTrue(call(employee,"GET","/employees/me/documents/catalog",null,200).toString().contains("PENDING"));
        call(reviewer,"GET","/documents/"+document,null,200);call(reviewer,"POST","/documents/"+document+"/approve",Map.of(),200);
        assertEquals("APPROVED",call(employee,"GET","/documents/"+document,null,200).path("reviewStatus").asText());
    }
    @Test @Order(4)
    void violationExplanationDoesNotRequireFinancialApprovalPermission() throws Exception {
        clock.setAt(vn(2037,3,3,10,0));Actor employee=employeeActor();Actor reviewer=actor(Roles.EMPLOYEE,Permissions.VIOLATION_REVIEW);
        call(employee,"GET","/rewards-penalties/me?page=0&size=20",null,200);
        call(reviewer,"GET","/violations?status=OPEN&page=0&size=20",null,200);
        jdbc.update("INSERT INTO dbo.ViolationEvent(EmployeeId,RuleId,Details,RecordStatus) SELECT ?,RuleId,N'Đi muộn kiểm thử','PENDING' FROM dbo.RuleCatalog WHERE RuleCode='LATE_MINOR'",employee.employeeId());
        long id=jdbc.queryForObject("SELECT MAX(ViolationEventId) FROM dbo.ViolationEvent WHERE EmployeeId=?",Long.class,employee.employeeId());
        call(employee,"POST","/violations/"+id+"/explanations",Map.of("reason","Sự cố giao thông, đề nghị xem xét"),201);
        assertEquals(1,call(reviewer,"GET","/violations/"+id+"/explanations",null,200).size());
        call(reviewer,"POST","/violations/"+id+"/dismiss",Map.of("reason","Đã xem xét giải trình"),200);
        call(employee,"POST","/violations/"+id+"/explanations",Map.of("reason","Nội dung bổ sung sau khi đã quyết định"),409);
    }
    @Test @Order(5)
    void hrAdjustmentPermissionCanReadAndCompleteItsOwnReviewStage() throws Exception {
        clock.setAt(vn(2037,3,4,10,0));Actor manager=actor(Roles.STORE_MANAGER);Actor employee=employeeActor();Actor hr=actor(Roles.EMPLOYEE,Permissions.ATTENDANCE_ADJUST_HR);
        long assignment=assign(manager,employee.employeeId(),"2037-03-04",workShiftId("CA_SANG"));
        jdbc.update("INSERT INTO dbo.Attendance(ShiftAssignmentId,EmployeeId,CheckInAt,CheckOutAt,AttendanceStatus) VALUES (?,?,'2037-03-04T00:00:00','2037-03-04T02:00:00','PRESENT')",assignment,employee.employeeId());
        long attendance=attendanceIdOfShift(assignment);
        long request=call(employee,"POST","/attendance/adjustment-requests",Map.of("attendanceId",attendance,"reasonCode","OTHER","reason","Sửa giờ vào bị ghi sai","requestedCheckInAt","2037-03-04T08:00:00+07:00"),201).get(0).path("requestId").asLong();
        call(hr,"POST","/attendance/adjustment-requests/"+request+"/hr-approve",Map.of(),409);
        call(manager,"POST","/attendance/adjustment-requests/"+request+"/manager-approve",Map.of("note","Đã đối chiếu"),200);
        call(hr,"GET","/attendance/adjustment-requests?status=PENDING_HR",null,200);
        var requestDetail=call(hr,"GET","/attendance/adjustment-requests/"+request,null,200);
        assertEquals(employee.employeeId().longValue(),requestDetail.path("employeeId").asLong());
        assertEquals("2037-03-04",requestDetail.path("workDate").asText());
        assertFalse(requestDetail.path("employeeName").asText().isBlank());
        call(hr,"GET","/attendance/"+attendance,null,200);
        call(hr,"POST","/attendance/adjustment-requests/"+request+"/hr-approve",Map.of("note","Chấp thuận"),200);
        assertEquals("APPROVED",call(employee,"GET","/attendance/adjustment-requests/"+request,null,200).path("status").asText());
        assertEquals(60,jdbc.queryForObject("SELECT WorkedMinutes FROM dbo.Attendance WHERE AttendanceId=?",Integer.class,attendance));
    }
    @Test @Order(6)
    void employeeAdministrationCatalogsDoNotRequireSystemAdminRole() throws Exception {
        clock.setAt(vn(2037,3,5,10,0));Actor administrator=actor(Roles.EMPLOYEE,Permissions.EMPLOYEE_MANAGE);Actor reviewer=actor(Roles.EMPLOYEE,Permissions.DOCUMENT_REVIEW);Actor employee=employeeActor();
        assertTrue(call(administrator,"GET","/job-positions",null,200).size()>0);
        call(administrator,"GET","/employees/linkable-users",null,200);
        call(employee,"GET","/employees/linkable-users",null,403);
        call(reviewer,"GET","/employees/"+employee.employeeId()+"/documents/catalog",null,200);
    }
    @Test @Order(7)
    void concurrentDeviceApprovalsHaveOneWinner() throws Exception {
        clock.setAt(vn(2037,3,6,10,0));Actor administrator=actor(Roles.SYSTEM_ADMIN,Permissions.EMPLOYEE_MANAGE);Actor employee=actor(Roles.EMPLOYEE);Actor first=actor(Roles.STORE_MANAGER);Actor second=actor(Roles.STORE_MANAGER);
        long position=jdbc.queryForObject("SELECT TOP 1 PositionId FROM dbo.JobPosition WHERE IsActive=1",Long.class);
        call(administrator,"POST","/employees",Map.of("userId",employee.userId(),"employeeCode","DEV-"+code(),"positionId",position,"employmentType","FULL_TIME","hireDate","2037-03-01"),201);
        long device=call(employee,"POST","/attendance/devices/register",Map.of("deviceFingerprint","race-"+code(),"platform","ANDROID","deviceLabel","Máy cạnh tranh"),201).path("deviceId").asLong();
        var pool=java.util.concurrent.Executors.newFixedThreadPool(2);var ready=new java.util.concurrent.CountDownLatch(2);var start=new java.util.concurrent.CountDownLatch(1);
        try {
            var tasks=List.of(first,second).stream().map(actor->pool.submit(()->{ready.countDown();start.await();return mvc.perform(MockMvcRequestBuilders.post("/api/v1/attendance/devices/"+device+"/approve").header("Authorization","Bearer "+jwt.createAccessToken(actor.userId()))).andReturn().getResponse().getStatus();})).toList();
            assertTrue(ready.await(10,java.util.concurrent.TimeUnit.SECONDS));start.countDown();var results=new ArrayList<Integer>();for(var task:tasks)results.add(task.get(20,java.util.concurrent.TimeUnit.SECONDS));
            assertEquals(1,results.stream().filter(status->status==200).count());assertEquals(1,results.stream().filter(status->status==409).count());
        } finally {pool.shutdownNow();}
    }
    @Test @Order(99)
    void exportDedicatedLiveAcceptanceSessions() throws Exception {
        clock.setAt(Instant.now());
        Actor manager=actor(Roles.STORE_MANAGER);Actor admin=actor(Roles.SYSTEM_ADMIN,Permissions.PAYROLL_VIEW,Permissions.PAYROLL_PERIOD_MANAGE,Permissions.PAYROLL_FINALIZE,Permissions.ATTENDANCE_ADJUST_HR,Permissions.DOCUMENT_REVIEW,Permissions.EMPLOYEE_VIEW,Permissions.EMPLOYEE_MANAGE);
        Actor employee=actor(Roles.EMPLOYEE);long position=jdbc.queryForObject("SELECT PositionId FROM dbo.JobPosition WHERE PositionCode='PHUC_VU'",Long.class);
        long employeeId=call(admin,"POST","/employees",Map.of("userId",employee.userId(),"employeeCode","V3-"+code(),"positionId",position,"employmentType","FULL_TIME","hireDate",LocalDate.now().toString()),201).path("employeeId").asLong();
        employee=new Actor(employee.userId(),employeeId,jwt.createAccessToken(employee.userId()));
        jdbc.update("UPDATE dbo.AppUser SET DisplayName=N'Nhân viên kiểm thử' WHERE UserId=?",employee.userId());
        jdbc.update("UPDATE dbo.AppUser SET DisplayName=N'Quản lý kiểm thử' WHERE UserId=?",manager.userId());
        jdbc.update("UPDATE dbo.AppUser SET DisplayName=N'Quản trị kiểm thử' WHERE UserId=?",admin.userId());
        long shift=call(manager,"POST","/work-shifts",Map.of("shiftCode","LIVE-"+code(),"shiftName","Ca kiểm thử giao diện","startTime","00:00","endTime","23:59","breakMinutes",0,"earlyCheckInMinutes",15,"graceMinutes",5,"isActive",true),201).path("shiftId").asLong();
        assign(manager,employeeId,TimeUtils.today(clock).toString(),(int)shift);
        Map<String,Object> sessions=new LinkedHashMap<>();sessions.put("employee",session(employee));sessions.put("manager",session(manager));sessions.put("admin",session(admin));sessions.put("database",TEST_DB);
        Path output=Path.of("../.dart_tool/v3-acceptance.json").toAbsolutePath().normalize();Files.createDirectories(output.getParent());mapper.writeValue(output.toFile(),sessions);
    }
    Map<String,Object> session(Actor actor) {
        String raw=UUID.randomUUID()+"-"+UUID.randomUUID();RefreshToken token=new RefreshToken();token.setUserId(actor.userId());token.setTokenHash(Hashing.sha256Hex(raw));token.setExpiresAt(Instant.now().plus(Duration.ofDays(1)));refreshTokens.saveAndFlush(token);
        return Map.of("accessToken",actor.token(),"refreshToken",raw,"userId",actor.userId(),"employeeId",actor.employeeId()==null?0:actor.employeeId());
    }
}
