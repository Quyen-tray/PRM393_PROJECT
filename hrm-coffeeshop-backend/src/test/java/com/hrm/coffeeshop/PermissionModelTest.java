package com.hrm.coffeeshop;

import com.hrm.coffeeshop.common.AuthUser;
import com.hrm.coffeeshop.common.PermissionSets;
import com.hrm.coffeeshop.common.Permissions;
import com.hrm.coffeeshop.common.Roles;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class PermissionModelTest {
    private static AuthUser employeeWith(Set<String> perms) {
        return new AuthUser(1L, "a@b.c", Set.of(Roles.EMPLOYEE), perms, 10L);
    }

    @Test
    void hrSetGrantedToPlainEmployeeEnablesHrActionsWithoutHrRole() {
        List<String> hr = PermissionSets.ALL.get(PermissionSets.HR);
        AuthUser u = employeeWith(Set.copyOf(hr));
        assertTrue(u.hasPermission(Permissions.PAYROLL_FINALIZE));
        assertTrue(u.hasPermission(Permissions.ATTENDANCE_ADJUST_HR));
        assertTrue(u.isStaffReviewer());
        assertFalse(u.hasRole(Roles.STORE_MANAGER));
    }

    @Test
    void employeeWithoutGrantsHasNoHrActions() {
        AuthUser u = employeeWith(Set.of(Permissions.ATTENDANCE_SELF));
        assertFalse(u.hasPermission(Permissions.PAYROLL_FINALIZE));
        assertFalse(u.isStaffReviewer());
    }

    @Test
    void sensitiveEvidenceDownloadIsNotPartOfHrSet() {
        assertFalse(PermissionSets.ALL.get(PermissionSets.HR).contains(Permissions.EVIDENCE_DOWNLOAD));
        assertFalse(PermissionSets.ALL.get(PermissionSets.HR).contains(Permissions.PAYROLL_REOPEN));
    }
}
