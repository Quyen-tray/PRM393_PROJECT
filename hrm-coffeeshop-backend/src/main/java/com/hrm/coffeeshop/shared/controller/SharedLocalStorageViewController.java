package com.hrm.coffeeshop.shared.controller;

import com.hrm.coffeeshop.shared.service.SignedUrlStorageGateway;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpHeaders;
import com.hrm.coffeeshop.shared.service.AuditService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Phục vụ file cho URL ký do SignedUrlStorageGateway phát ra. Chữ ký + hạn dùng là cơ chế xác thực
 * (Image.network không gửi được header Authorization), nên đường dẫn này được permitAll trong SecurityConfig.
 * Chỉ tồn tại khi dùng lưu trữ cục bộ; với S3/Azure/GCS ảnh được phát thẳng từ nhà cung cấp.
 */
@RestController
@ConditionalOnProperty(name = "app.storage.provider", havingValue = "local", matchIfMissing = true)
public class SharedLocalStorageViewController {
    private final SignedUrlStorageGateway storage;
    private final AuditService audit;

    public SharedLocalStorageViewController(SignedUrlStorageGateway storage, AuditService audit) {
        this.storage = storage;
        this.audit = audit;
    }

    @GetMapping("/storage/view")
    public ResponseEntity<byte[]> view(@RequestParam String key, @RequestParam long exp, @RequestParam String sig,
                                       @RequestParam(required = false) Long actor, HttpServletRequest request) {
        // B-21: mỗi lần truy cập file (kể cả bị từ chối) đều được ghi audit. Đây là lần xem thực tế, khác với lần cấp URL.
        String auditKey = key.substring(0, Math.min(key.length(), 100));   // AuditLog.EntityId tối đa 100 ký tự
        if (!storage.verify(key, exp, sig, actor)) {
            audit.log("STORAGE_VIEW_DENIED", "StoredFile", auditKey, null, java.util.Map.of("exp", exp));
            return ResponseEntity.status(403).build();
        }
        // Actor trong query chỉ đáng tin sau khi chữ ký HMAC (bao gồm actor) hợp lệ.
        if (actor != null) request.setAttribute(AuditService.SIGNED_URL_ACTOR_ATTRIBUTE, actor);
        // Chỉ ghi STORAGE_VIEW khi file thực sự đọc được; URL hợp lệ nhưng file đã mất là 404.
        java.util.Optional<byte[]> content = storage.read(key);
        if (content.isEmpty()) {
            audit.log("STORAGE_VIEW_NOT_FOUND", "StoredFile", auditKey, null,
                    java.util.Map.of("exp", exp));
            return ResponseEntity.notFound().build();
        }
        audit.log("STORAGE_VIEW", "StoredFile", auditKey, null, java.util.Map.of("exp", exp));
        return ResponseEntity.ok()
                .contentType(mediaType(key))
                .cacheControl(CacheControl.noStore())
                .header("X-Content-Type-Options", "nosniff")
                .header(HttpHeaders.CONTENT_DISPOSITION, "inline")
                .body(content.get());
    }

    private static MediaType mediaType(String key) {
        String k = key.toLowerCase();
        if (k.endsWith(".png")) return MediaType.IMAGE_PNG;
        if (k.endsWith(".webp")) return MediaType.parseMediaType("image/webp");
        if (k.endsWith(".pdf")) return MediaType.APPLICATION_PDF;
        return MediaType.IMAGE_JPEG;
    }
}
