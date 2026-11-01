package com.hrm.coffeeshop;

import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import com.hrm.coffeeshop.common.BusinessException;
import com.hrm.coffeeshop.common.ErrorCode;
import com.hrm.coffeeshop.config.AppProperties;
import com.hrm.coffeeshop.config.JwtService;
import com.hrm.coffeeshop.domain.AppUser;
import com.hrm.coffeeshop.repository.AppUserRepository;
import com.hrm.coffeeshop.repository.EmployeeRepository;
import com.hrm.coffeeshop.repository.RefreshTokenRepository;
import com.hrm.coffeeshop.repository.RoleRepository;
import com.hrm.coffeeshop.shared.dto.AuthDto.TokenResponse;
import com.hrm.coffeeshop.shared.service.AuditService;
import com.hrm.coffeeshop.shared.service.AuthService;
import com.hrm.coffeeshop.shared.service.GoogleTokenVerifier;
import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

/** Luồng POST /auth/google (SRS 3.1): tài khoản phải do Admin cấp trước, không tự tạo từ Google. */
class GoogleLoginServiceTest {
    private final Clock clock = Clock.fixed(Instant.parse("2026-10-17T03:00:00Z"), ZoneOffset.UTC);
    private final AppUserRepository users = mock(AppUserRepository.class);
    private final RoleRepository roles = mock(RoleRepository.class);
    private final GoogleTokenVerifier google = mock(GoogleTokenVerifier.class);

    private AuthService svc() {
        JwtService jwt = mock(JwtService.class);
        when(jwt.createAccessToken(any())).thenReturn("access");
        AppProperties props = new AppProperties("Asia/Ho_Chi_Minh", new AppProperties.Jwt("x".repeat(32), 900, 14), null, null,
                null, null);
        return new AuthService(google, users, roles, mock(EmployeeRepository.class),
                mock(RefreshTokenRepository.class), jwt, props, mock(AuditService.class), clock);
    }

    private static GoogleIdToken.Payload payload(String email, String subject) {
        GoogleIdToken.Payload p = new GoogleIdToken.Payload();
        p.setEmail(email);
        p.setSubject(subject);
        p.setEmailVerified(true);
        p.set("picture", "https://example.com/a.png");
        return p;
    }

    private static AppUser user(String status, String subject) {
        AppUser u = new AppUser();
        u.setUserId(7L);
        u.setEmail("boss@gmail.com");
        u.setDisplayName("Boss");
        u.setUserStatus(status);
        u.setGoogleSubject(subject);
        return u;
    }

    @Test
    void firstLoginLinksGoogleSubjectByEmail() {
        AppUser u = user("ACTIVE", null);
        when(google.verify("tok")).thenReturn(payload("Boss@Gmail.com", "sub-1"));
        when(users.findByGoogleSubject("sub-1")).thenReturn(Optional.empty());
        when(users.findByEmail("boss@gmail.com")).thenReturn(Optional.of(u));
        when(roles.findActiveCodesByUserId(7L)).thenReturn(List.of("SYSTEM_ADMIN"));

        TokenResponse t = svc().loginWithGoogle("tok");

        assertEquals("access", t.accessToken());
        assertEquals("sub-1", u.getGoogleSubject());
        verify(users).save(u);
    }

    @Test
    void laterLoginMatchesBySubjectEvenIfEmailDiffers() {
        AppUser u = user("ACTIVE", "sub-1");
        when(google.verify("tok")).thenReturn(payload("new-address@gmail.com", "sub-1"));
        when(users.findByGoogleSubject("sub-1")).thenReturn(Optional.of(u));
        when(roles.findActiveCodesByUserId(7L)).thenReturn(List.of("EMPLOYEE"));

        assertEquals("access", svc().loginWithGoogle("tok").accessToken());
    }

    @Test
    void unknownAccountIsRejectedAndNotCreated() {
        when(google.verify("tok")).thenReturn(payload("stranger@gmail.com", "sub-9"));
        when(users.findByGoogleSubject("sub-9")).thenReturn(Optional.empty());
        when(users.findByEmail("stranger@gmail.com")).thenReturn(Optional.empty());

        BusinessException e = assertThrows(BusinessException.class, () -> svc().loginWithGoogle("tok"));
        assertEquals(ErrorCode.ACCOUNT_NOT_ACTIVE, e.getCode());
        verify(users, never()).save(any());
    }

    @Test
    void sameEmailButDifferentGoogleAccountIsRejected() {
        when(google.verify("tok")).thenReturn(payload("boss@gmail.com", "sub-OTHER"));
        when(users.findByGoogleSubject("sub-OTHER")).thenReturn(Optional.empty());
        when(users.findByEmail("boss@gmail.com")).thenReturn(Optional.of(user("ACTIVE", "sub-1")));

        BusinessException e = assertThrows(BusinessException.class, () -> svc().loginWithGoogle("tok"));
        assertEquals(ErrorCode.ACCOUNT_NOT_ACTIVE, e.getCode());
        verify(users, never()).save(any());
    }

    @Test
    void lockedAccountIsRejected() {
        when(google.verify("tok")).thenReturn(payload("boss@gmail.com", "sub-1"));
        when(users.findByGoogleSubject("sub-1")).thenReturn(Optional.of(user("LOCKED", "sub-1")));

        assertEquals(ErrorCode.ACCOUNT_NOT_ACTIVE,
                assertThrows(BusinessException.class, () -> svc().loginWithGoogle("tok")).getCode());
    }

    @Test
    void accountWithoutRolesIsRejected() {
        when(google.verify("tok")).thenReturn(payload("boss@gmail.com", "sub-1"));
        when(users.findByGoogleSubject("sub-1")).thenReturn(Optional.of(user("ACTIVE", "sub-1")));
        when(roles.findActiveCodesByUserId(7L)).thenReturn(List.of());

        assertEquals(ErrorCode.ACCOUNT_NOT_ACTIVE,
                assertThrows(BusinessException.class, () -> svc().loginWithGoogle("tok")).getCode());
    }

    @Test
    void invalidGoogleTokenIsPropagated() {
        when(google.verify("bad")).thenThrow(new BusinessException(ErrorCode.INVALID_TOKEN, "Google ID token không hợp lệ"));

        assertEquals(ErrorCode.INVALID_TOKEN,
                assertThrows(BusinessException.class, () -> svc().loginWithGoogle("bad")).getCode());
        verifyNoInteractions(users);
    }
}
