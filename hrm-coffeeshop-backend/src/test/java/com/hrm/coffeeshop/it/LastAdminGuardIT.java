package com.hrm.coffeeshop.it;

import com.hrm.coffeeshop.common.ErrorCode;
import com.hrm.coffeeshop.common.Roles;
import com.hrm.coffeeshop.shared.service.UserService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;

/** P1-12 / TC36: không khóa hoặc gỡ quyền System Admin đang hoạt động cuối cùng. Khôi phục trạng thái sau test. */
class LastAdminGuardIT extends IntegrationTestBase {

    @Autowired UserService users;

    private static final String SECOND_ADMIN = "it-guard-admin2@hrm.test";

    @Test
    void lastActiveSystemAdminCannotBeLockedOrStripped() {
        List<Long> adminIds = jdbc.queryForList(
                "SELECT u.UserId FROM dbo.AppUser u JOIN dbo.UserRole ur ON ur.UserId = u.UserId "
                        + "JOIN dbo.Role r ON r.RoleId = ur.RoleId WHERE r.RoleCode = 'SYSTEM_ADMIN'", Long.class);
        assertFalse(adminIds.isEmpty(), "Seed phải có ít nhất một System Admin");

        Map<Long, String> original = new LinkedHashMap<>();
        for (Long id : adminIds)
            original.put(id, jdbc.queryForObject("SELECT UserStatus FROM dbo.AppUser WHERE UserId = ?", String.class, id));

        long caller = createUser("it-guard-caller@hrm.test");   // người thao tác, không phải admin
        loginAs(caller, null, Set.of(Roles.SYSTEM_ADMIN));
        try {
            long keep = adminIds.get(0);
            for (Long id : adminIds)
                if (id != keep) jdbc.update("UPDATE dbo.AppUser SET UserStatus = 'INACTIVE' WHERE UserId = ?", id);
            jdbc.update("UPDATE dbo.AppUser SET UserStatus = 'ACTIVE' WHERE UserId = ?", keep);

            // Chỉ còn một admin đang hoạt động: không được khóa hoặc gỡ quyền.
            assertRejected(() -> users.setStatus(keep, "LOCKED"), ErrorCode.BUSINESS_RULE_VIOLATION);
            assertRejected(() -> users.setRoles(keep, List.of(Roles.EMPLOYEE)), ErrorCode.BUSINESS_RULE_VIOLATION);

            // Khi có admin thứ hai đang hoạt động, việc khóa admin đầu tiên được phép.
            long second = createUser(SECOND_ADMIN);
            jdbc.update("INSERT INTO dbo.UserRole (UserId, RoleId) VALUES (?, (SELECT RoleId FROM dbo.Role WHERE RoleCode = 'SYSTEM_ADMIN'))", second);
            assertDoesNotThrow(() -> users.setStatus(keep, "LOCKED"));
        } finally {
            for (Map.Entry<Long, String> en : original.entrySet())
                jdbc.update("UPDATE dbo.AppUser SET UserStatus = ? WHERE UserId = ?", en.getValue(), en.getKey());
            jdbc.update("DELETE FROM dbo.UserRole WHERE UserId = (SELECT UserId FROM dbo.AppUser WHERE Email = ?)", SECOND_ADMIN);
        }
    }
}
