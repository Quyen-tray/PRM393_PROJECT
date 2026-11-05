package com.hrm.coffeeshop.common;

/**
 * Mã quyền (khớp bảng dbo.Permission trong config.sql).
 * Endpoint dùng {@code @PreAuthorize("hasAuthority('...')")}; service dùng {@link SecurityUtils#requirePermission}.
 */
public final class Permissions {
    private Permissions() {}

    // Nhân viên
    public static final String SCHEDULE_VIEW_SELF = "SCHEDULE_VIEW_SELF";
    public static final String ATTENDANCE_SELF = "ATTENDANCE_SELF";
    public static final String DEVICE_REGISTER = "DEVICE_REGISTER";
    public static final String DOCUMENT_SUBMIT_SELF = "DOCUMENT_SUBMIT_SELF";
    public static final String TRAINING_SELF = "TRAINING_SELF";
    public static final String CHECKLIST_EXECUTE = "CHECKLIST_EXECUTE";
    public static final String EXPLANATION_SUBMIT = "EXPLANATION_SUBMIT";

    // Vận hành cửa hàng
    public static final String SCHEDULE_MANAGE = "SCHEDULE_MANAGE";
    public static final String ATTENDANCE_REVIEW = "ATTENDANCE_REVIEW";
    public static final String ATTENDANCE_VIEW_ALL = "ATTENDANCE_VIEW_ALL";
    public static final String ATTENDANCE_ADJUST_HR = "ATTENDANCE_ADJUST_HR";
    public static final String DEVICE_APPROVE = "DEVICE_APPROVE";
    public static final String CHECKLIST_REVIEW = "CHECKLIST_REVIEW";
    public static final String CHECKLIST_VIEW = "CHECKLIST_VIEW";
    public static final String DASHBOARD_MANAGER = "DASHBOARD_MANAGER";
    public static final String STAFF_REVIEW = "STAFF_REVIEW";

    // Nhân sự
    public static final String EMPLOYEE_VIEW = "EMPLOYEE_VIEW";
    public static final String EMPLOYEE_MANAGE = "EMPLOYEE_MANAGE";
    public static final String EMPLOYEE_PII_VIEW = "EMPLOYEE_PII_VIEW";
    public static final String DOCUMENT_REVIEW = "DOCUMENT_REVIEW";
    public static final String TRAINING_MANAGE = "TRAINING_MANAGE";
    public static final String VIOLATION_REVIEW = "VIOLATION_REVIEW";
    public static final String REWARD_VIEW = "REWARD_VIEW";
    public static final String REWARD_PROPOSE = "REWARD_PROPOSE";
    public static final String REWARD_APPROVE = "REWARD_APPROVE";
    public static final String REWARD_APPROVE_CRITICAL = "REWARD_APPROVE_CRITICAL";

    // Dữ liệu nhạy cảm (nên cấp riêng, luôn audit)
    public static final String EVIDENCE_VIEW = "EVIDENCE_VIEW";
    public static final String EVIDENCE_DOWNLOAD = "EVIDENCE_DOWNLOAD";

    // Kỳ công
    public static final String PAYROLL_VIEW = "PAYROLL_VIEW";
    public static final String PAYROLL_PERIOD_MANAGE = "PAYROLL_PERIOD_MANAGE";
    public static final String PAYROLL_MANAGER_CONFIRM = "PAYROLL_MANAGER_CONFIRM";
    public static final String PAYROLL_FINALIZE = "PAYROLL_FINALIZE";
    public static final String PAYROLL_REOPEN = "PAYROLL_REOPEN";

    // Quản trị
    public static final String CONFIG_MANAGE = "CONFIG_MANAGE";
    public static final String USER_MANAGE = "USER_MANAGE";
    public static final String AUDIT_VIEW = "AUDIT_VIEW";
    public static final String TEMPLATE_MANAGE = "TEMPLATE_MANAGE";
}
