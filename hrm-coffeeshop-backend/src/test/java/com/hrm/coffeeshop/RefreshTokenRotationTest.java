package com.hrm.coffeeshop;

import com.hrm.coffeeshop.common.BusinessException;
import com.hrm.coffeeshop.common.Hashing;
import com.hrm.coffeeshop.config.AppProperties;
import com.hrm.coffeeshop.config.JwtService;
import com.hrm.coffeeshop.domain.RefreshToken;
import com.hrm.coffeeshop.repository.*;
import com.hrm.coffeeshop.shared.service.AuditService;
import com.hrm.coffeeshop.shared.service.AuthService;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import com.hrm.coffeeshop.shared.service.GoogleTokenVerifier;
import org.junit.jupiter.api.Test;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

/** Xoay vòng refresh token: phát hiện tái sử dụng, race condition, đăng xuất đúng thiết bị. */
class RefreshTokenRotationTest {
    private final Clock clock = Clock.fixed(Instant.parse("2026-10-17T03:00:00Z"), ZoneOffset.UTC);
    private final String raw = "raw-refresh-token-value";
    private final String hash = Hashing.sha256Hex(raw);
    private final RefreshTokenRepository tokens = mock(RefreshTokenRepository.class);
    private final AuditService audit = mock(AuditService.class);

    private AuthService svc() {
        JwtService jwt = mock(JwtService.class);
        AppProperties props = new AppProperties("Asia/Ho_Chi_Minh", new AppProperties.Jwt("x".repeat(32), 900, 14), null, null, null, null);
        return new AuthService(mock(GoogleTokenVerifier.class), mock(AppUserRepository.class), mock(RoleRepository.class),
                mock(EmployeeRepository.class), tokens, jwt, props, audit, clock);
    }

    private RefreshToken token(Instant revokedAt) {
        RefreshToken t = new RefreshToken();
        t.setUserId(7L);
        t.setTokenHash(hash);
        t.setExpiresAt(Instant.parse("2026-10-31T00:00:00Z"));
        t.setRevokedAt(revokedAt);
        return t;
    }

    @Test
    void reuseOfRotatedTokenRevokesAllSessions() {
        when(tokens.findByTokenHash(hash)).thenReturn(java.util.Optional.of(token(Instant.parse("2026-10-16T00:00:00Z"))));
        assertThrows(BusinessException.class, () -> svc().refresh(raw));
        verify(tokens).revokeAll(eq(7L), any());
    }

    @Test
    void concurrentUseLosesRaceAndRevokesAllSessions() {
        when(tokens.findByTokenHash(hash)).thenReturn(java.util.Optional.of(token(null)));
        when(tokens.revokeIfActive(eq(hash), any())).thenReturn(0);   // request khác đã xoay vòng trước
        assertThrows(BusinessException.class, () -> svc().refresh(raw));
        verify(tokens).revokeAll(eq(7L), any());
    }

    @Test
    void logoutWithTokenRevokesOnlyThatDevice() {
        RefreshToken mine = token(null);
        when(tokens.findByTokenHash(hash)).thenReturn(java.util.Optional.of(mine));
        svc().logout(7L, raw);
        assertNotNull(mine.getRevokedAt());
        verify(tokens, never()).revokeAll(anyLong(), any());
    }

    @Test
    void logoutWithAnotherUsersTokenDoesNothing() {
        RefreshToken theirs = token(null);
        when(tokens.findByTokenHash(hash)).thenReturn(java.util.Optional.of(theirs));
        svc().logout(99L, raw);
        assertNull(theirs.getRevokedAt());
        verify(tokens, never()).revokeAll(anyLong(), any());
    }

    @Test
    void logoutWithoutTokenRevokesAllDevices() {
        svc().logout(7L, null);
        verify(tokens).revokeAll(eq(7L), any());
    }
}
