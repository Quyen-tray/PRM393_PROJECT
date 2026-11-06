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

/** A separate fresh database proves config.sql works before Spring can apply a migration. */
@EnabledIfEnvironmentVariable(named = "HRM_TEST_DB_URL", matches = ".*databaseName=HRM_CoffeeShop_V3_Test(?:_[0-9]+)?(?:;.*)?")
class SchemaBootstrapIT {
    @Test void configContainsV3AndOldMigrationCanStillRunWithoutLosingData() throws Exception {
        String database = "HRM_CoffeeShop_V3_Test_" + System.currentTimeMillis() + "31";
        String masterUrl = System.getenv("HRM_TEST_DB_URL").replaceFirst("(?i)databaseName=[^;]+", "databaseName=master");
        try (Connection connection = DriverManager.getConnection(masterUrl,
                System.getenv("HRM_TEST_DB_USERNAME"), System.getenv("HRM_TEST_DB_PASSWORD"));
             Statement sql = connection.createStatement()) {
            run(sql, Files.readString(Path.of("infra/sqlserver/config.sql"), StandardCharsets.UTF_8)
                    .replace("HRM_CoffeeShop", database), "(?im)^\\s*GO\\s*$");
            run(sql, Files.readString(Path.of("infra/sqlserver/seeddata.sql"), StandardCharsets.UTF_8)
                    .replace("HRM_CoffeeShop", database), "(?im)^\\s*GO\\s*$");
            assertEquals(4, scalar(sql, "SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE "
                    + "(TABLE_NAME='EmployeeTraining' AND COLUMN_NAME IN ('CompletionReviewedAt','CompletionReviewedBy','CompletionReviewNote')) "
                    + "OR (TABLE_NAME='TrainingAttempt' AND COLUMN_NAME='AnswersJson')"));
            assertEquals(2, scalar(sql, "SELECT COUNT(*) FROM sys.tables WHERE name IN ('TrainingQuestion','ViolationExplanation')"));
            sql.executeUpdate("INSERT INTO dbo.TrainingAttempt (EmployeeId,CourseId,AttemptNo,Score,IsPassed,Source,AnswersJson) "
                    + "SELECT TOP (1) EmployeeId,CourseId,1000,100,1,'QUIZ',N'{}' FROM dbo.EmployeeTraining");
            assertEquals(1, scalar(sql, "SELECT COUNT(*) FROM dbo.TrainingAttempt WHERE AttemptNo=1000 AND Source='QUIZ' AND AnswersJson=N'{}'"));
            long users = scalar(sql, "SELECT COUNT(*) FROM dbo.AppUser");
            long attempts = scalar(sql, "SELECT COUNT(*) FROM dbo.TrainingAttempt");
            String migration = Files.readString(Path.of("src/main/resources/db/migration/v3.sql"), StandardCharsets.UTF_8);
            run(sql, migration, "(?m)^@@\\s*$");
            run(sql, migration, "(?m)^@@\\s*$");
            assertEquals(users, scalar(sql, "SELECT COUNT(*) FROM dbo.AppUser"));
            assertEquals(attempts, scalar(sql, "SELECT COUNT(*) FROM dbo.TrainingAttempt"));
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
