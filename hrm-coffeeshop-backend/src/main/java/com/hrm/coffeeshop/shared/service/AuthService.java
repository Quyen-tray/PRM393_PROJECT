package com.hrm.coffeeshop.shared.service;

import com.hrm.coffeeshop.shared.dto.AuthDto.TokenResponse;
import com.hrm.coffeeshop.shared.dto.AuthDto.UserView;

import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import com.hrm.coffeeshop.common.*;
import com.hrm.coffeeshop.config.AppProperties;
import com.hrm.coffeeshop.config.JwtService;
import com.hrm.coffeeshop.domain.AppUser;
import com.hrm.coffeeshop.domain.RefreshToken;
import com.hrm.coffeeshop.repository.AppUserRepository;
import com.hrm.coffeeshop.repository.EmployeeRepository;
import com.hrm.coffeeshop.repository.RefreshTokenRepository;
import com.hrm.coffeeshop.repository.RoleRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Base64;
import java.util.List;
import java.util.Map;

@Service
public class AuthService {
    private final GoogleTokenVerifier google;
    private final AppUserRepository users;
    private final RoleRepository roles;
    private final EmployeeRepository employees;
    private final RefreshTokenRepository refreshTokens;
    private final JwtService jwt;
    private final AppProperties props;
    private final AuditService audit;
    private final Clock clock;
    private final SecureRandom random = new SecureRandom();


    public AuthService(GoogleTokenVerifier google, AppUserRepository users, RoleRepository roles,
                       EmployeeRepository employees, RefreshTokenRepository refreshTokens, JwtService jwt,
                       AppProperties props, AuditService audit, Clock clock) {
        this.google = google;
        this.users = users;
        this.roles = roles;
        this.employees = employees;
        this.refreshTokens = refreshTokens;
        this.jwt = jwt;
        this.props = props;
        this.audit = audit;
        this.clock = clock;
    }

    @Transactional
    public TokenResponse loginWithGoogle(String idToken) {
        GoogleIdToken.Payload p = google.verify(idToken);
        String email = p.getEmail().toLowerCase();
        String subject = p.getSubject();

        // Tài khoản phải được Admin cấp trước; không tự tạo tài khoản từ Google.
        AppUser u = users.findByGoogleSubject(subject).orElseGet(() -> users.findByEmail(email).orElse(null));
        if (u == null)
            throw new BusinessException(ErrorCode.ACCOUNT_NOT_ACTIVE,
                    "Tài khoản chưa được cấp quyền. Vui lòng liên hệ quản trị viên.");
        if (u.getGoogleSubject() != null && !u.getGoogleSubject().equals(subject))
            throw new BusinessException(ErrorCode.ACCOUNT_NOT_ACTIVE, "Tài khoản Google không khớp với tài khoản đã cấp");
        if (!"ACTIVE".equals(u.getUserStatus()))
            throw new BusinessException(ErrorCode.ACCOUNT_NOT_ACTIVE,
                    "Tài khoản đang bị khóa hoặc chưa kích hoạt. Vui lòng liên hệ quản trị viên.");
        List<String> codes = roles.findActiveCodesByUserId(u.getUserId());
        if (codes.isEmpty())
            throw new BusinessException(ErrorCode.ACCOUNT_NOT_ACTIVE,
                    "Tài khoản chưa được gán quyền. Vui lòng liên hệ quản trị viên.");

        if (u.getGoogleSubject() == null) u.setGoogleSubject(subject);
        Object pic = p.get("picture");
        if (pic instanceof String s && s.length() <= 1000) u.setAvatarUrl(s);
        u.setLastLoginAt(clock.instant());
        users.save(u);
        audit.log("AUTH_LOGIN", "AppUser", u.getUserId(), null, null);
        return issue(u, codes);
    }


    private static BusinessException invalidCredentials() {
        return new BusinessException(ErrorCode.INVALID_CREDENTIALS, "Email hoặc mật khẩu không đúng");
    }

    /**
     * noRollbackFor: khi phát hiện tái sử dụng, việc thu hồi toàn bộ phiên phải được COMMIT
     * trước khi trả lỗi. Nếu không, BusinessException (RuntimeException) sẽ rollback luôn thao tác thu hồi.
     */
    @Transactional(noRollbackFor = BusinessException.class)
    public TokenResponse refresh(String rawRefresh) {
        String hash = Hashing.sha256Hex(rawRefresh);
        RefreshToken t = refreshTokens.findByTokenHash(hash)
                .orElseThrow(() -> new BusinessException(ErrorCode.INVALID_TOKEN, "Refresh token không hợp lệ"));
        Instant now = clock.instant();
        Long userId = t.getUserId();
        if (t.getRevokedAt() != null) {
            // Dùng lại token đã xoay vòng → nghi ngờ bị đánh cắp: thu hồi toàn bộ phiên.
            refreshTokens.revokeAll(userId, now);
            throw new BusinessException(ErrorCode.INVALID_TOKEN, "Phiên đăng nhập không còn hiệu lực");
        }
        if (t.getExpiresAt().isBefore(now))
            throw new BusinessException(ErrorCode.INVALID_TOKEN, "Phiên đăng nhập đã hết hạn");
        // Hai request đồng thời cùng dùng một token: chỉ một request chiếm được quyền xoay vòng.
        if (refreshTokens.revokeIfActive(hash, now) == 0) {
            refreshTokens.revokeAll(userId, now);
            throw new BusinessException(ErrorCode.INVALID_TOKEN, "Phiên đăng nhập không còn hiệu lực");
        }
        AppUser u = users.findById(userId)
                .filter(x -> "ACTIVE".equals(x.getUserStatus()))
                .orElseThrow(() -> new BusinessException(ErrorCode.ACCOUNT_NOT_ACTIVE, "Tài khoản không còn hoạt động"));
        return issue(u, roles.findActiveCodesByUserId(u.getUserId()));
    }

    /** Đăng xuất tất cả thiết bị (dùng khi không gửi refresh token). */
    @Transactional
    public void logout(Long userId) {
        refreshTokens.revokeAll(userId, clock.instant());
        audit.log("AUTH_LOGOUT", "AppUser", userId, null, null);
    }

    /**
     * Đăng xuất đúng thiết bị đang dùng: thu hồi refresh token được gửi kèm.
     * Token không tồn tại hoặc không thuộc người dùng này thì bỏ qua (không lộ thông tin, idempotent).
     */
    @Transactional
    public void logout(Long userId, String rawRefresh) {
        if (rawRefresh == null || rawRefresh.isBlank()) { logout(userId); return; }
        String hash = Hashing.sha256Hex(rawRefresh);
        refreshTokens.findByTokenHash(hash)
                .filter(t -> userId.equals(t.getUserId()) && t.getRevokedAt() == null)
                .ifPresent(t -> {
                    t.setRevokedAt(clock.instant());
                    audit.log("AUTH_LOGOUT_DEVICE", "RefreshToken", t.getRefreshTokenId(), null, null);
                });
    }

    private TokenResponse issue(AppUser u, List<String> codes) {
        byte[] b = new byte[32];
        random.nextBytes(b);
        String raw = Base64.getUrlEncoder().withoutPadding().encodeToString(b);
        RefreshToken rt = new RefreshToken();
        rt.setUserId(u.getUserId());
        rt.setTokenHash(Hashing.sha256Hex(raw));
        rt.setExpiresAt(clock.instant().plus(props.jwt().refreshTtlDays(), ChronoUnit.DAYS));
        refreshTokens.save(rt);
        return new TokenResponse(jwt.createAccessToken(u.getUserId()), raw, "Bearer", jwt.accessTtlSeconds(), view(u, codes));
    }

    public UserView view(AppUser u, List<String> codes) {
        Long empId = employees.findByUserId(u.getUserId()).map(e -> e.getEmployeeId()).orElse(null);
        return new UserView(u.getUserId(), u.getEmail(), u.getDisplayName(), u.getAvatarUrl(), u.getPhoneNumber(), codes, empId, u.getUserStatus());
    }
}
