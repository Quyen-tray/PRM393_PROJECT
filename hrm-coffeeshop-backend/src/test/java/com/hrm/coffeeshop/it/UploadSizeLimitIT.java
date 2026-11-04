package com.hrm.coffeeshop.it;

import com.hrm.coffeeshop.common.ErrorCode;
import com.hrm.coffeeshop.common.Roles;
import com.hrm.coffeeshop.shared.controller.SharedStorageController;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.mock.web.MockHttpServletRequest;

import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;

/** TC31: giới hạn upload được kiểm tra ở tầng HTTP/controller trước khi đọc và lưu file. */
class UploadSizeLimitIT extends IntegrationTestBase {
    @Autowired SharedStorageController uploads;

    @Test
    void rejectsAttendanceImageLargerThanEightMegabytes() {
        long employeeId = employeeIdByCode("NV001");
        loginAs(userIdOfEmployee("NV001"), employeeId, Set.of(Roles.EMPLOYEE));
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setContentType("image/jpeg");
        request.setContent(new byte[8 * 1024 * 1024 + 1]);

        var error = assertRejected(() -> uploads.upload("ATTENDANCE", null, request), ErrorCode.VALIDATION_ERROR);
        assertEquals("Tệp quá lớn (tối đa 8 MB)", error.getMessage());
    }
}
