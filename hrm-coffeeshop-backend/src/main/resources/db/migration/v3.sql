-- Additive SQL Server migration. Apply once against the selected application database.
-- Uses @@ as a batch delimiter for Spring SQL initialization; replace @@ with GO in SSMS.
IF OBJECT_ID(N'dbo.EmployeeTraining', N'U') IS NULL
    THROW 51000, 'Initialize the base schema before applying V3 migration.', 1;
@@
IF COL_LENGTH('dbo.EmployeeTraining', 'CompletionReviewedAt') IS NULL
    ALTER TABLE dbo.EmployeeTraining ADD CompletionReviewedAt DATETIME2 NULL;
IF COL_LENGTH('dbo.EmployeeTraining', 'CompletionReviewedBy') IS NULL
    ALTER TABLE dbo.EmployeeTraining ADD CompletionReviewedBy BIGINT NULL;
IF COL_LENGTH('dbo.EmployeeTraining', 'CompletionReviewNote') IS NULL
    ALTER TABLE dbo.EmployeeTraining ADD CompletionReviewNote NVARCHAR(500) NULL;
IF COL_LENGTH('dbo.TrainingAttempt', 'AnswersJson') IS NULL
    ALTER TABLE dbo.TrainingAttempt ADD AnswersJson NVARCHAR(MAX) NULL;
@@
IF OBJECT_ID(N'dbo.CK_Attempt_Source', N'C') IS NOT NULL
    ALTER TABLE dbo.TrainingAttempt DROP CONSTRAINT CK_Attempt_Source;
ALTER TABLE dbo.TrainingAttempt WITH CHECK ADD CONSTRAINT CK_Attempt_Source CHECK (Source IN ('MANUAL','LMS','QUIZ'));
@@
IF OBJECT_ID(N'dbo.TrainingQuestion', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.TrainingQuestion (
        QuestionId BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        CourseId INT NOT NULL REFERENCES dbo.TrainingCourse(CourseId),
        QuestionText NVARCHAR(2000) NOT NULL,
        OptionA NVARCHAR(1000) NOT NULL, OptionB NVARCHAR(1000) NOT NULL,
        OptionC NVARCHAR(1000) NOT NULL, OptionD NVARCHAR(1000) NOT NULL,
        CorrectOption VARCHAR(1) NOT NULL CHECK (CorrectOption IN ('A','B','C','D')),
        SortOrder INT NOT NULL CHECK (SortOrder > 0),
        IsActive BIT NOT NULL DEFAULT 1
    );
    CREATE INDEX IX_TrainingQuestion_Course ON dbo.TrainingQuestion(CourseId, IsActive, SortOrder);
END;
@@
IF OBJECT_ID(N'dbo.ViolationExplanation', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ViolationExplanation (
        ExplanationId BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        ViolationEventId BIGINT NOT NULL REFERENCES dbo.ViolationEvent(ViolationEventId),
        EmployeeId BIGINT NOT NULL REFERENCES dbo.Employee(EmployeeId),
        Reason NVARCHAR(2000) NOT NULL,
        EvidenceStorageKey NVARCHAR(900) NULL,
        CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
    );
    CREATE INDEX IX_ViolationExplanation_Violation ON dbo.ViolationExplanation(ViolationEventId, CreatedAt);
END;
@@
