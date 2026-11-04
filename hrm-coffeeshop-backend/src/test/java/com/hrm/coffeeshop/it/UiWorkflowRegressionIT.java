package com.hrm.coffeeshop.it;

import com.fasterxml.jackson.databind.*;
import com.hrm.coffeeshop.common.*;
import com.hrm.coffeeshop.config.JwtService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;
import java.time.LocalDate;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;

@AutoConfigureMockMvc
class UiWorkflowRegressionIT extends IntegrationTestBase {
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper mapper;
    @Autowired JwtService jwt;
    String code(){return UUID.randomUUID().toString().substring(0,8);}
    long actor(String role){long id=createUser("ui-"+code()+"@hrm.test");jdbc.update("INSERT INTO dbo.UserRole(UserId,RoleId) SELECT ?,RoleId FROM dbo.Role WHERE RoleCode=?",id,role);return id;}
    JsonNode call(long actor,String method,String path,Object body,int status)throws Exception{
        var req=MockMvcRequestBuilders.request(org.springframework.http.HttpMethod.valueOf(method),"/api/v1"+path).header("Authorization","Bearer "+jwt.createAccessToken(actor));
        if(body!=null)req.contentType(MediaType.APPLICATION_JSON).content(mapper.writeValueAsBytes(body));
        var response=mvc.perform(req).andReturn().getResponse();
        var result=mapper.readTree(response.getContentAsString());
        assertEquals(status,response.getStatus(),method+" "+path+" "+result.path("message").asText());return result.path("data");
    }
    Map<String,Object> question(String title,int order){return Map.of("questionText",title,"optionA","A","optionB","B","optionC","C","optionD","D","correctOption","A","sortOrder",order);}
    @Test void questionCrudArchiveAndManualPassGuard()throws Exception{
        long admin=actor(Roles.SYSTEM_ADMIN),manager=actor(Roles.STORE_MANAGER),employee=userIdOfEmployee("NV001");
        long course=call(admin,"POST","/admin/training/courses",Map.of("courseCode","UI-"+code(),"courseName","UI regression","isMandatoryTest",true,"passScore",70,"isActive",true),201).path("courseId").asLong();
        String path="/admin/training/courses/"+course+"/questions";
        long first=call(admin,"POST",path,question("Câu 1",1),200).path("questionId").asLong();
        long second=call(admin,"PUT",path+"/"+first,question("Câu 1 đã sửa",1),200).path("questionId").asLong();
        assertNotEquals(first,second,"Editing invalidates stale quiz question identifiers");
        assertEquals(1,call(admin,"GET",path,null,200).size());
        call(employee,"DELETE",path+"/"+second,null,403);
        call(admin,"DELETE",path+"/"+second,null,200);assertEquals(0,call(admin,"GET",path,null,200).size());
        call(manager,"POST","/training/courses/"+course+"/attempts",Map.of("employeeId",employeeIdByCode("NV001"),"score",100,"note","manual bypass"),409);
        assertEquals(0,jdbc.queryForObject("SELECT COUNT(*) FROM dbo.EmployeeTraining WHERE EmployeeId=? AND CourseId=?",Integer.class,employeeIdByCode("NV001"),course));
        call(admin,"DELETE","/admin/training/courses/"+course,null,200);
        assertFalse(jdbc.queryForObject("SELECT IsActive FROM dbo.TrainingCourse WHERE CourseId=?",Boolean.class,course));
        call(admin,"DELETE","/admin/users/"+admin,null,422);
        call(employee,"DELETE","/admin/users/"+admin,null,403);
    }
    @Test void allChecklistFilterIncludesApprovedAndEvidenceIsReadableByReviewer()throws Exception{
        clock.setAt(vn(2038,6,10,10,0));long admin=actor(Roles.SYSTEM_ADMIN),manager=actor(Roles.STORE_MANAGER),employee=userIdOfEmployee("NV001"),employeeId=employeeIdByCode("NV001");
        long template=call(admin,"POST","/admin/checklist-templates",Map.of("checklistCode","UI-"+code(),"checklistName","Checklist UI","checklistType","SERVICE","managerApprovalRequired",true,"isActive",true,"items",List.of(Map.of("itemName","Ảnh minh chứng","isRequired",true,"requiresEvidence",true,"sortOrder",1))),201).path("templateId").asLong();
        var run=call(manager,"POST","/checklists/instances/generate",Map.of("templateId",template,"employeeId",employeeId,"workDate","2038-06-10"),201);
        long task=run.path("taskId").asLong(),item=run.path("items").get(0).path("runItemId").asLong();
        call(employee,"POST","/checklists/tasks/"+task+"/start",Map.of(),200);
        String key="checklist-evidence/"+employeeId+"/20380610/"+UUID.randomUUID()+".jpg";storage.store(key,new byte[]{(byte)255,(byte)216,(byte)255,0});
        call(employee,"POST","/checklists/tasks/"+task+"/items/"+item+"/complete",Map.of("evidenceStorageKey",key),200);
        var evidence=call(manager,"GET","/checklists/tasks/"+task+"/evidence",null,200);
        assertEquals(item,evidence.get(0).path("runItemId").asLong());assertTrue(evidence.get(0).path("evidenceViewUrl").asText().contains("sig="));
        call(employee,"POST","/checklists/tasks/"+task+"/submit",Map.of(),200);call(manager,"POST","/checklists/tasks/"+task+"/approve",Map.of(),200);
        var all=call(employee,"GET","/checklists/me?status=",null,200);
        boolean found=false;for(var row:all)if(row.path("taskId").asLong()==task)found=true;assertTrue(found,"All must include approved tasks");
        call(admin,"DELETE","/admin/checklist-templates/"+template,null,200);call(employee,"GET","/checklists/tasks/"+task,null,200);
    }
    @Test void accountSearchAndReminderArchiveWorkWithStringCodes()throws Exception{
        long admin=actor(Roles.SYSTEM_ADMIN),target=actor(Roles.EMPLOYEE);
        String email=jdbc.queryForObject("SELECT Email FROM dbo.AppUser WHERE UserId=?",String.class,target);
        assertEquals(1,call(admin,"GET","/admin/users?q="+email+"&role=EMPLOYEE&size=10&sort=userId,desc",null,200).path("totalElements").asInt());
        call(admin,"DELETE","/admin/users/"+target,null,200);assertEquals("INACTIVE",jdbc.queryForObject("SELECT UserStatus FROM dbo.AppUser WHERE UserId=?",String.class,target));
        call(admin,"DELETE","/admin/reminder-rules/SHIFT_REMINDER",null,200);
        assertFalse(jdbc.queryForObject("SELECT IsActive FROM dbo.ReminderRule WHERE RuleCode='SHIFT_REMINDER'",Boolean.class));
        call(admin,"PUT","/admin/reminder-rules/SHIFT_REMINDER",Map.of("leadMinutes",15,"isActive",true),200);
    }
}
