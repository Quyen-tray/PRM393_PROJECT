package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.common.BusinessException;
import com.hrm.coffeeshop.common.ErrorCode;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Kiểm tra quyền sở hữu khóa lưu trữ do SharedStorageController sinh:
 *   attendance-evidence/{employeeId}/{yyyyMMdd}/{uuid}.{jpg|png|webp}
 *   checklist-evidence/{employeeId}/{uuid}.{jpg|png|webp}
 * Chỉ chấp nhận khóa đúng định dạng VÀ thuộc về chính nhân viên đang thao tác.
 * Trước đây checklist chỉ kiểm tra tiền tố chung, nên một nhân viên có thể dùng ảnh của người khác.
 */
public final class EvidenceKeys {
    private static final Pattern ATTENDANCE_EVIDENCE =
            Pattern.compile("^attendance-evidence/(\\d{1,19})/\\d{8}/[0-9a-fA-F-]{36}\\.(jpg|png|webp)$");
    private static final Pattern CHECKLIST_EVIDENCE =
            Pattern.compile("^checklist-evidence/(\\d{1,19})/[0-9a-fA-F-]{36}\\.(jpg|png|webp)$");

    private EvidenceKeys() {}

    public static void requireOwnedAttendanceEvidence(String key, Long employeeId) {
        requireOwned(ATTENDANCE_EVIDENCE, key, employeeId);
    }

    public static void requireOwnedChecklistEvidence(String key, Long employeeId) {
        requireOwned(CHECKLIST_EVIDENCE, key, employeeId);
    }

    private static void requireOwned(Pattern pattern, String key, Long employeeId) {
        Matcher m = key == null ? null : pattern.matcher(key);
        if (m == null || !m.matches())
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "storageKey ảnh không hợp lệ");
        if (employeeId == null || !m.group(1).equals(String.valueOf(employeeId)))
            throw BusinessException.forbidden("Ảnh không thuộc về nhân viên hiện tại");
    }
}
