package com.hrm.coffeeshop.it;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.Statement;

import static org.junit.jupiter.api.Assertions.*;

/** A separate fresh database proves the two SQL setup files contain the current schema and minimal demo. */
@EnabledIfEnvironmentVariable(named = "HRM_TEST_DB_URL", matches = ".*databaseName=HRM_CoffeeShop_V3_Test(?:_[0-9]+)?(?:;.*)?")
class SchemaBootstrapIT {
    @Test void configAndSeedCreateCurrentSchemaAndMinimalDemo() throws Exception {
        String database = "HRM_CoffeeShop_V3_Test_" + System.currentTimeMillis() + "31";
        String masterUrl = System.getenv("HRM_TEST_DB_URL").replaceFirst("(?i)databaseName=[^;]+", "databaseName=master");
        try (Connection connection = DriverManager.getConnection(masterUrl,
                System.getenv("HRM_TEST_DB_USERNAME"), System.getenv("HRM_TEST_DB_PASSWORD"));
             Statement sql = connection.createStatement()) {
            run(sql, Files.readString(Path.of("infra/sqlserver/config.sql"), StandardCharsets.UTF_8)
                    .replace("HRM_CoffeeShop", database), "(?im)^\\s*GO\\s*$");
            run(sql, Files.readString(Path.of("infra/sqlserver/seeddata.sql"), StandardCharsets.UTF_8)
                    .replace("HRM_CoffeeShop", database), "(?im)^\\s*GO\\s*$");
            assertEquals(3, scalar(sql, "SELECT COUNT(*) FROM dbo.AppUser"));
            assertEquals(2, scalar(sql, "SELECT COUNT(*) FROM dbo.Employee"));
            assertEquals(1, scalar(sql, "SELECT COUNT(*) FROM sys.tables WHERE name='AttendanceSpotCheck'"));
            assertEquals(1, scalar(sql, "SELECT COUNT(*) FROM sys.tables WHERE name='AttendanceVerificationAttempt'"));
            assertEquals(7, scalar(sql, "SELECT COUNT(*) FROM dbo.ShiftAssignment sa "
                    + "JOIN dbo.WorkShift ws ON ws.WorkShiftId=sa.WorkShiftId WHERE ws.ShiftCode='CA_TEST'"));
        }
    }

    private static void run(Statement sql, String source, String separator) throws Exception {
        for (String batch : source.replace("\uFEFF", "").split(separator)) {
            if (!batch.isBlank()) sql.execute(batch);
        }
    }

    private static long scalar(Statement sql, String query) throws Exception {
        try (var rows = sql.executeQuery(query)) {
            assertTrue(rows.next());
            return rows.getLong(1);
        }
    }
}
