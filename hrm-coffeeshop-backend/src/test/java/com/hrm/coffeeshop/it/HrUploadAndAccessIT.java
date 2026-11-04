package com.hrm.coffeeshop.it;

import com.hrm.coffeeshop.common.ApiResponse;
import com.hrm.coffeeshop.common.AuthUser;
import com.hrm.coffeeshop.common.ErrorCode;
import com.hrm.coffeeshop.common.Roles;
import com.hrm.coffeeshop.shared.controller.SharedStorageController;
import com.hrm.coffeeshop.shared.controller.SharedStorageController.UploadView;
import com.hrm.coffeeshop.shared.dto.DocumentDto.SubmitRequest;
import com.hrm.coffeeshop.shared.service.DocumentService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;

import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;

/** B-19 (TC28), TC29: HR tải hồ sơ thay nhân viên khi có DOCUMENT_REVIEW; nhân viên không được xem hồ sơ người khác. */
class HrUploadAndAccessIT extends IntegrationTestBase {

    @Autowired SharedStorageController uploads;
    @Autowired DocumentService documents;

    private static final byte[] PDF = "%PDF-1.4\n%it\n".getBytes(StandardCharsets.US_ASCII);

    private static MockHttpServletRequest pdfRequest() {
        MockHttpServletRequest req = new MockHttpServletRequest();
        req.setContentType("application/pdf");
        req.setContent(PDF);
        return req;
    }

    /** Tài khoản không có quyền nào (chỉ có employeeId): dùng để kiểm tra từ chối. */
    private static void loginWithoutPermissions(long userId, Long employeeId) {
        AuthUser u = new AuthUser(userId, "it-noperm-" + userId + "@hrm.test", Set.of(), Set.of(), employeeId);
        SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(u, null, List.of()));
    }

    private void clearPendingCommitment(long employeeId) {
        Integer typeId = jdbc.queryForObject(
                "SELECT DocumentTypeId FROM dbo.DocumentType WHERE DocumentCode = 'COMMITMENT'", Integer.class);
        jdbc.update("DELETE FROM dbo.EmployeeDocument WHERE EmployeeId = ? AND DocumentTypeId = ? AND ReviewStatus = 'PENDING'",
                employeeId, typeId);
    }

    @Test
    void hrUploadsPdfOnBehalfOfEmployee() throws Exception {
        long nv1 = employeeIdByCode("NV001");
        // Tài khoản quản lý có đủ quyền (ALL_PERMISSIONS, gồm DOCUMENT_REVIEW)
        loginAs(userIdByEmail("quanly@hrm.test"), null, Set.of(Roles.STORE_MANAGER));

        ApiResponse<UploadView> res = uploads.upload("DOCUMENT", nv1, pdfRequest());
        String key = res.data().storageKey();
        assertTrue(key.startsWith("private-documents/employee-" + nv1 + "/"), "Khóa phải thuộc nhân viên đích: " + key);
        assertTrue(key.endsWith(".pdf"));

        clearPendingCommitment(nv1);
        Integer typeId = jdbc.queryForObject(
                "SELECT DocumentTypeId FROM dbo.DocumentType WHERE DocumentCode = 'COMMITMENT'", Integer.class);
        assertNotNull(documents.submit(nv1, new SubmitRequest(typeId, key, null, null)));
    }

    @Test
    void employeeWithoutDocumentReviewCannotUploadForAnotherEmployee() {
        long nv1 = employeeIdByCode("NV001");
        loginWithoutPermissions(userIdOfEmployee("NV002"), employeeIdByCode("NV002"));
        assertRejected(() -> uploads.upload("DOCUMENT", nv1, pdfRequest()), ErrorCode.PERMISSION_DENIED);
    }

    @Test
    void employeeCannotViewAnotherEmployeesDocument() throws Exception {
        long nv1 = employeeIdByCode("NV001");
        long nv2 = employeeIdByCode("NV002");

        // NV001 tự tải và nộp hồ sơ của mình
        loginWithoutPermissions(userIdOfEmployee("NV001"), nv1);
        clearPendingCommitment(nv1);
        String key = uploads.upload("DOCUMENT", null, pdfRequest()).data().storageKey();
        Integer typeId = jdbc.queryForObject(
                "SELECT DocumentTypeId FROM dbo.DocumentType WHERE DocumentCode = 'COMMITMENT'", Integer.class);
        documents.submit(nv1, new SubmitRequest(typeId, key, null, null));
        Long docId = jdbc.queryForObject(
                "SELECT EmployeeDocumentId FROM dbo.EmployeeDocument WHERE StorageKey = ?", Long.class, key);

        // NV002 không có quyền xem hồ sơ của NV001 (TC29)
        loginWithoutPermissions(userIdOfEmployee("NV002"), nv2);
        assertRejected(() -> documents.get(docId), ErrorCode.PERMISSION_DENIED);
    }
}
