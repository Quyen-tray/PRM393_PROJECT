package com.hrm.coffeeshop.it;

import com.hrm.coffeeshop.common.ErrorCode;
import com.hrm.coffeeshop.common.Roles;
import com.hrm.coffeeshop.shared.dto.DocumentDto.SubmitRequest;
import com.hrm.coffeeshop.shared.service.DocumentService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.nio.charset.StandardCharsets;
import java.util.Set;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

/** DEC-PDF / TC27: hồ sơ PDF đã upload được nộp; khóa không tồn tại bị từ chối. */
class DocumentSubmitIT extends IntegrationTestBase {

    @Autowired DocumentService documents;

    @Test
    void submitAcceptsUploadedPdfAndRejectsMissingFile() {
        long nv = employeeIdByCode("NV001");
        loginAs(userIdOfEmployee("NV001"), nv, Set.of(Roles.EMPLOYEE));
        Integer typeId = jdbc.queryForObject(
                "SELECT DocumentTypeId FROM dbo.DocumentType WHERE DocumentCode = 'COMMITMENT'", Integer.class);
        // Tránh xung đột với hồ sơ đang chờ duyệt có sẵn trong seed.
        jdbc.update("DELETE FROM dbo.EmployeeDocument WHERE EmployeeId = ? AND DocumentTypeId = ? AND ReviewStatus = 'PENDING'",
                nv, typeId);

        String pdfKey = "private-documents/employee-" + nv + "/" + UUID.randomUUID() + ".pdf";
        storage.store(pdfKey, "%PDF-1.4\n%it\n".getBytes(StandardCharsets.US_ASCII));
        var accepted = documents.submit(nv, new SubmitRequest(typeId, pdfKey, null, null));
        assertNotNull(accepted);

        String missingKey = "private-documents/employee-" + nv + "/" + UUID.randomUUID() + ".pdf";
        assertRejected(() -> documents.submit(nv, new SubmitRequest(typeId, missingKey, null, null)),
                ErrorCode.VALIDATION_ERROR);
    }
}
