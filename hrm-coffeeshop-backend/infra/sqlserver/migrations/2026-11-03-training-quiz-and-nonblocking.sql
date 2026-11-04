-- Add employee-scored multiple-choice quizzes and make position training informational for shift access.
IF OBJECT_ID('dbo.TrainingQuestion', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.TrainingQuestion (
        QuestionId BIGINT IDENTITY(1,1) PRIMARY KEY,
        CourseId INT NOT NULL,
        QuestionText NVARCHAR(1000) NOT NULL,
        OptionA NVARCHAR(300) NOT NULL,
        OptionB NVARCHAR(300) NOT NULL,
        OptionC NVARCHAR(300) NOT NULL,
        OptionD NVARCHAR(300) NOT NULL,
        CorrectOption CHAR(1) NOT NULL,
        SortOrder INT NOT NULL,
        IsActive BIT NOT NULL CONSTRAINT DF_TrainingQuestion_IsActive DEFAULT 1,
        CONSTRAINT FK_TrainingQuestion_Course FOREIGN KEY (CourseId)
            REFERENCES dbo.TrainingCourse(CourseId),
        CONSTRAINT UQ_TrainingQuestion_Course_SortOrder UNIQUE (CourseId, SortOrder),
        CONSTRAINT CK_TrainingQuestion_CorrectOption CHECK (CorrectOption IN ('A', 'B', 'C', 'D')),
        CONSTRAINT CK_TrainingQuestion_SortOrder CHECK (SortOrder > 0)
    );
END;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID('dbo.TrainingQuestion')
      AND name = 'IX_TrainingQuestion_Course_Active_Order'
)
    CREATE INDEX IX_TrainingQuestion_Course_Active_Order
        ON dbo.TrainingQuestion(CourseId, IsActive, SortOrder, QuestionId);
GO

-- Demo-ready question bank for Employee A's seeded BARISTA_BASIC enrollment.
INSERT INTO dbo.TrainingQuestion
    (CourseId, QuestionText, OptionA, OptionB, OptionC, OptionD, CorrectOption, SortOrder)
SELECT c.CourseId, q.QuestionText, q.OptionA, q.OptionB, q.OptionC, q.OptionD, q.CorrectOption, q.SortOrder
FROM (VALUES
    (N'Tác dụng chính của việc cân cà phê là gì?', N'Kiểm soát tỷ lệ pha ổn định', N'Làm hạt cà phê ngọt hơn', N'Tăng nhiệt độ nước', N'Thay thế việc xay cà phê', 'A', 1),
    (N'Khi espresso chảy quá nhanh, nên kiểm tra gì trước?', N'Độ mịn và lượng cà phê xay', N'Màu của ly', N'Vị trí bàn khách', N'Kích thước khăn lau', 'A', 2),
    (N'Sữa dùng để đánh nóng nên được xử lý thế nào?', N'Tái sử dụng nhiều lần', N'Làm nóng theo nhiệt độ và quy trình quy định', N'Đun sôi hoàn toàn', N'Để ngoài quầy cả ngày', 'B', 3),
    (N'Sau khi chiết xuất espresso, cần làm gì với tay pha?', N'Để nguyên đến cuối ngày', N'Rửa sạch bã và lau khô', N'Ngâm trong sữa', N'Đặt lên khăn ướt', 'B', 4),
    (N'Để công thức đồ uống nhất quán, cần làm gì?', N'Ước lượng nguyên liệu bằng mắt', N'Tuân thủ định lượng và thứ tự pha', N'Thay đổi công thức mỗi lần', N'Bỏ qua thời gian chiết xuất', 'B', 5)
) q(QuestionText, OptionA, OptionB, OptionC, OptionD, CorrectOption, SortOrder)
JOIN dbo.TrainingCourse c ON c.CourseCode = 'BARISTA_BASIC'
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.TrainingQuestion existing WHERE existing.CourseId = c.CourseId
);
GO

IF OBJECT_ID('dbo.TrainingAttempt', 'U') IS NOT NULL
BEGIN
    IF OBJECT_ID('dbo.CK_Attempt_Source', 'C') IS NOT NULL
        ALTER TABLE dbo.TrainingAttempt DROP CONSTRAINT CK_Attempt_Source;

    ALTER TABLE dbo.TrainingAttempt WITH CHECK
        ADD CONSTRAINT CK_Attempt_Source CHECK (Source IN ('MANUAL', 'LMS', 'QUIZ'));
END;
GO

IF OBJECT_ID('dbo.PositionTrainingRequirement', 'U') IS NOT NULL
BEGIN
    UPDATE dbo.PositionTrainingRequirement SET BlocksShiftAssignment = 0
    WHERE BlocksShiftAssignment <> 0;

    DECLARE @defaultName sysname;
    SELECT @defaultName = dc.name
    FROM sys.default_constraints dc
    JOIN sys.columns col
      ON col.object_id = dc.parent_object_id
     AND col.column_id = dc.parent_column_id
    WHERE dc.parent_object_id = OBJECT_ID('dbo.PositionTrainingRequirement')
      AND col.name = 'BlocksShiftAssignment';

    IF @defaultName IS NOT NULL
    BEGIN
        DECLARE @dropDefaultSql nvarchar(4000) =
            N'ALTER TABLE dbo.PositionTrainingRequirement DROP CONSTRAINT ' + QUOTENAME(@defaultName);
        EXEC sp_executesql @dropDefaultSql;
    END;

    ALTER TABLE dbo.PositionTrainingRequirement
        ADD CONSTRAINT DF_PTR_BlocksShiftAssignment DEFAULT 0 FOR BlocksShiftAssignment;
END;
GO
