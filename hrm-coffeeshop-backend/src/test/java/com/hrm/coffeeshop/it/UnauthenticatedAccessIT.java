package com.hrm.coffeeshop.it;

import org.junit.jupiter.api.Test;
import com.hrm.coffeeshop.config.JwtService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.junit.jupiter.api.Assertions.assertNotEquals;


/** P1-03/P1-04 / TC32: endpoint yêu cầu đăng nhập trả 401 khi không có token (fail-closed). */
@AutoConfigureMockMvc
class UnauthenticatedAccessIT extends IntegrationTestBase {

    @Autowired MockMvc mvc;
    @Autowired JwtService jwt;

    @Test
    void requestWithoutTokenIsUnauthorized() throws Exception {
        mvc.perform(get("/api/v1/users/me")).andExpect(status().isUnauthorized());
    }

    @Test
    void publicStorageViewIsNotBlockedByAuthentication() throws Exception {
        // Không có chữ ký hợp lệ thì ứng dụng trả lỗi nghiệp vụ, nhưng KHÔNG phải 401 từ bộ lọc bảo mật.
        int code = mvc.perform(get("/api/v1/storage/view")).andReturn().getResponse().getStatus();
        assertNotEquals(401, code);
    }

    /** TC33: đã đăng nhập nhưng không đủ quyền gọi API quản trị thì trả 403. */
    @Test
    void authenticatedUserWithoutPermissionGetsForbidden() throws Exception {
        long user = createUser("it-noperm-403@hrm.test");
        String token = jwt.createAccessToken(user);
        mvc.perform(get("/api/v1/admin/users").header("Authorization", "Bearer " + token))
                .andExpect(status().isForbidden());
    }
}
