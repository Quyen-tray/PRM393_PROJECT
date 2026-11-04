-- Employee-submitted completion review for non-quiz training courses.
IF OBJECT_ID('dbo.EmployeeTraining', 'U') IS NULL
    THROW 51002, N'EmployeeTraining chưa tồn tại; hãy cài schema trước.', 1;
GO

IF COL_LENGTH('dbo.EmployeeTraining', 'CompletionSubmittedAt') IS NULL
    ALTER TABLE dbo.EmployeeTraining ADD CompletionSubmittedAt DATETIME2 NULL;
IF COL_LENGTH('dbo.EmployeeTraining', 'CompletionRequestNote') IS NULL
    ALTER TABLE dbo.EmployeeTraining ADD CompletionRequestNote NVARCHAR(500) NULL;
IF COL_LENGTH('dbo.EmployeeTraining', 'CompletionReviewedAt') IS NULL
    ALTER TABLE dbo.EmployeeTraining ADD CompletionReviewedAt DATETIME2 NULL;
IF COL_LENGTH('dbo.EmployeeTraining', 'CompletionReviewedBy') IS NULL
    ALTER TABLE dbo.EmployeeTraining ADD CompletionReviewedBy BIGINT NULL;
IF COL_LENGTH('dbo.EmployeeTraining', 'CompletionReviewNote') IS NULL
    ALTER TABLE dbo.EmployeeTraining ADD CompletionReviewNote NVARCHAR(500) NULL;
GO

IF OBJECT_ID('dbo.FK_EmployeeTraining_CompletionReviewedBy', 'F') IS NULL
    ALTER TABLE dbo.EmployeeTraining WITH CHECK
        ADD CONSTRAINT FK_EmployeeTraining_CompletionReviewedBy
        FOREIGN KEY (CompletionReviewedBy) REFERENCES dbo.AppUser(UserId);
GO

IF OBJECT_ID('dbo.CK_EmployeeTraining_Status', 'C') IS NOT NULL
    ALTER TABLE dbo.EmployeeTraining DROP CONSTRAINT CK_EmployeeTraining_Status;
ALTER TABLE dbo.EmployeeTraining WITH CHECK
    ADD CONSTRAINT CK_EmployeeTraining_Status CHECK (TrainingStatus IN
        ('NOT_STARTED', 'IN_PROGRESS', 'PENDING_REVIEW', 'PASSED', 'FAILED', 'EXPIRED'));
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.EmployeeTraining')
      AND name = 'IX_EmployeeTraining_CompletionReviewQueue'
)
    CREATE INDEX IX_EmployeeTraining_CompletionReviewQueue
        ON dbo.EmployeeTraining(TrainingStatus, CompletionSubmittedAt)
        INCLUDE (EmployeeId, CourseId);
GO
