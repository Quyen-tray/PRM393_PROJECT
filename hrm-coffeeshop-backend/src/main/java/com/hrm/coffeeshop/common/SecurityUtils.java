package com.hrm.coffeeshop.common;

import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;

public final class SecurityUtils {
    private SecurityUtils() {}

    public static AuthUser current() {
        Authentication a = SecurityContextHolder.getContext().getAuthentication();
        if (a == null || !(a.getPrincipal() instanceof AuthUser u))
            throw new BusinessException(ErrorCode.UNAUTHENTICATED, "Chưa xác thực");
        return u;
    }

    public static AuthUser currentOrNull() {
        Authentication a = SecurityContextHolder.getContext().getAuthentication();
        return a != null && a.getPrincipal() instanceof AuthUser u ? u : null;
    }

    /** employeeId lấy từ token đã xác thực + DB, không bao giờ từ client. */
    public static Long requireEmployeeId() {
        AuthUser u = current();
        if (u.employeeId() == null)
            throw BusinessException.forbidden("Tài khoản chưa có hồ sơ nhân viên");
        return u.employeeId();
    }

    /** Yêu cầu người dùng có ÍT NHẤT MỘT trong các quyền (permission), không xét role. */
    public static void requirePermission(String... permissions) {
        if (!current().hasAnyPermission(permissions)) throw BusinessException.forbidden("Bạn không đủ quyền thực hiện thao tác này");
    }

    public static void requireAny(String... roles) {
        if (!current().hasAny(roles)) throw BusinessException.forbidden("Bạn không đủ quyền thực hiện thao tác này");
    }
}
