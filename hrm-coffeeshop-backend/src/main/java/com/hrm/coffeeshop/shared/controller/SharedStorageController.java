package com.hrm.coffeeshop.shared.controller;

import com.hrm.coffeeshop.common.*;
import com.hrm.coffeeshop.shared.service.StorageGateway;
import com.hrm.coffeeshop.shared.service.UploadScanner;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.io.IOException;
import java.time.Clock;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/**
 * Upload ảnh/giấy tờ. Body là BYTES THÔ, không multipart.
 * Khóa lưu trữ do SERVER sinh, client không chọn được đường dẫn.
 *
 * DEC-PDF: hồ sơ HR (DOCUMENT) nhận PDF, JPEG, PNG, WebP, tối đa 10 MB/tệp.
 * ATTENDANCE và CHECKLIST chỉ nhận ảnh, tối đa 8 MB.
 *
 * B-19: với DOCUMENT, quyền DOCUMENT_REVIEW được tải tệp thay nhân viên (targetEmployeeId).
 * Không có targetEmployeeId thì tệp thuộc về nhân viên đang đăng nhập.
 */
@RestController
public class SharedStorageController {
    public record UploadView(String storageKey) {}

    private static final List<String> PURPOSES = List.of("ATTENDANCE", "CHECKLIST", "DOCUMENT");

    private final StorageGateway storage;
    private final UploadScanner scanner;
    private final Clock clock;
    private final long maxImageBytes;
    private final long maxDocumentBytes;

    public SharedStorageController(StorageGateway storage, UploadScanner scanner, Clock clock,
                                   @Value("${app.storage.max-upload-bytes:8388608}") long maxImageBytes,
                                   @Value("${app.storage.max-document-bytes:10485760}") long maxDocumentBytes) {
        this.storage = storage;
        this.scanner = scanner;
        this.clock = clock;
        this.maxImageBytes = maxImageBytes;
        this.maxDocumentBytes = maxDocumentBytes;
    }

    /** purpose: ATTENDANCE | CHECKLIST | DOCUMENT. */
    @PostMapping("/storage/uploads")
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<UploadView> upload(@RequestParam String purpose,
                                          @RequestParam(required = false) Long targetEmployeeId,
                                          HttpServletRequest req) throws IOException {
        String p = purpose == null ? "" : purpose.trim().toUpperCase();
        if (!PURPOSES.contains(p))
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "purpose phải là ATTENDANCE, CHECKLIST hoặc DOCUMENT");
        boolean document = "DOCUMENT".equals(p);
        if (targetEmployeeId != null && !document)
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "targetEmployeeId chỉ áp dụng cho hồ sơ DOCUMENT");

        Long empId;
        if (targetEmployeeId == null) {
            empId = SecurityUtils.requireEmployeeId();
        } else {
            if (!targetEmployeeId.equals(SecurityUtils.current().employeeId()))
                SecurityUtils.requirePermission(Permissions.DOCUMENT_REVIEW);
            empId = targetEmployeeId;
        }
        long limit = document ? maxDocumentBytes : maxImageBytes;

        if (req.getContentLengthLong() > limit) throw tooLarge(limit);
        byte[] data = req.getInputStream().readNBytes((int) limit + 1);
        if (data.length > limit) throw tooLarge(limit);

        // Nhận dạng theo nội dung, không theo Content-Type hay đuôi do client gửi.
        FileSignature sig = FileSignature.sniff(data).orElseThrow(() -> new BusinessException(ErrorCode.VALIDATION_ERROR,
                document ? "Hồ sơ chỉ nhận PDF, JPEG, PNG hoặc WebP" : "Chỉ nhận ảnh JPEG, PNG hoặc WebP"));
        if (sig == FileSignature.PDF && !document)
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Chỉ hồ sơ HR được tải lên PDF");
        if (!sig.matchesDeclared(req.getContentType()))
            throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Content-Type không khớp với nội dung tệp");
        scanner.scan(data, sig);

        String id = UUID.randomUUID() + "." + sig.ext();
        String key = switch (p) {
            case "ATTENDANCE" -> "attendance-evidence/" + empId + "/" + LocalDate.now(clock).toString().replace("-", "") + "/" + id;
            case "CHECKLIST" -> "checklist-evidence/" + empId + "/" + id;
            case "DOCUMENT" -> "private-documents/employee-" + empId + "/" + id;
            default -> throw new BusinessException(ErrorCode.VALIDATION_ERROR, "purpose không hợp lệ");
        };
        storage.store(key, data);
        return ApiResponse.ok("Uploaded", new UploadView(key));
    }

    private static BusinessException tooLarge(long limit) {
        return new BusinessException(ErrorCode.VALIDATION_ERROR, "Tệp quá lớn (tối đa " + (limit / 1024 / 1024) + " MB)");
    }
}
