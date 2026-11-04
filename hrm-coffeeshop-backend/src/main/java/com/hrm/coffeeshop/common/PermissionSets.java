package com.hrm.coffeeshop.common;

import java.util.List;
import java.util.Map;

/**
 * Tập quyền dựng sẵn để Admin gán nhanh cho người dùng (SRS 1.2: HR là tập quyền, không phải actor/role thứ tư).
 * Gán xong được lưu thành từng quyền riêng lẻ trong dbo.UserPermission; đổi định nghĩa ở đây KHÔNG tự đổi
 * quyền của người đã được gán. Danh sách HR phải khớp dữ liệu quyền trong seeddata.sql.
 *
 * EVIDENCE_DOWNLOAD cố ý KHÔNG nằm trong HR: tải ảnh xác minh là quyền nhạy cảm, chỉ cấp riêng khi cần (SRS 2.1).
 */
public final class PermissionSets {
    private PermissionSets() {}

    public static final String HR = "HR";

    public static final Map<String, List<String>> ALL = Map.of(
            HR, List.of(
                    Permissions.DOCUMENT_REVIEW, Permissions.STAFF_REVIEW,
                    Permissions.EMPLOYEE_VIEW, Permissions.EMPLOYEE_MANAGE, Permissions.EMPLOYEE_PII_VIEW,
                    Permissions.ATTENDANCE_VIEW_ALL, Permissions.ATTENDANCE_ADJUST_HR,
                    Permissions.PAYROLL_VIEW, Permissions.PAYROLL_PERIOD_MANAGE, Permissions.PAYROLL_FINALIZE,
                    Permissions.DEVICE_APPROVE, Permissions.DASHBOARD_MANAGER, Permissions.CHECKLIST_VIEW,
                    Permissions.TRAINING_MANAGE, Permissions.VIOLATION_REVIEW,
                    Permissions.REWARD_VIEW, Permissions.REWARD_PROPOSE, Permissions.REWARD_APPROVE,
                    Permissions.EVIDENCE_VIEW));
}
