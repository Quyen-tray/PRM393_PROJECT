package com.hrm.coffeeshop.it;

import com.hrm.coffeeshop.common.BusinessException;
import com.hrm.coffeeshop.common.ErrorCode;
import com.hrm.coffeeshop.common.Hashing;
import com.hrm.coffeeshop.shared.dto.AuthDto.TokenResponse;
import com.hrm.coffeeshop.shared.service.AuthService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.time.Duration;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.*;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Luồng 4 — Refresh token: xoay vòng, tái sử dụng, race condition, đăng xuất, rollback.
 * Đặc biệt kiểm tra: khi phát hiện tái sử dụng và trả lỗi, việc thu hồi toàn bộ phiên
 * vẫn được COMMIT (không bị rollback theo BusinessException).
 */
class RefreshTokenIT extends IntegrationTestBase {

    @Autowired AuthService auth;

    @BeforeEach
    void setClock() {
        clock.setAt(Instant.parse("2034-01-01T03:00:00Z"));
    }

    private long newUser() {
        return createUser("it-refresh-" + UUID.randomUUID() + "@hrm.test");
    }

    /** Chèn một refresh token còn hạn 1 ngày, trả về bản gốc (raw) để client dùng. */
    private String issue(long userId) {
        String raw = "rt-" + UUID.randomUUID();
        LocalDateTime expires = LocalDateTime.ofInstant(clock.instant().plus(Duration.ofDays(1)), ZoneOffset.UTC);
        jdbc.update("INSERT INTO dbo.RefreshToken (UserId, TokenHash, ExpiresAt) VALUES (?, ?, ?)",
                userId, Hashing.sha256Hex(raw), expires);
        return raw;
    }

    private int activeTokens(long userId) {
        return jdbc.queryForObject(
                "SELECT COUNT(*) FROM dbo.RefreshToken WHERE UserId = ? AND RevokedAt IS NULL", Integer.class, userId);
    }

    @Test
    void rotationIssuesNewTokenAndRevokesTheOldOne() {
        long user = newUser();
        String raw1 = issue(user);

        TokenResponse r = auth.refresh(raw1);

        assertNotNull(r.refreshToken());
        assertNotEquals(raw1, r.refreshToken(), "Phải cấp refresh token mới");
        assertEquals(1, activeTokens(user), "Chỉ token mới còn hiệu lực");
        assertRejectedRefresh(raw1, ErrorCode.INVALID_TOKEN);
    }

    @Test
    void reuseOfRotatedTokenRevokesEverySessionAndCommitsTheRevocation() {
        long user = newUser();
        String raw1 = issue(user);
        issue(user);                                   // phiên thứ hai (thiết bị khác)
        auth.refresh(raw1);                            // raw1 đã xoay vòng → còn 2 phiên hoạt động
        assertEquals(2, activeTokens(user));

        // Dùng lại raw1: phải trả lỗi VÀ thu hồi mọi phiên, và việc thu hồi phải được commit.
        BusinessException e = assertThrows(BusinessException.class, () -> auth.refresh(raw1));
        assertEquals(ErrorCode.INVALID_TOKEN, e.getCode());
        assertEquals(0, activeTokens(user),
                "Thu hồi phiên khi phát hiện tái sử dụng bị rollback: các phiên vẫn còn hiệu lực");
    }

    @Test
    void concurrentRefreshWithSameTokenLetsOnlyOneRequestWin() throws Exception {
        long user = newUser();
        String raw = issue(user);

        ExecutorService pool = Executors.newFixedThreadPool(2);
        try {
            CyclicBarrier start = new CyclicBarrier(2);
            List<Future<String>> futures = new ArrayList<>();
            for (int i = 0; i < 2; i++) {
                futures.add(pool.submit(() -> {
                    start.await(10, TimeUnit.SECONDS);
                    try {
                        auth.refresh(raw);
                        return "OK";
                    } catch (BusinessException e) {
                        return e.getCode().name();
                    }
                }));
            }
            List<String> results = new ArrayList<>();
            for (Future<String> f : futures) results.add(f.get(30, TimeUnit.SECONDS));

            assertEquals(1, results.stream().filter("OK"::equals).count(),
                    "Chỉ một request được xoay vòng, kết quả: " + results);
            assertTrue(results.contains(ErrorCode.INVALID_TOKEN.name()),
                    "Request thua phải nhận INVALID_TOKEN, kết quả: " + results);
            assertEquals(0, activeTokens(user), "Sau tranh chấp không còn phiên nào hoạt động");
        } finally {
            pool.shutdownNow();
        }
    }

    @Test
    void logoutRevokesOnlyTheCurrentDevice() {
        long user = newUser();
        String deviceA = issue(user);
        String deviceB = issue(user);

        auth.logout(user, deviceA);

        assertEquals(1, activeTokens(user), "Chỉ thiết bị A bị đăng xuất");
        assertDoesNotThrow(() -> auth.refresh(deviceB), "Thiết bị B vẫn phải làm mới được token");
    }

    @Test
    void logoutWithoutTokenRevokesAllDevices() {
        long user = newUser();
        issue(user);
        issue(user);

        auth.logout(user, null);

        assertEquals(0, activeTokens(user));
    }

    @Test
    void logoutWithAnotherUsersTokenHasNoEffect() {
        long owner = newUser();
        long intruder = newUser();
        String ownerToken = issue(owner);

        auth.logout(intruder, ownerToken);

        assertEquals(1, activeTokens(owner), "Không được đăng xuất phiên của người khác");
    }

    @Test
    void expiredTokenIsRejectedWithoutSideEffects() {
        long user = newUser();
        String raw = issue(user);

        clock.setAt(clock.instant().plus(Duration.ofDays(2)));   // vượt hạn 1 ngày
        BusinessException e = assertThrows(BusinessException.class, () -> auth.refresh(raw));

        assertEquals(ErrorCode.INVALID_TOKEN, e.getCode());
        assertEquals(1, activeTokens(user), "Token hết hạn bị từ chối nhưng không được làm thay đổi phiên khác");
    }

    private void assertRejectedRefresh(String raw, ErrorCode expected) {
        BusinessException e = assertThrows(BusinessException.class, () -> auth.refresh(raw));
        assertEquals(expected, e.getCode());
    }
}
