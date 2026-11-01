package com.hrm.coffeeshop.common;

import java.util.Set;

/** Người dùng đã xác thực. {@code permissions} là quyền hiệu lực (quyền của role ∪ quyền gán trực tiếp), nạp từ DB mỗi request. */
public record AuthUser(Long userId, String email, Set<String> roles, Set<String> permissions, Long employeeId) {
    public boolean hasRole(String r) { return roles.contains(r); }
    public boolean hasAny(String... rs) {
        for (String r : rs) if (roles.contains(r)) return true;
        return false;
    }
    public boolean hasPermission(String p) { return permissions.contains(p); }
    public boolean hasAnyPermission(String... ps) {
        for (String p : ps) if (permissions.contains(p)) return true;
        return false;
    }
    /** Người được rà soát dữ liệu nhân viên của cửa hàng (Quản lý, hoặc người được gán tập quyền HR). */
    public boolean isStaffReviewer() { return hasPermission(Permissions.STAFF_REVIEW); }
}
