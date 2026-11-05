package com.hrm.coffeeshop.common;

import jakarta.validation.ConstraintViolationException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpMethod;
import org.springframework.orm.ObjectOptimisticLockingFailureException;
import org.springframework.data.mapping.PropertyReferenceException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.servlet.resource.NoResourceFoundException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

import java.util.LinkedHashMap;
import java.util.Map;

@RestControllerAdvice
public class GlobalExceptionHandler {
    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    private ResponseEntity<ApiResponse<Object>> build(HttpStatus st, ErrorCode code, String msg, Map<String, Object> d) {
        return ResponseEntity.status(st).body(ApiResponse.error(msg, code.name(), d));
    }

    @ExceptionHandler(BusinessException.class)
    public ResponseEntity<ApiResponse<Object>> business(BusinessException e) {
        return build(e.getCode().httpStatus(), e.getCode(), e.getMessage(), e.getDetails());
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiResponse<Object>> invalid(MethodArgumentNotValidException e) {
        Map<String, Object> fields = new LinkedHashMap<>();
        e.getBindingResult().getFieldErrors().forEach(f -> fields.put(f.getField(), f.getDefaultMessage()));
        return build(HttpStatus.BAD_REQUEST, ErrorCode.VALIDATION_ERROR, "Dữ liệu không hợp lệ", fields);
    }

    @ExceptionHandler(ConstraintViolationException.class)
    public ResponseEntity<ApiResponse<Object>> constraint(ConstraintViolationException e) {
        return build(HttpStatus.BAD_REQUEST, ErrorCode.VALIDATION_ERROR, e.getMessage(), null);
    }

    @ExceptionHandler({HttpMessageNotReadableException.class, MissingServletRequestParameterException.class,
            MethodArgumentTypeMismatchException.class})
    public ResponseEntity<ApiResponse<Object>> badRequest(Exception e) {
        return build(HttpStatus.BAD_REQUEST, ErrorCode.VALIDATION_ERROR, "Request sai định dạng", null);
    }

    @ExceptionHandler(PropertyReferenceException.class)
    public ResponseEntity<ApiResponse<Object>> badSort(PropertyReferenceException e) {
        return build(HttpStatus.BAD_REQUEST, ErrorCode.VALIDATION_ERROR, "Tham số sắp xếp không hợp lệ", null);
    }

    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<ApiResponse<Object>> denied(AccessDeniedException e) {
        return build(HttpStatus.FORBIDDEN, ErrorCode.PERMISSION_DENIED, "Bạn không đủ quyền truy cập", null);
    }

    @ExceptionHandler(AuthenticationException.class)
    public ResponseEntity<ApiResponse<Object>> unauth(AuthenticationException e) {
        return build(HttpStatus.UNAUTHORIZED, ErrorCode.UNAUTHENTICATED, "Chưa xác thực", null);
    }

    /** Hai người cùng xử lý một yêu cầu: người commit sau bị từ chối có kiểm soát thay vì 500. */
    @ExceptionHandler(ObjectOptimisticLockingFailureException.class)
    public ResponseEntity<ApiResponse<Object>> optimisticLock(ObjectOptimisticLockingFailureException e) {
        log.info("Optimistic lock conflict: {}", e.getMessage());
        return build(HttpStatus.CONFLICT, ErrorCode.CONFLICT,
                "Yêu cầu vừa được xử lý bởi người khác. Vui lòng tải lại và thử lại.", null);
    }

    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<ApiResponse<Object>> integrity(DataIntegrityViolationException e) {
        log.warn("Data integrity violation: {}", e.getMostSpecificCause().getMessage());
        return build(HttpStatus.CONFLICT, ErrorCode.CONFLICT, "Dữ liệu xung đột với trạng thái hiện tại, vui lòng thử lại", null);
    }

    /**
     * Không tìm thấy route/tài nguyên. Không để các lỗi định tuyến rơi xuống
     * catch-all Exception và bị trả nhầm thành HTTP 500.
     */
    @ExceptionHandler(NoResourceFoundException.class)
    public ResponseEntity<ApiResponse<Object>> noResource(NoResourceFoundException e) {
        log.debug("No resource/route found: {}", e.getResourcePath());
        return build(HttpStatus.NOT_FOUND, ErrorCode.NOT_FOUND,
                "Không tìm thấy endpoint hoặc tài nguyên được yêu cầu", null);
    }

    /** Đường dẫn tồn tại nhưng HTTP method không được controller hỗ trợ. */
    @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
    public ResponseEntity<ApiResponse<Object>> methodNotAllowed(HttpRequestMethodNotSupportedException e) {
        Map<String, Object> details = new LinkedHashMap<>();
        details.put("method", e.getMethod());
        if (e.getSupportedHttpMethods() != null) {
            details.put("supportedMethods", e.getSupportedHttpMethods().stream()
                    .map(HttpMethod::name)
                    .sorted()
                    .toList());
        }
        return build(HttpStatus.METHOD_NOT_ALLOWED, ErrorCode.METHOD_NOT_ALLOWED,
                "HTTP method không được hỗ trợ cho endpoint này", details);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiResponse<Object>> other(Exception e) {
        log.error("Unhandled error", e);
        return build(HttpStatus.INTERNAL_SERVER_ERROR, ErrorCode.INTERNAL_ERROR, "Lỗi hệ thống, vui lòng thử lại sau", null);
    }
}
