package com.hrm.coffeeshop.it;

import com.hrm.coffeeshop.HrmApplication;
import com.hrm.coffeeshop.common.AuthUser;
import com.hrm.coffeeshop.common.BusinessException;
import com.hrm.coffeeshop.common.ErrorCode;
import com.hrm.coffeeshop.common.Permissions;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.LocationDto;
import com.hrm.coffeeshop.shared.dto.AttendanceDto.PhotoEvidence;
import com.hrm.coffeeshop.shared.service.StorageGateway;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.function.Executable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.lang.reflect.Modifier;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.sql.Statement;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.time.ZonedDateTime;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.Arrays;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assertions.assertThrows;

/**
 * SQL Server thật tại HRM_TEST_DB_URL, nạp schema/seed vào database kiểm thử riêng,
 * ứng dụng Spring đầy đủ và đồng hồ điều khiển được. Không yêu cầu Docker.
 * Chạy tooling/Test-HrmBackend.ps1 -Integration từ workspace Flutter.
 */
@SpringBootTest(classes = HrmApplication.class)
@Import(IntegrationTestBase.TestClockConfig.class)
@EnabledIfEnvironmentVariable(named = "HRM_TEST_DB_URL", matches = ".*databaseName=HRM_CoffeeShop_V3_Test(?:_[0-9]+)?(?:;.*)?")
public abstract class IntegrationTestBase {

    static final ZoneId VN = ZoneId.of("Asia/Ho_Chi_Minh");
    static final String TEST_URL = System.getenv("HRM_TEST_DB_URL");
    static final String TEST_USER = System.getenv("HRM_TEST_DB_USERNAME");
    static final String TEST_PASSWORD = System.getenv("HRM_TEST_DB_PASSWORD");
    static final String TEST_DB = TEST_URL == null ? null : TEST_URL.replaceFirst(".*databaseName=(HRM_CoffeeShop_V3_Test(?:_[0-9]+)?)(?:;.*)?", "$1");
    static final Path STORAGE_DIR = tempDir();
    static final Set<String> ALL_PERMISSIONS = allPermissions();

    static {
        if (TEST_URL != null) {
            if (!TEST_URL.matches(".*databaseName=HRM_CoffeeShop_V3_Test(?:_[0-9]+)?(?:;.*)?"))
                throw new IllegalStateException("Integration tests only accept the dedicated HRM_CoffeeShop_V3_Test database");
            initializeTestDatabase();
        }
    }

    @DynamicPropertySource
    static void applicationProperties(DynamicPropertyRegistry r) {
        r.add("spring.datasource.url", () -> TEST_URL);
        r.add("spring.datasource.username", () -> TEST_USER);
        r.add("spring.datasource.password", () -> TEST_PASSWORD);
        r.add("spring.sql.init.mode", () -> "always");
        r.add("app.jwt.secret", () -> "it-jwt-secret-" + "a".repeat(32));
        r.add("app.storage.signing-secret", () -> "it-storage-secret-" + "b".repeat(32));
        r.add("app.storage.local-dir", () -> STORAGE_DIR.toString());
        r.add("app.google.client-id", () -> "it-client-id");
        r.add("ATTENDANCE_FLEXIBLE_TESTING_ENABLED", () -> "false");
    }

    @Autowired protected JdbcTemplate jdbc;
    @Autowired protected TestClock clock;
    @Autowired protected StorageGateway storage;

    @BeforeEach
    void clearSecurityContext() {
        SecurityContextHolder.clearContext();
    }

    // ----------------------------------------------------------- nạp dữ liệu

    static void runScript(String file) {
        String text;
        try {
            text = Files.readString(Path.of("infra/sqlserver", file), StandardCharsets.UTF_8).replace("\uFEFF", "")
                    .replace("HRM_CoffeeShop", TEST_DB);
        } catch (IOException e) {
            throw new UncheckedIOException("Không đọc được " + file + " (chạy test từ thư mục gốc của backend)", e);
        }
        try (Connection c = DriverManager.getConnection(TEST_URL.replace("databaseName=" + TEST_DB, "databaseName=master"), TEST_USER, TEST_PASSWORD);
             Statement st = c.createStatement()) {
            for (String batch : text.split("(?im)^\\s*GO\\s*$")) {
                if (!batch.isBlank()) st.execute(batch);
            }
        } catch (SQLException e) {
            throw new IllegalStateException("Lỗi khi chạy " + file, e);
        }
    }

    static void initializeTestDatabase() {
        // No DROP/reset: every run uses new fixture identities and preserves previous evidence.
        try (Connection c = DriverManager.getConnection(TEST_URL.replace("databaseName=" + TEST_DB, "databaseName=master"), TEST_USER, TEST_PASSWORD);
             Statement s = c.createStatement(); var rs = s.executeQuery("SELECT DB_ID(N'" + TEST_DB + "')")) {
            rs.next(); if (rs.getObject(1) != null) return;
        } catch (SQLException e) { throw new IllegalStateException("Cannot inspect dedicated test database", e); }
        runScript("config.sql"); runScript("seeddata.sql");
    }

    static Path tempDir() {
        try {
            return Files.createTempDirectory("hrm-it-storage");
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    static Set<String> allPermissions() {
        return Arrays.stream(Permissions.class.getFields())
                .filter(f -> Modifier.isStatic(f.getModifiers()) && f.getType() == String.class)
                .map(f -> {
                    try {
                        return (String) f.get(null);
                    } catch (IllegalAccessException e) {
                        throw new IllegalStateException(e);
                    }
                })
                .collect(Collectors.toUnmodifiableSet());
    }

    // ----------------------------------------------------------- đồng hồ & xác thực

    @TestConfiguration
    public static class TestClockConfig {
        @Bean
        @Primary
        public TestClock testClock() {
            return new TestClock();
        }
    }

    /** Đồng hồ điều khiển được để kiểm soát thời điểm check-in, chốt kỳ và hết hạn token. */
    public static final class TestClock extends Clock {
        private volatile Instant now = Instant.parse("2031-03-01T00:00:00Z");

        public void setAt(Instant t) { now = t; }

        /** Đặt giờ Việt Nam (UTC+7). */
        public void setVn(int y, int mo, int d, int h, int mi) {
            now = ZonedDateTime.of(y, mo, d, h, mi, 0, 0, VN).toInstant();
        }

        @Override public ZoneId getZone() { return ZoneOffset.UTC; }

        @Override public Instant instant() { return now; }

        @Override
        public Clock withZone(ZoneId zone) {
            TestClock self = this;
            return new Clock() {
                @Override public ZoneId getZone() { return zone; }
                @Override public Instant instant() { return self.instant(); }
                @Override public Clock withZone(ZoneId z) { return self.withZone(z); }
            };
        }
    }

    /** Đăng nhập giả lập: gắn AuthUser vào SecurityContext của thread hiện tại. */
    protected static void loginAs(long userId, Long employeeId, Set<String> roles) {
        AuthUser u = new AuthUser(userId, "it-" + userId + "@hrm.test", roles, ALL_PERMISSIONS, employeeId);
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(u, null, List.of()));
    }

    // ----------------------------------------------------------- fixture & truy vấn

    protected long userIdByEmail(String email) {
        return jdbc.queryForObject("SELECT UserId FROM dbo.AppUser WHERE Email = ?", Long.class, email);
    }

    protected long createUser(String email) {
        jdbc.update("INSERT INTO dbo.AppUser (Email, DisplayName, PhoneNumber, UserStatus) VALUES (?, ?, NULL, 'ACTIVE')",
                email, "IT " + email);
        return userIdByEmail(email);
    }

    protected long employeeIdByCode(String code) {
        return jdbc.queryForObject("SELECT EmployeeId FROM dbo.Employee WHERE EmployeeCode = ?", Long.class, code);
    }

    protected long userIdOfEmployee(String code) {
        return jdbc.queryForObject("SELECT UserId FROM dbo.Employee WHERE EmployeeCode = ?", Long.class, code);
    }

    protected long activeDeviceId(long employeeId) {
        return jdbc.queryForObject(
                "SELECT TOP 1 DeviceId FROM dbo.AttendanceDevice WHERE EmployeeId = ? AND Status = 'ACTIVE'",
                Long.class, employeeId);
    }

    protected int workShiftId(String shiftCode) {
        return jdbc.queryForObject("SELECT WorkShiftId FROM dbo.WorkShift WHERE ShiftCode = ?", Integer.class, shiftCode);
    }

    protected long attendanceIdOfShift(long shiftAssignmentId) {
        return jdbc.queryForObject("SELECT AttendanceId FROM dbo.Attendance WHERE ShiftAssignmentId = ?",
                Long.class, shiftAssignmentId);
    }

    protected int countAttendanceOfShift(long shiftAssignmentId) {
        return jdbc.queryForObject("SELECT COUNT(*) FROM dbo.Attendance WHERE ShiftAssignmentId = ?",
                Integer.class, shiftAssignmentId);
    }

    /** Tải một ảnh hợp lệ về đúng khóa mà server sẽ kiểm tra (đúng chủ, đúng định dạng). */
    protected PhotoEvidence uploadPhoto(long employeeId, LocalDate date) {
        String key = "attendance-evidence/" + employeeId + "/" + date.toString().replace("-", "")
                + "/" + UUID.randomUUID() + ".jpg";
        storage.store(key, new byte[]{(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, 0x00});
        return new PhotoEvidence(key, true);
    }

    /** Vị trí trùng tọa độ cửa hàng seed (CF-HN01), độ chính xác tốt, đo ngay tại thời điểm đồng hồ test. */
    protected LocationDto onSite() {
        return new LocationDto(21.0278, 105.8342, 10.0, OffsetDateTime.ofInstant(clock.instant(), ZoneOffset.UTC));
    }

    protected static Instant vn(int y, int mo, int d, int h, int mi) {
        return ZonedDateTime.of(y, mo, d, h, mi, 0, 0, VN).toInstant();
    }

    // ----------------------------------------------------------- khẳng định

    /** Thao tác phải bị từ chối với một trong các mã lỗi cho phép. */
    protected static BusinessException assertRejected(Executable action, ErrorCode... allowed) {
        BusinessException e = assertThrows(BusinessException.class, action);
        Set<ErrorCode> ok = Set.of(allowed);
        assertTrue(ok.contains(e.getCode()),
                "Mã lỗi không mong đợi: " + e.getCode() + " (" + e.getMessage() + "), mong đợi " + ok);
        return e;
    }
}
