package com.hrm.coffeeshop.shared.service;

import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdTokenVerifier;
import com.google.api.client.http.javanet.NetHttpTransport;
import com.google.api.client.json.gson.GsonFactory;
import com.hrm.coffeeshop.common.BusinessException;
import com.hrm.coffeeshop.common.ErrorCode;
import com.hrm.coffeeshop.config.AppProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.security.GeneralSecurityException;
import java.util.Arrays;
import java.util.List;

/**
 * Xác minh chữ ký, issuer, audience, expiry của Google ID token (SRS 3.1).
 * <p>
 * {@code GOOGLE_CLIENT_ID} có thể chứa nhiều Client ID, ngăn cách bằng dấu phẩy (ví dụ Web + iOS).
 * Token hợp lệ khi audience khớp với MỘT trong các ID đó.
 */
@Component
public class GoogleTokenVerifier {
    private static final Logger log = LoggerFactory.getLogger(GoogleTokenVerifier.class);

    private final List<String> clientIds;
    private volatile GoogleIdTokenVerifier verifier;

    public GoogleTokenVerifier(AppProperties props) {
        this.clientIds = parseClientIds(props.google() == null ? null : props.google().clientId());
        if (clientIds.isEmpty())
            log.warn("GOOGLE_CLIENT_ID chưa được cấu hình: POST /auth/google sẽ báo lỗi cấu hình cho tới khi đặt biến này.");
        else
            log.info("Đăng nhập Google: chấp nhận {} Client ID", clientIds.size());
    }

    /** Tách chuỗi cấu hình thành danh sách Client ID (bỏ khoảng trắng, bỏ phần rỗng). */
    public static List<String> parseClientIds(String raw) {
        if (raw == null || raw.isBlank()) return List.of();
        return Arrays.stream(raw.split("[,;\\s]+")).map(String::trim).filter(s -> !s.isEmpty()).distinct().toList();
    }

    private GoogleIdTokenVerifier verifier() {
        if (verifier == null) {
            verifier = new GoogleIdTokenVerifier.Builder(new NetHttpTransport(), GsonFactory.getDefaultInstance())
                    .setAudience(clientIds).build();   // issuer mặc định: accounts.google.com
        }
        return verifier;
    }

    public GoogleIdToken.Payload verify(String idToken) {
        if (clientIds.isEmpty())
            throw new BusinessException(ErrorCode.INTERNAL_ERROR,
                    "Máy chủ chưa cấu hình đăng nhập Google (thiếu GOOGLE_CLIENT_ID). Vui lòng liên hệ quản trị viên.");
        if (idToken == null || idToken.isBlank())
            throw invalid();

        GoogleIdToken t;
        try {
            t = GoogleIdToken.parse(GsonFactory.getDefaultInstance(), idToken.trim());
        } catch (IOException | RuntimeException e) {
            throw invalid();                       // sai định dạng JWT
        }

        boolean ok;
        try {
            ok = verifier().verify(t);             // chữ ký, issuer, audience, expiry
        } catch (GeneralSecurityException e) {
            throw invalid();
        } catch (IOException e) {
            // Không tải được khóa công khai của Google: lỗi phía máy chủ, không phải do token.
            log.error("Không kết nối được Google để xác minh ID token", e);
            throw new BusinessException(ErrorCode.INTERNAL_ERROR,
                    "Không kết nối được Google để xác minh đăng nhập. Vui lòng thử lại sau.");
        }
        if (!ok) throw invalid();

        GoogleIdToken.Payload p = t.getPayload();
        if (!Boolean.TRUE.equals(p.getEmailVerified()) || p.getEmail() == null || p.getSubject() == null)
            throw new BusinessException(ErrorCode.INVALID_TOKEN, "Email Google chưa được xác minh");
        return p;
    }

    private static BusinessException invalid() {
        return new BusinessException(ErrorCode.INVALID_TOKEN, "Google ID token không hợp lệ");
    }
}
