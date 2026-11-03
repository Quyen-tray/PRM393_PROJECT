package com.hrm.coffeeshop.it;

import com.hrm.coffeeshop.common.ErrorCode;
import com.hrm.coffeeshop.shared.dto.DocumentDto.SubmitRequest;
import com.hrm.coffeeshop.shared.service.DocumentService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.nio.charset.StandardCharsets;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

/** DEC-PDF / TC27: hồ sơ PDF đã upload được nộp; khóa không tồn tại bị từ chối. */
class DocumentSubmitIT extends IntegrationTestBase {

    @Autowired DocumentService documents;

    @Test
    void submitAcceptsUploadedPdfAndRejectsMissingFile() {
        long nv = employeeIdByCode("NV001");
        String code = "IT_SUBMIT_" + UUID.randomUUID().toString().replace("-", "").substring(0, 18);
        jdbc.update("INSERT INTO dbo.DocumentType (DocumentCode, DocumentName, IsActive) VALUES (?, ?, 1)",
                code, "Submit integration test");
        Integer typeId = jdbc.queryForObject(
                "SELECT DocumentTypeId FROM dbo.DocumentType WHERE DocumentCode = ?", Integer.class, code);

        String pdfKey = "private-documents/employee-" + nv + "/" + UUID.randomUUID() + ".pdf";
        storage.store(pdfKey, "%PDF-1.4\n%it\n".getBytes(StandardCharsets.US_ASCII));
        var accepted = documents.submit(nv, new SubmitRequest(typeId, pdfKey, null, null));
        assertNotNull(accepted);

        String missingKey = "private-documents/employee-" + nv + "/" + UUID.randomUUID() + ".pdf";
        assertRejected(() -> documents.submit(nv, new SubmitRequest(typeId, missingKey, null, null)),
                ErrorCode.VALIDATION_ERROR);
    }
}
