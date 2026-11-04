package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.config.AppProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import jakarta.annotation.PostConstruct;
import org.springframework.stereotype.Component;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.security.MessageDigest;
import java.time.Clock;
import java.time.Duration;
import java.util.HexFormat;
import java.util.Optional;

/**
 * Lưu file trên đĩa của máy chủ (thư mục app.storage.local-dir) và phát URL xem ký HMAC có hạn.
 * Đủ cho một cửa hàng / một instance. Nhiều instance hoặc cần bền vững hơn: viết bean StorageGateway
 * cho S3/Azure/GCS (pre-signed URL của nhà cung cấp) và đặt app.storage.provider=s3 (bean này sẽ tắt).
 */
@Component
@ConditionalOnProperty(name = "app.storage.provider", havingValue = "local", matchIfMissing = true)
public class SignedUrlStorageGateway implements StorageGateway {
    private static final Logger log = LoggerFactory.getLogger(SignedUrlStorageGateway.class);
    /** Prefix đã có /api/v1 vì mọi controller nằm dưới /api/v1 (xem SecurityConfig). */
    public static final String VIEW_PATH = "/api/v1/storage/view";

    private final AppProperties props;
    private final Clock clock;
    private final Path root;

    public SignedUrlStorageGateway(AppProperties props, Clock clock,
                                   @Value("${app.storage.local-dir:./data/storage}") String localDir) {
        this.props = props;
        this.clock = clock;
        this.root = Path.of(localDir).toAbsolutePath().normalize();
    }

    /** Fail-fast: không khởi động nếu secret ký URL thiếu, quá ngắn hoặc là giá trị mẫu. */
    @PostConstruct
    void checkSigningSecret() {
        String s = props.storage().signingSecret();
        if (s == null || s.getBytes(StandardCharsets.UTF_8).length < 32)
            throw new IllegalStateException("app.storage.signing-secret (env STORAGE_SIGNING_SECRET) phải có tối thiểu 32 ký tự");
        if (s.startsWith("change-me"))
            throw new IllegalStateException("app.storage.signing-secret đang dùng giá trị mẫu; hãy đặt STORAGE_SIGNING_SECRET ngẫu nhiên");
    }

    @Override
    public String createViewUrl(String storageKey, Duration ttl) {
        return createViewUrl(storageKey, ttl, null);
    }

    @Override
    public String createViewUrl(String storageKey, Duration ttl, Long actorUserId) {
        long exp = clock.instant().plus(ttl).getEpochSecond();
        String enc = URLEncoder.encode(storageKey, StandardCharsets.UTF_8);
        String payload = signingPayload(storageKey, exp, actorUserId);
        String actor = actorUserId == null ? "" : "&actor=" + actorUserId;
        return VIEW_PATH + "?key=" + enc + "&exp=" + exp + actor + "&sig=" + sign(payload);
    }

    @Override
    public void store(String storageKey, byte[] content) {
        Path target = resolve(storageKey);
        try {
            Files.createDirectories(target.getParent());
            Files.write(target, content, StandardOpenOption.CREATE_NEW, StandardOpenOption.WRITE);
        } catch (IOException e) {
            throw new UncheckedIOException("Không ghi được file lưu trữ", e);
        }
    }

    @Override
    public boolean exists(String storageKey) {
        try {
            return Files.isRegularFile(resolve(storageKey));
        } catch (IllegalArgumentException e) {
            return false;
        }
    }

    @Override
    public void delete(String storageKey) {
        try {
            Files.deleteIfExists(resolve(storageKey));
        } catch (IOException | IllegalArgumentException e) {
            log.warn("Không xóa được file lưu trữ: {}", e.getMessage());
        }
    }

    /** Chữ ký hợp lệ và chưa hết hạn (so sánh thời gian không rò rỉ). */
    public boolean verify(String storageKey, long exp, String sig) {
        return verify(storageKey, exp, sig, null);
    }

    /** Actor là claim không tin cậy cho đến khi chữ ký HMAC được xác minh. */
    public boolean verify(String storageKey, long exp, String sig, Long actorUserId) {
        if (sig == null || clock.instant().getEpochSecond() > exp) return false;
        return MessageDigest.isEqual(sign(signingPayload(storageKey, exp, actorUserId)).getBytes(StandardCharsets.UTF_8),
                sig.getBytes(StandardCharsets.UTF_8));
    }

    private static String signingPayload(String storageKey, long exp, Long actorUserId) {
        return actorUserId == null ? storageKey + "|" + exp : storageKey + "|" + exp + "|" + actorUserId;
    }

    public Optional<byte[]> read(String storageKey) {
        try {
            Path p = resolve(storageKey);
            return Files.isRegularFile(p) ? Optional.of(Files.readAllBytes(p)) : Optional.empty();
        } catch (IOException | IllegalArgumentException e) {
            return Optional.empty();
        }
    }

    /** Chặn path traversal: đường dẫn sau chuẩn hóa phải nằm trong thư mục gốc. */
    private Path resolve(String storageKey) {
        if (storageKey == null || storageKey.isBlank() || storageKey.contains("..") || storageKey.startsWith("/"))
            throw new IllegalArgumentException("storageKey không hợp lệ");
        Path p = root.resolve(storageKey).normalize();
        if (!p.startsWith(root)) throw new IllegalArgumentException("storageKey không hợp lệ");
        return p;
    }

    private String sign(String data) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(props.storage().signingSecret().getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            return HexFormat.of().formatHex(mac.doFinal(data.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }
}
