package com.hrm.coffeeshop.common;

import java.time.OffsetDateTime;
import java.util.Map;

/** Envelope chuẩn theo SRS 8.2/8.3. */
public record ApiResponse<T>(boolean success, String message, T data, ErrorBody error, OffsetDateTime timestamp) {
    public record ErrorBody(String code, Map<String, Object> details) {}

    public static <T> ApiResponse<T> ok(String message, T data) {
        return new ApiResponse<>(true, message, data, null, TimeUtils.nowVn());
    }

    public static <T> ApiResponse<T> ok(T data) { return ok("OK", data); }

    public static ApiResponse<Object> error(String message, String code, Map<String, Object> details) {
        return new ApiResponse<>(false, message, null, new ErrorBody(code, details), TimeUtils.nowVn());
    }
}
