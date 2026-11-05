package com.hrm.coffeeshop.common;

import java.util.LinkedHashMap;
import java.util.Map;

public class BusinessException extends RuntimeException {
    private final ErrorCode code;
    private final Map<String, Object> details;

    public BusinessException(ErrorCode code, String message) { this(code, message, null); }

    public BusinessException(ErrorCode code, String message, Map<String, Object> details) {
        super(message);
        this.code = code;
        this.details = details;
    }

    public ErrorCode getCode() { return code; }
    public Map<String, Object> getDetails() { return details; }

    public static BusinessException notFound(String what) {
        return new BusinessException(ErrorCode.NOT_FOUND, "Không tìm thấy " + what);
    }

    public static BusinessException forbidden(String msg) {
        return new BusinessException(ErrorCode.PERMISSION_DENIED, msg);
    }

    public static BusinessException invalidState(String msg) {
        return new BusinessException(ErrorCode.INVALID_STATE, msg);
    }

    public static BusinessException rule(String msg) {
        return new BusinessException(ErrorCode.BUSINESS_RULE_VIOLATION, msg);
    }

    public static Map<String, Object> details(Object... kv) {
        Map<String, Object> m = new LinkedHashMap<>();
        for (int i = 0; i + 1 < kv.length; i += 2) m.put(String.valueOf(kv[i]), kv[i + 1]);
        return m;
    }
}
