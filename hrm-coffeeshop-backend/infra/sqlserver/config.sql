-- ============================================================================
-- config.sql
-- Tạo database và toàn bộ cấu trúc: bảng, khóa, CHECK/UNIQUE constraints, index.
-- Chỉ dùng để cài mới. Nếu database đã tồn tại, script sẽ dừng và KHÔNG xóa dữ liệu.
-- ============================================================================
-- =====================================================================================
-- Chạy file này một lần trên SQL Server bằng tài khoản có quyền CREATE DATABASE.
-- Nếu HRM_CoffeeShop đã tồn tại, script dừng để tránh xóa nhầm dữ liệu.
-- Sau khi chạy thành công, chạy tiếp seeddata.sql.
-- =====================================================================================
USE master;
GO
IF DB_ID(N'HRM_CoffeeShop') IS NOT NULL
    THROW 51000, N'Database HRM_CoffeeShop đã tồn tại. Script config.sql chỉ dùng cho database mới; không tự động xóa database.', 1;
CREATE DATABASE HRM_CoffeeShop;
CREATE TABLE #HrmInstallGuard (GuardId INT NOT NULL);
GO
IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;
USE HRM_CoffeeShop;
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- 2. Vai trò
IF OBJECT_ID('dbo.Role', 'U') IS NULL
CREATE TABLE dbo.Role (
    RoleId INT IDENTITY(1,1) PRIMARY KEY,
    RoleCode VARCHAR(40) NOT NULL UNIQUE,
    RoleName NVARCHAR(100) NOT NULL,
    Description NVARCHAR(300),
    IsActive BIT NOT NULL DEFAULT 1
);
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- 3. Tài khoản đăng nhập (Google)
IF OBJECT_ID('dbo.AppUser', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.AppUser (
        UserId BIGINT IDENTITY(1,1) PRIMARY KEY,
        GoogleSubject NVARCHAR(255),
        Email NVARCHAR(255) NOT NULL UNIQUE,
        DisplayName NVARCHAR(150) NOT NULL,
        AvatarUrl NVARCHAR(1000),
        PhoneNumber VARCHAR(20),
        UserStatus VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
        LastLoginAt DATETIME2,
        CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),

        CONSTRAINT CK_AppUser_Status
            CHECK (UserStatus IN ('ACTIVE','LOCKED','INACTIVE','PENDING'))
    );

    CREATE UNIQUE INDEX UX_AppUser_GoogleSubject
        ON dbo.AppUser(GoogleSubject)
        WHERE GoogleSubject IS NOT NULL;
END;
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- 4. Gán vai trò cho tài khoản
IF OBJECT_ID('dbo.UserRole', 'U') IS NULL
CREATE TABLE dbo.UserRole (
    UserId BIGINT NOT NULL,
    RoleId INT NOT NULL,
    AssignedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_UserRole PRIMARY KEY (UserId, RoleId),
    CONSTRAINT FK_UserRole_User
        FOREIGN KEY (UserId) REFERENCES dbo.AppUser(UserId),
    CONSTRAINT FK_UserRole_Role
        FOREIGN KEY (RoleId) REFERENCES dbo.Role(RoleId)
);
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- 5. Refresh token (lưu hash, hỗ trợ xoay vòng và thu hồi khi đăng xuất)
IF OBJECT_ID('dbo.RefreshToken', 'U') IS NULL
CREATE TABLE dbo.RefreshToken (
    RefreshTokenId BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserId BIGINT NOT NULL,
    TokenHash VARCHAR(64) NOT NULL UNIQUE,
    ExpiresAt DATETIME2 NOT NULL,
    RevokedAt DATETIME2,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_RefreshToken_User FOREIGN KEY (UserId) REFERENCES dbo.AppUser(UserId)
);
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- 6. Danh mục quyền chi tiết (RBAC theo permission)
IF OBJECT_ID('dbo.Permission', 'U') IS NULL
CREATE TABLE dbo.Permission (
    PermissionId INT IDENTITY(1,1) PRIMARY KEY,
    PermissionCode VARCHAR(60) NOT NULL UNIQUE,
    PermissionName NVARCHAR(150) NOT NULL
);
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- 7. Quyền mặc định của từng vai trò
IF OBJECT_ID('dbo.RolePermission', 'U') IS NULL
CREATE TABLE dbo.RolePermission (
    RoleId INT NOT NULL,
    PermissionId INT NOT NULL,

    CONSTRAINT PK_RolePermission PRIMARY KEY (RoleId, PermissionId),
    CONSTRAINT FK_RolePermission_Role
        FOREIGN KEY (RoleId) REFERENCES dbo.Role(RoleId),
    CONSTRAINT FK_RolePermission_Permission
        FOREIGN KEY (PermissionId) REFERENCES dbo.Permission(PermissionId)
);
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- 8. Quyền gán trực tiếp cho người dùng (cách cấp "HR": HR là tập quyền, không phải role)
IF OBJECT_ID('dbo.UserPermission', 'U') IS NULL
CREATE TABLE dbo.UserPermission (
    UserId BIGINT NOT NULL,
    PermissionId INT NOT NULL,
    GrantedBy BIGINT NULL,
    GrantedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT PK_UserPermission PRIMARY KEY (UserId, PermissionId),
    CONSTRAINT FK_UserPermission_User
        FOREIGN KEY (UserId) REFERENCES dbo.AppUser(UserId),
    CONSTRAINT FK_UserPermission_Permission
        FOREIGN KEY (PermissionId) REFERENCES dbo.Permission(PermissionId)
);
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- 9. Thông tin cửa hàng
IF OBJECT_ID('dbo.Store', 'U') IS NULL
CREATE TABLE dbo.Store (
    StoreId INT IDENTITY(1,1) PRIMARY KEY,
    StoreCode VARCHAR(30) NOT NULL UNIQUE,
    Name NVARCHAR(150) NOT NULL,
    AddressLine NVARCHAR(300) NOT NULL,
    Latitude DECIMAL(10,7) NOT NULL,
    Longitude DECIMAL(10,7) NOT NULL,
    AttendanceRadiusMeters INT NOT NULL DEFAULT 30,
    CheckInEarlyMinutes INT NOT NULL DEFAULT 15,
    GraceMinutes INT NOT NULL DEFAULT 5,
    MonthlyGraceLimit INT NOT NULL DEFAULT 3,
    PhotoRetentionMonths INT NOT NULL DEFAULT 12,
    GpsMaxAccuracyMeters INT NOT NULL DEFAULT 50,
    DirectorApprovalThreshold INT NOT NULL DEFAULT 0,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT CK_Store_Geofence CHECK (AttendanceRadiusMeters BETWEEN 15 AND 50),
    CONSTRAINT CK_Store_EarlyCheckIn CHECK (CheckInEarlyMinutes BETWEEN 15 AND 30),
    CONSTRAINT CK_Store_Grace CHECK (GraceMinutes BETWEEN 3 AND 5),
    CONSTRAINT CK_Store_GraceLimit CHECK (MonthlyGraceLimit BETWEEN 3 AND 5),
    CONSTRAINT CK_Store_Retention CHECK (PhotoRetentionMonths BETWEEN 6 AND 12),
    CONSTRAINT CK_Store_GpsAccuracy CHECK (GpsMaxAccuracyMeters BETWEEN 5 AND 200),
    CONSTRAINT CK_Store_DirectorThreshold CHECK (DirectorApprovalThreshold >= 0)
);
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- Cấu hình nhắc việc (SRS 7.4 ReminderRule)
IF OBJECT_ID('dbo.ReminderRule', 'U') IS NULL
CREATE TABLE dbo.ReminderRule (
    ReminderRuleId INT IDENTITY(1,1) PRIMARY KEY,
    RuleCode VARCHAR(40) NOT NULL UNIQUE,
    RuleName NVARCHAR(150) NOT NULL,
    LeadMinutes INT NULL,
    IntervalMinutes INT NULL,
    MaxAttempts INT NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    CONSTRAINT CK_ReminderRule_Lead CHECK (LeadMinutes IS NULL OR LeadMinutes BETWEEN 5 AND 120),
    CONSTRAINT CK_ReminderRule_Interval CHECK (IntervalMinutes IS NULL OR IntervalMinutes BETWEEN 1 AND 60),
    CONSTRAINT CK_ReminderRule_Max CHECK (MaxAttempts IS NULL OR MaxAttempts BETWEEN 1 AND 10)
);
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- 9b. Danh mục chức vụ (SRS 7.3, 9.3)
CREATE TABLE dbo.JobPosition (
    PositionId INT IDENTITY(1,1) PRIMARY KEY,
    PositionCode VARCHAR(40) NOT NULL UNIQUE,
    PositionName NVARCHAR(100) NOT NULL UNIQUE,
    Description NVARCHAR(500),
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- 10. Hồ sơ nhân viên
IF OBJECT_ID('dbo.Employee', 'U') IS NULL
CREATE TABLE dbo.Employee (
    EmployeeId BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserId BIGINT NOT NULL UNIQUE,
    EmployeeCode VARCHAR(30) NOT NULL UNIQUE,
    StoreId INT NOT NULL,
    JobTitle NVARCHAR(100) NOT NULL,
    PositionId INT NOT NULL,
    EmploymentType VARCHAR(20) NOT NULL DEFAULT 'FULL_TIME',
    EmploymentStatus VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    DateOfBirth DATE,
    HireDate DATE NOT NULL,
    IdentityNumber NVARCHAR(50),
    Address NVARCHAR(300),
    EmergencyContact NVARCHAR(150),
    ProfileStatus VARCHAR(20) NOT NULL DEFAULT 'INCOMPLETE',
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT FK_Employee_User
        FOREIGN KEY (UserId) REFERENCES dbo.AppUser(UserId),
    CONSTRAINT FK_Employee_Position
        FOREIGN KEY (PositionId) REFERENCES dbo.JobPosition(PositionId),
    CONSTRAINT FK_Employee_Store
        FOREIGN KEY (StoreId) REFERENCES dbo.Store(StoreId),
    CONSTRAINT CK_Employee_Type
        CHECK (EmploymentType IN
            ('FULL_TIME','PART_TIME','TEMPORARY','PROBATION')),
    CONSTRAINT CK_Employee_Status
        CHECK (EmploymentStatus IN
            ('ACTIVE','ON_LEAVE','SUSPENDED','RESIGNED')),
    CONSTRAINT CK_Employee_Profile
        CHECK (ProfileStatus IN ('COMPLETE','INCOMPLETE','UNDER_REVIEW'))
);
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- 11. Loại giấy tờ cần nộp
IF OBJECT_ID('dbo.DocumentType', 'U') IS NULL
CREATE TABLE dbo.DocumentType (
    DocumentTypeId INT IDENTITY(1,1) PRIMARY KEY,
    DocumentCode VARCHAR(40) NOT NULL UNIQUE,
    DocumentName NVARCHAR(150) NOT NULL,
    IsActive BIT NOT NULL DEFAULT 1
);
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- 11b. Yêu cầu hồ sơ theo chức vụ (SRS 7.4, 9.4)
CREATE TABLE dbo.PositionDocumentRequirement (
    RequirementId INT IDENTITY(1,1) PRIMARY KEY,
    PositionId INT NOT NULL,
    DocumentTypeId INT NOT NULL,
    IsMandatory BIT NOT NULL DEFAULT 1,
    EffectiveFrom DATE NOT NULL DEFAULT CAST(SYSUTCDATETIME() AS DATE),
    EffectiveTo DATE NULL,
    CONSTRAINT FK_PDR_Position FOREIGN KEY (PositionId) REFERENCES dbo.JobPosition(PositionId),
    CONSTRAINT FK_PDR_DocType FOREIGN KEY (DocumentTypeId) REFERENCES dbo.DocumentType(DocumentTypeId),
    CONSTRAINT UQ_PDR UNIQUE (PositionId, DocumentTypeId, EffectiveFrom),
    CONSTRAINT CK_PDR_Dates CHECK (EffectiveTo IS NULL OR EffectiveTo >= EffectiveFrom)
);
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- 12. Giấy tờ nhân viên đã nộp
IF OBJECT_ID('dbo.EmployeeDocument', 'U') IS NULL
CREATE TABLE dbo.EmployeeDocument (
    EmployeeDocumentId BIGINT IDENTITY(1,1) PRIMARY KEY,
    EmployeeId BIGINT NOT NULL,
    DocumentTypeId INT NOT NULL,
    FileName NVARCHAR(255) NOT NULL,
    StorageKey NVARCHAR(1000) NOT NULL,
    ReviewStatus VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    ReviewedBy BIGINT,
    ReviewedAt DATETIME2,
    ExpiresAt DATE,
    IssuedAt DATE,
    UploadedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    RejectionReason NVARCHAR(500),

    CONSTRAINT FK_Document_Employee
        FOREIGN KEY (EmployeeId) REFERENCES dbo.Employee(EmployeeId),
    CONSTRAINT FK_Document_Type
        FOREIGN KEY (DocumentTypeId) REFERENCES dbo.DocumentType(DocumentTypeId),
    CONSTRAINT FK_Document_Reviewer
        FOREIGN KEY (ReviewedBy) REFERENCES dbo.AppUser(UserId),
    CONSTRAINT CK_Document_Status
        CHECK (ReviewStatus IN ('PENDING','APPROVED','REJECTED','EXPIRED'))
);
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- 13. Thiết bị được đăng ký để chấm công
IF OBJECT_ID('dbo.AttendanceDevice', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.AttendanceDevice (
        DeviceId BIGINT IDENTITY(1,1) PRIMARY KEY,
        EmployeeId BIGINT NOT NULL,
        DeviceFingerprint VARCHAR(256) NOT NULL,
        DeviceName NVARCHAR(150),
        Platform VARCHAR(20),
        Status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
        RequestedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        ApprovedBy BIGINT,
        ApprovedAt DATETIME2,
        LockedAt DATETIME2,
        LockReason NVARCHAR(300),
        RevokedAt DATETIME2,

        CONSTRAINT FK_Device_Employee
            FOREIGN KEY (EmployeeId) REFERENCES dbo.Employee(EmployeeId),
        CONSTRAINT FK_Device_Approver
            FOREIGN KEY (ApprovedBy) REFERENCES dbo.AppUser(UserId),
        CONSTRAINT CK_Device_Status
            CHECK (Status IN ('PENDING','ACTIVE','LOCKED','REJECTED','REVOKED')),
        CONSTRAINT CK_Device_Platform
            CHECK (Platform IS NULL OR Platform IN ('ANDROID','IOS','WEB','OTHER'))
    );

    -- Mỗi nhân viên chỉ có một thiết bị hoạt động
    CREATE UNIQUE INDEX UX_AttendanceDevice_OneActive
        ON dbo.AttendanceDevice(EmployeeId)
        WHERE Status = 'ACTIVE';
END;
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- 14. Mẫu ca làm việc
IF OBJECT_ID('dbo.WorkShift', 'U') IS NULL
CREATE TABLE dbo.WorkShift (
    WorkShiftId INT IDENTITY(1,1) PRIMARY KEY,
    StoreId INT NOT NULL,
    ShiftCode VARCHAR(30) NOT NULL,
    ShiftName NVARCHAR(100) NOT NULL,
    StartTime TIME NOT NULL,
    EndTime TIME NOT NULL,
    BreakMinutes SMALLINT NOT NULL DEFAULT 0,
    EarlyCheckInMinutes SMALLINT NOT NULL DEFAULT 30,
    GraceMinutes SMALLINT NOT NULL DEFAULT 5,
    IsActive BIT NOT NULL DEFAULT 1,

    CONSTRAINT FK_Shift_Store
        FOREIGN KEY (StoreId) REFERENCES dbo.Store(StoreId),
    CONSTRAINT UQ_Shift_Code UNIQUE (StoreId, ShiftCode),
    CONSTRAINT CK_Shift_Break CHECK (BreakMinutes >= 0),
    CONSTRAINT CK_Shift_Early CHECK (EarlyCheckInMinutes BETWEEN 15 AND 30),
    CONSTRAINT CK_Shift_Grace CHECK (GraceMinutes BETWEEN 3 AND 5)
);
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- 15. Lịch làm việc của nhân viên
IF OBJECT_ID('dbo.ShiftAssignment', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ShiftAssignment (
        ShiftAssignmentId BIGINT IDENTITY(1,1) PRIMARY KEY,
        EmployeeId BIGINT NOT NULL,
        WorkShiftId INT NOT NULL,
        WorkDate DATE NOT NULL,
        PlannedStartAt DATETIME2 NOT NULL,
        PlannedEndAt DATETIME2 NOT NULL,
        ScheduleStatus VARCHAR(20) NOT NULL DEFAULT 'PUBLISHED',
        CreatedBy BIGINT NOT NULL,
        CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        Note NVARCHAR(500),

        CONSTRAINT FK_Schedule_Employee
            FOREIGN KEY (EmployeeId) REFERENCES dbo.Employee(EmployeeId),
        CONSTRAINT FK_Schedule_Shift
            FOREIGN KEY (WorkShiftId) REFERENCES dbo.WorkShift(WorkShiftId),
        CONSTRAINT FK_Schedule_Creator
            FOREIGN KEY (CreatedBy) REFERENCES dbo.AppUser(UserId),
        CONSTRAINT CK_Schedule_Time CHECK (PlannedEndAt > PlannedStartAt),
        CONSTRAINT CK_Schedule_Status
            CHECK (ScheduleStatus IN ('DRAFT','PUBLISHED','CANCELLED','COMPLETED'))
    );

    CREATE INDEX IX_Schedule_Employee_Date
        ON dbo.ShiftAssignment(EmployeeId, WorkDate);
END;
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- 16. Đơn xin làm thêm giờ
IF OBJECT_ID('dbo.OvertimeRequest', 'U') IS NULL
CREATE TABLE dbo.OvertimeRequest (
    OvertimeRequestId BIGINT IDENTITY(1,1) PRIMARY KEY,
    RowVersion BIGINT NOT NULL DEFAULT 0,  -- khóa lạc quan (JPA @Version): chống duyệt đồng thời
    ShiftAssignmentId BIGINT NOT NULL,
    EmployeeId BIGINT NOT NULL,
    RequestedStartAt DATETIME2 NOT NULL,
    RequestedEndAt DATETIME2 NOT NULL,
    Reason NVARCHAR(500) NOT NULL,
    ApprovalStatus VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    RequestedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    ReviewedBy BIGINT,
    ReviewedAt DATETIME2,
    ReviewNote NVARCHAR(500),

    CONSTRAINT FK_OT_Schedule
        FOREIGN KEY (ShiftAssignmentId) REFERENCES dbo.ShiftAssignment(ShiftAssignmentId),
    CONSTRAINT FK_OT_Employee
        FOREIGN KEY (EmployeeId) REFERENCES dbo.Employee(EmployeeId),
    CONSTRAINT FK_OT_Reviewer
        FOREIGN KEY (ReviewedBy) REFERENCES dbo.AppUser(UserId),
    CONSTRAINT CK_OT_Time CHECK (RequestedEndAt > RequestedStartAt),
    CONSTRAINT CK_OT_Status
        CHECK (ApprovalStatus IN ('PENDING','APPROVED','REJECTED','CANCELLED'))
);
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- 17. Bản ghi chấm công của một ca
IF OBJECT_ID('dbo.Attendance', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Attendance (
        AttendanceId BIGINT IDENTITY(1,1) PRIMARY KEY,
        ShiftAssignmentId BIGINT NOT NULL UNIQUE,
        EmployeeId BIGINT NOT NULL,

        CheckInAt DATETIME2,
        CheckOutAt DATETIME2,

        CheckInLatitude DECIMAL(10,7),
        CheckInLongitude DECIMAL(10,7),
        CheckInAccuracyM DECIMAL(8,2),

        CheckOutLatitude DECIMAL(10,7),
        CheckOutLongitude DECIMAL(10,7),
        CheckOutAccuracyM DECIMAL(8,2),

        CheckInMethod VARCHAR(20),
        CheckOutMethod VARCHAR(20),
        CheckInFaceStatus VARCHAR(20),
        CheckOutFaceStatus VARCHAR(20),

        AttendanceStatus VARCHAR(25) NOT NULL DEFAULT 'IN_PROGRESS',
        LateMinutes INT NOT NULL DEFAULT 0,
        EarlyLeaveMinutes INT NOT NULL DEFAULT 0,
        WorkedMinutes INT,
        ApprovedOTMinutes INT NOT NULL DEFAULT 0,

        ManagerReviewedBy BIGINT,
        ManagerReviewedAt DATETIME2,
        PayrollStatus VARCHAR(20) NOT NULL DEFAULT 'OPEN',

        Note NVARCHAR(500),
        CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),

        -- Idempotency (retry an toàn), thiết bị chấm công, ân hạn đi muộn
        CheckInIdempotencyKey VARCHAR(100),
        CheckOutIdempotencyKey VARCHAR(100),
        CheckInDeviceId BIGINT,
        CheckOutDeviceId BIGINT,
        GraceApplied BIT NOT NULL DEFAULT 0,

        CONSTRAINT FK_Attendance_Schedule
            FOREIGN KEY (ShiftAssignmentId) REFERENCES dbo.ShiftAssignment(ShiftAssignmentId),
        CONSTRAINT FK_Attendance_Employee
            FOREIGN KEY (EmployeeId) REFERENCES dbo.Employee(EmployeeId),
        CONSTRAINT FK_Attendance_Manager
            FOREIGN KEY (ManagerReviewedBy) REFERENCES dbo.AppUser(UserId),

        CONSTRAINT CK_Attendance_Time
            CHECK (CheckOutAt IS NULL OR CheckInAt IS NULL OR CheckOutAt >= CheckInAt),
        CONSTRAINT CK_Attendance_Status
            CHECK (AttendanceStatus IN
                ('IN_PROGRESS','PRESENT','LATE','EARLY_LEAVE',
                 'EXPLANATION_PENDING','APPROVED_EXCEPTION')),
        CONSTRAINT CK_Attendance_Payroll
            CHECK (PayrollStatus IN ('OPEN','MANAGER_APPROVED','HR_APPROVED','LOCKED')),
        CONSTRAINT CK_Attendance_CheckInMethod
            CHECK (CheckInMethod IS NULL OR CheckInMethod IN
                ('GPS','STORE_QR','INTERNAL_WIFI','MANUAL_APPROVAL')),
        CONSTRAINT CK_Attendance_CheckOutMethod
            CHECK (CheckOutMethod IS NULL OR CheckOutMethod IN
                ('GPS','STORE_QR','INTERNAL_WIFI','MANUAL_APPROVAL'))
    );

    CREATE INDEX IX_Attendance_Employee
        ON dbo.Attendance(EmployeeId, CheckInAt);

    CREATE INDEX IX_Attendance_Status
        ON dbo.Attendance(AttendanceStatus, PayrollStatus);
END;
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- 18. Ảnh và bằng chứng chấm công
IF OBJECT_ID('dbo.AttendanceVerification', 'U') IS NULL
CREATE TABLE dbo.AttendanceVerification (
    VerificationId BIGINT IDENTITY(1,1) PRIMARY KEY,
    AttendanceId BIGINT NOT NULL,
    DeviceId BIGINT NULL,
    VerificationType VARCHAR(30) NOT NULL,
    EventType VARCHAR(20) NOT NULL,
    Latitude DECIMAL(10,7) NULL,
    Longitude DECIMAL(10,7) NULL,
    AccuracyMeters DECIMAL(8,2) NULL,
    DistanceMeters DECIMAL(8,2) NULL,
    EvidenceStorageKey NVARCHAR(1000) NULL,
    VerificationStatus VARCHAR(20) NOT NULL,
    FailureReason NVARCHAR(500) NULL,
    VerifiedAt DATETIME2 NOT NULL,
    ContentHash VARCHAR(128) NULL,
    AiProvider NVARCHAR(100) NULL,
    AiResultJson NVARCHAR(MAX) NULL,
    RetainUntil DATE NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT FK_Verification_Attendance FOREIGN KEY (AttendanceId) REFERENCES dbo.Attendance(AttendanceId),
    CONSTRAINT FK_Verification_Device FOREIGN KEY (DeviceId) REFERENCES dbo.AttendanceDevice(DeviceId),
    CONSTRAINT CK_Verification_Type CHECK (VerificationType IN ('GPS','DEVICE','PHOTO','FACE_LIVENESS','QR','WIFI')),
    CONSTRAINT CK_Verification_Event CHECK (EventType IN ('CHECK_IN','CHECK_OUT')),
    CONSTRAINT CK_Verification_Status CHECK (VerificationStatus IN ('PASSED','FAILED','REVIEW_REQUIRED','EXEMPTED'))
);

GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- 19. Đơn giải trình chấm công
IF OBJECT_ID('dbo.AttendanceExceptionRequest', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.AttendanceExceptionRequest (
        ExceptionRequestId BIGINT IDENTITY(1,1) PRIMARY KEY,
    RowVersion BIGINT NOT NULL DEFAULT 0,  -- khóa lạc quan (JPA @Version): chống duyệt đồng thời
        EmployeeId BIGINT NOT NULL,
        ShiftAssignmentId BIGINT,
        AttendanceId BIGINT,
        RequestType VARCHAR(30) NOT NULL,
        RequestedCheckInAt DATETIME2,
        RequestedCheckOutAt DATETIME2,
        Reason NVARCHAR(1000) NOT NULL,
        RequestStatus VARCHAR(20) NOT NULL DEFAULT 'PENDING',
        SubmittedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        ReviewedBy BIGINT,
        ReviewedAt DATETIME2,
        ReviewNote NVARCHAR(1000),
        EvidenceStorageKey NVARCHAR(1000) NULL,
        RetainUntil DATE NULL,

        CONSTRAINT FK_Exception_Employee
            FOREIGN KEY (EmployeeId) REFERENCES dbo.Employee(EmployeeId),
        CONSTRAINT FK_Exception_Schedule
            FOREIGN KEY (ShiftAssignmentId) REFERENCES dbo.ShiftAssignment(ShiftAssignmentId),
        CONSTRAINT FK_Exception_Attendance
            FOREIGN KEY (AttendanceId) REFERENCES dbo.Attendance(AttendanceId),
        CONSTRAINT FK_Exception_Reviewer
            FOREIGN KEY (ReviewedBy) REFERENCES dbo.AppUser(UserId),
        CONSTRAINT CK_Exception_Type
            CHECK (RequestType IN
                ('NO_GPS','MISSED_CHECK_IN','MISSED_CHECK_OUT','BUSINESS_TRIP',
                 'DEVICE_ISSUE','CAMERA_ISSUE','OTHER','ABSENCE')),
        CONSTRAINT CK_Exception_Status
            CHECK (RequestStatus IN ('PENDING','APPROVED','REJECTED','CANCELLED'))
    );

    CREATE INDEX IX_Exception_Status
        ON dbo.AttendanceExceptionRequest(RequestStatus, SubmittedAt);
END;
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- 20. Đơn yêu cầu điều chỉnh công
IF OBJECT_ID('dbo.AttendanceAdjustmentRequest', 'U') IS NULL
CREATE TABLE dbo.AttendanceAdjustmentRequest (
    AttendanceAdjustmentRequestId BIGINT IDENTITY(1,1) PRIMARY KEY,
    RowVersion BIGINT NOT NULL DEFAULT 0,  -- khóa lạc quan (JPA @Version): chống duyệt đồng thời
    AttendanceId BIGINT NOT NULL,
    RequestedBy BIGINT NOT NULL,
    FieldName VARCHAR(40) NOT NULL,
    OldValue NVARCHAR(100),
    NewValue NVARCHAR(100) NOT NULL,
    Reason NVARCHAR(1000) NOT NULL,
    EvidenceStorageKey NVARCHAR(1000),

    ManagerStatus VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    ManagerReviewedBy BIGINT,
    ManagerReviewedAt DATETIME2,

    HrStatus VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    HrReviewedBy BIGINT,
    HrReviewedAt DATETIME2,

    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT FK_Adjustment_Attendance
        FOREIGN KEY (AttendanceId) REFERENCES dbo.Attendance(AttendanceId),
    CONSTRAINT FK_Adjustment_Requester
        FOREIGN KEY (RequestedBy) REFERENCES dbo.AppUser(UserId),
    CONSTRAINT FK_Adjustment_Manager
        FOREIGN KEY (ManagerReviewedBy) REFERENCES dbo.AppUser(UserId),
    CONSTRAINT FK_Adjustment_HR
        FOREIGN KEY (HrReviewedBy) REFERENCES dbo.AppUser(UserId),
    CONSTRAINT CK_Adjustment_Field
        CHECK (FieldName IN
            ('CHECK_IN','CHECK_OUT','WORKED_MINUTES','LATE_MINUTES','EARLY_LEAVE_MINUTES')),
    CONSTRAINT CK_Adjustment_ManagerStatus
        CHECK (ManagerStatus IN ('PENDING','APPROVED','REJECTED')),
    CONSTRAINT CK_Adjustment_HrStatus
        CHECK (HrStatus IN ('PENDING','APPROVED','REJECTED'))
);
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- Lịch sử giá trị chấm công trước/sau khi điều chỉnh (SRS 7.4 AttendanceAdjustmentHistory)
IF OBJECT_ID('dbo.AttendanceAdjustmentHistory', 'U') IS NULL
CREATE TABLE dbo.AttendanceAdjustmentHistory (
    AdjustmentHistoryId BIGINT IDENTITY(1,1) PRIMARY KEY,
    AttendanceAdjustmentRequestId BIGINT NOT NULL,
    AttendanceId BIGINT NOT NULL,
    FieldName VARCHAR(40) NOT NULL,
    OldValue NVARCHAR(100),
    NewValue NVARCHAR(100),
    ChangedBy BIGINT NOT NULL,
    ChangedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_AdjHistory_Request FOREIGN KEY (AttendanceAdjustmentRequestId)
        REFERENCES dbo.AttendanceAdjustmentRequest(AttendanceAdjustmentRequestId),
    CONSTRAINT FK_AdjHistory_Attendance FOREIGN KEY (AttendanceId) REFERENCES dbo.Attendance(AttendanceId),
    CONSTRAINT FK_AdjHistory_User FOREIGN KEY (ChangedBy) REFERENCES dbo.AppUser(UserId)
);

GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- 21. Mẫu checklist
IF OBJECT_ID('dbo.ChecklistTemplate', 'U') IS NULL
CREATE TABLE dbo.ChecklistTemplate (
    ChecklistTemplateId INT IDENTITY(1,1) PRIMARY KEY,
    StoreId INT NOT NULL,
    ChecklistCode VARCHAR(40) NOT NULL,
    ChecklistName NVARCHAR(150) NOT NULL,
    ChecklistType VARCHAR(20) NOT NULL,
    IsManagerApprovalRequired BIT NOT NULL DEFAULT 0,
    Version INT NOT NULL DEFAULT 1,
    IsActive BIT NOT NULL DEFAULT 1,

    CONSTRAINT FK_ChecklistTemplate_Store
        FOREIGN KEY (StoreId) REFERENCES dbo.Store(StoreId),
    CONSTRAINT UQ_ChecklistTemplate_Code UNIQUE (StoreId, ChecklistCode, Version),
    CONSTRAINT CK_ChecklistTemplate_Type
        CHECK (ChecklistType IN ('OPENING','CLOSING','HANDOVER','SERVICE','INVENTORY'))
);
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- 22. Các công việc bên trong checklist
IF OBJECT_ID('dbo.ChecklistTemplateItem', 'U') IS NULL
CREATE TABLE dbo.ChecklistTemplateItem (
    ChecklistTemplateItemId INT IDENTITY(1,1) PRIMARY KEY,
    ChecklistTemplateId INT NOT NULL,
    ItemName NVARCHAR(200) NOT NULL,
    Instructions NVARCHAR(500),
    IsMandatory BIT NOT NULL DEFAULT 1,
    RequiresEvidence BIT NOT NULL DEFAULT 0,
    RequiresManagerApproval BIT NOT NULL DEFAULT 0,
    SortOrder INT NOT NULL DEFAULT 1,

    CONSTRAINT FK_ChecklistItem_Template
        FOREIGN KEY (ChecklistTemplateId)
        REFERENCES dbo.ChecklistTemplate(ChecklistTemplateId)
);
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- 23. Một lần thực hiện checklist
-- Nhóm checklist theo mẫu, ngày và ca (SRS 7.4 ChecklistInstance)
IF OBJECT_ID('dbo.ChecklistInstance', 'U') IS NULL
CREATE TABLE dbo.ChecklistInstance (
    ChecklistInstanceId BIGINT IDENTITY(1,1) PRIMARY KEY,
    ChecklistTemplateId INT NOT NULL,
    WorkDate DATE NOT NULL,
    WorkShiftId INT NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_ChecklistInstance_Template FOREIGN KEY (ChecklistTemplateId)
        REFERENCES dbo.ChecklistTemplate(ChecklistTemplateId),
    CONSTRAINT FK_ChecklistInstance_Shift FOREIGN KEY (WorkShiftId)
        REFERENCES dbo.WorkShift(WorkShiftId)
);
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

IF OBJECT_ID('dbo.ChecklistTask', 'U') IS NULL
CREATE TABLE dbo.ChecklistTask (
    ChecklistTaskId BIGINT IDENTITY(1,1) PRIMARY KEY,
    ChecklistTemplateId INT NOT NULL,
    ShiftAssignmentId BIGINT,
    EmployeeId BIGINT NOT NULL,
    DueAt DATETIME2 NOT NULL,
    StartedAt DATETIME2,
    SubmittedAt DATETIME2,
    RunStatus VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    ManagerStatus VARCHAR(20) NOT NULL DEFAULT 'NOT_REQUIRED',
    ChecklistInstanceId BIGINT NULL,

    CONSTRAINT FK_ChecklistRun_Template
        FOREIGN KEY (ChecklistTemplateId) REFERENCES dbo.ChecklistTemplate(ChecklistTemplateId),
    CONSTRAINT FK_ChecklistRun_Schedule
        FOREIGN KEY (ShiftAssignmentId) REFERENCES dbo.ShiftAssignment(ShiftAssignmentId),
    CONSTRAINT FK_ChecklistRun_Employee
        FOREIGN KEY (EmployeeId) REFERENCES dbo.Employee(EmployeeId),
    CONSTRAINT FK_ChecklistTask_Instance
        FOREIGN KEY (ChecklistInstanceId) REFERENCES dbo.ChecklistInstance(ChecklistInstanceId),
    CONSTRAINT CK_ChecklistRun_Status
        CHECK (RunStatus IN
            ('PENDING','IN_PROGRESS','SUBMITTED','OVERDUE','APPROVED','REJECTED','WAIVED')),
    CONSTRAINT CK_ChecklistRun_ManagerStatus
        CHECK (ManagerStatus IN ('NOT_REQUIRED','PENDING','APPROVED','REJECTED'))
);
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- 24. Trạng thái từng mục checklist
IF OBJECT_ID('dbo.ChecklistTaskItem', 'U') IS NULL
CREATE TABLE dbo.ChecklistTaskItem (
    ChecklistTaskItemId BIGINT IDENTITY(1,1) PRIMARY KEY,
    ChecklistTaskId BIGINT NOT NULL,
    ChecklistTemplateItemId INT NOT NULL,
    IsCompleted BIT NOT NULL DEFAULT 0,
    CompletedAt DATETIME2,
    CompletedBy BIGINT,
    Note NVARCHAR(500),

    CONSTRAINT FK_ChecklistRunItem_Run
        FOREIGN KEY (ChecklistTaskId) REFERENCES dbo.ChecklistTask(ChecklistTaskId),
    CONSTRAINT FK_ChecklistRunItem_Template
        FOREIGN KEY (ChecklistTemplateItemId)
        REFERENCES dbo.ChecklistTemplateItem(ChecklistTemplateItemId),
    CONSTRAINT FK_ChecklistRunItem_User
        FOREIGN KEY (CompletedBy) REFERENCES dbo.AppUser(UserId),
    CONSTRAINT UQ_ChecklistRunItem UNIQUE (ChecklistTaskId, ChecklistTemplateItemId)
);
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- Minh chứng của từng mục checklist (SRS 7.4 ChecklistEvidence): mỗi minh chứng một dòng
IF OBJECT_ID('dbo.ChecklistEvidence', 'U') IS NULL
CREATE TABLE dbo.ChecklistEvidence (
    ChecklistEvidenceId BIGINT IDENTITY(1,1) PRIMARY KEY,
    ChecklistTaskId BIGINT NOT NULL,
    ChecklistTaskItemId BIGINT NULL,
    StorageKey NVARCHAR(1000) NOT NULL,
    UploadedBy BIGINT NULL,
    UploadedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_ChecklistEvidence_Task FOREIGN KEY (ChecklistTaskId)
        REFERENCES dbo.ChecklistTask(ChecklistTaskId),
    CONSTRAINT FK_ChecklistEvidence_Item FOREIGN KEY (ChecklistTaskItemId)
        REFERENCES dbo.ChecklistTaskItem(ChecklistTaskItemId),
    CONSTRAINT FK_ChecklistEvidence_User FOREIGN KEY (UploadedBy)
        REFERENCES dbo.AppUser(UserId)
);
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- Lịch sử duyệt/từ chối checklist (SRS 7.4 ChecklistReview): mỗi lần duyệt một dòng
IF OBJECT_ID('dbo.ChecklistReview', 'U') IS NULL
CREATE TABLE dbo.ChecklistReview (
    ChecklistReviewId BIGINT IDENTITY(1,1) PRIMARY KEY,
    ChecklistTaskId BIGINT NOT NULL,
    ReviewerId BIGINT NOT NULL,
    Decision VARCHAR(20) NOT NULL,
    Reason NVARCHAR(500),
    ReviewedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_ChecklistReview_Task FOREIGN KEY (ChecklistTaskId)
        REFERENCES dbo.ChecklistTask(ChecklistTaskId),
    CONSTRAINT FK_ChecklistReview_Reviewer FOREIGN KEY (ReviewerId)
        REFERENCES dbo.AppUser(UserId),
    CONSTRAINT CK_ChecklistReview_Decision CHECK (Decision IN ('APPROVED','REJECTED'))
);
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- 25. Khóa đào tạo
IF OBJECT_ID('dbo.TrainingCourse', 'U') IS NULL
CREATE TABLE dbo.TrainingCourse (
    CourseId INT IDENTITY(1,1) PRIMARY KEY,
    CourseCode VARCHAR(40) NOT NULL UNIQUE,
    CourseName NVARCHAR(200) NOT NULL,
    Description NVARCHAR(1000),
    PassingScore DECIMAL(5,2) NOT NULL DEFAULT 80,
    ValidityMonths INT NULL,
    IsMandatoryTest BIT NOT NULL DEFAULT 1,
    IsActive BIT NOT NULL DEFAULT 1,

    CONSTRAINT CK_TrainingCourse_PassingScore CHECK (PassingScore BETWEEN 0 AND 100),
    CONSTRAINT CK_TrainingCourse_Validity CHECK (ValidityMonths IS NULL OR ValidityMonths > 0)
);
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- 25b. Yêu cầu đào tạo theo chức vụ (SRS 7.4, 9.7)
CREATE TABLE dbo.PositionTrainingRequirement (
    RequirementId INT IDENTITY(1,1) PRIMARY KEY,
    PositionId INT NOT NULL,
    CourseId INT NOT NULL,
    IsMandatory BIT NOT NULL DEFAULT 1,
    BlocksShiftAssignment BIT NOT NULL DEFAULT 1,
    EffectiveFrom DATE NOT NULL DEFAULT CAST(SYSUTCDATETIME() AS DATE),
    EffectiveTo DATE NULL,
    CONSTRAINT FK_PTR_Position FOREIGN KEY (PositionId) REFERENCES dbo.JobPosition(PositionId),
    CONSTRAINT FK_PTR_Course FOREIGN KEY (CourseId) REFERENCES dbo.TrainingCourse(CourseId),
    CONSTRAINT UQ_PTR UNIQUE (PositionId, CourseId, EffectiveFrom),
    CONSTRAINT CK_PTR_Dates CHECK (EffectiveTo IS NULL OR EffectiveTo >= EffectiveFrom)
);
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- 25c. Lịch sử lượt thi (SRS 7.4, BR training attempts)
CREATE TABLE dbo.TrainingAttempt (
    AttemptId BIGINT IDENTITY(1,1) PRIMARY KEY,
    EmployeeId BIGINT NOT NULL,
    CourseId INT NOT NULL,
    AttemptNo INT NOT NULL,
    Score DECIMAL(5,2) NULL,
    IsPassed BIT NOT NULL,
    Source VARCHAR(10) NOT NULL DEFAULT 'MANUAL',
    RecordedBy BIGINT NULL,
    RecordedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Attempt_Employee FOREIGN KEY (EmployeeId) REFERENCES dbo.Employee(EmployeeId),
    CONSTRAINT FK_Attempt_Course FOREIGN KEY (CourseId) REFERENCES dbo.TrainingCourse(CourseId),
    CONSTRAINT FK_Attempt_Recorder FOREIGN KEY (RecordedBy) REFERENCES dbo.AppUser(UserId),
    CONSTRAINT UQ_Attempt_No UNIQUE (EmployeeId, CourseId, AttemptNo),
    CONSTRAINT CK_Attempt_Source CHECK (Source IN ('MANUAL','LMS')),
    CONSTRAINT CK_Attempt_Score CHECK (Score IS NULL OR Score BETWEEN 0 AND 100)
);
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- 26. Tiến độ đào tạo của nhân viên
IF OBJECT_ID('dbo.EmployeeTraining', 'U') IS NULL
CREATE TABLE dbo.EmployeeTraining (
    EmployeeTrainingId BIGINT IDENTITY(1,1) PRIMARY KEY,
    EmployeeId BIGINT NOT NULL,
    CourseId INT NOT NULL,
    AssignedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    DueAt DATETIME2,
    CompletedAt DATETIME2,
    ExpiresAt DATETIME2,
    TestScore DECIMAL(5,2),
    TrainingStatus VARCHAR(20) NOT NULL DEFAULT 'NOT_STARTED',

    CONSTRAINT FK_EmployeeTraining_Employee
        FOREIGN KEY (EmployeeId) REFERENCES dbo.Employee(EmployeeId),
    CONSTRAINT FK_EmployeeTraining_Course
        FOREIGN KEY (CourseId) REFERENCES dbo.TrainingCourse(CourseId),
    CONSTRAINT UQ_EmployeeTraining UNIQUE (EmployeeId, CourseId),
    CONSTRAINT CK_EmployeeTraining_Status
        CHECK (TrainingStatus IN
            ('NOT_STARTED','IN_PROGRESS','PASSED','FAILED','EXPIRED')),
    CONSTRAINT CK_EmployeeTraining_Score
        CHECK (TestScore IS NULL OR TestScore BETWEEN 0 AND 100)
);
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- 27. Danh mục quy tắc thưởng/phạt
IF OBJECT_ID('dbo.RuleCatalog', 'U') IS NULL
CREATE TABLE dbo.RuleCatalog (
    RuleId INT IDENTITY(1,1) PRIMARY KEY,
    RuleCode VARCHAR(40) NOT NULL UNIQUE,
    RuleName NVARCHAR(150) NOT NULL,
    RuleType VARCHAR(20) NOT NULL,
    Severity VARCHAR(20) NOT NULL,
    DefaultAmount DECIMAL(12,2),
    IsAutomatic BIT NOT NULL DEFAULT 0,
    IsActive BIT NOT NULL DEFAULT 1,
    Description NVARCHAR(500),

    CONSTRAINT CK_Rule_Type CHECK (RuleType IN ('VIOLATION','REWARD')),
    CONSTRAINT CK_Rule_Severity CHECK (Severity IN ('MINOR','MAJOR','CRITICAL')),
    CONSTRAINT CK_Rule_Amount CHECK (DefaultAmount IS NULL OR DefaultAmount >= 0)
);
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- 28. Vi phạm của nhân viên
IF OBJECT_ID('dbo.ViolationEvent', 'U') IS NULL
CREATE TABLE dbo.ViolationEvent (
    ViolationEventId BIGINT IDENTITY(1,1) PRIMARY KEY,
    EmployeeId BIGINT NOT NULL,
    RuleId INT NOT NULL,
    AttendanceId BIGINT,
    ChecklistTaskId BIGINT,
    OccurredAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    SourceType VARCHAR(20) NOT NULL DEFAULT 'MANUAL',
    SourceId BIGINT NULL,
    EvidenceReference NVARCHAR(500),
    Details NVARCHAR(1000),
    RecordStatus VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    IsAutoGenerated BIT NOT NULL DEFAULT 0,
    CreatedBy BIGINT,
    ReviewedBy BIGINT,
    ReviewedAt DATETIME2,
    ReviewNote NVARCHAR(500),

    CONSTRAINT FK_Violation_Employee FOREIGN KEY (EmployeeId) REFERENCES dbo.Employee(EmployeeId),
    CONSTRAINT FK_Violation_Rule FOREIGN KEY (RuleId) REFERENCES dbo.RuleCatalog(RuleId),
    CONSTRAINT FK_Violation_Attendance FOREIGN KEY (AttendanceId) REFERENCES dbo.Attendance(AttendanceId),
    CONSTRAINT FK_Violation_Checklist FOREIGN KEY (ChecklistTaskId) REFERENCES dbo.ChecklistTask(ChecklistTaskId),
    CONSTRAINT FK_Violation_Creator FOREIGN KEY (CreatedBy) REFERENCES dbo.AppUser(UserId),
    CONSTRAINT FK_Violation_Reviewer FOREIGN KEY (ReviewedBy) REFERENCES dbo.AppUser(UserId),
    CONSTRAINT CK_Violation_Status CHECK (RecordStatus IN ('PENDING','APPROVED','REJECTED','CANCELLED','APPLIED')),
    CONSTRAINT CK_Violation_Source CHECK (SourceType IN ('ATTENDANCE','CHECKLIST','MANUAL'))
);

GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- 29. Thành tích/thưởng của nhân viên
IF OBJECT_ID('dbo.EmployeeRewardPenalty', 'U') IS NULL
CREATE TABLE dbo.EmployeeRewardPenalty (
    RewardPenaltyId BIGINT IDENTITY(1,1) PRIMARY KEY,
    RowVersion BIGINT NOT NULL DEFAULT 0,  -- khóa lạc quan (JPA @Version): chống duyệt đồng thời
    DecisionType VARCHAR(10) NOT NULL,
    EmployeeId BIGINT NOT NULL,
    RuleId INT NOT NULL,
    ViolationEventId BIGINT NULL,
    EffectiveDate DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    Details NVARCHAR(1000) NOT NULL,
    Amount DECIMAL(12,2),
    DecisionStatus VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    ProposedBy BIGINT NOT NULL,
    ApprovedBy BIGINT,
    ApprovedAt DATETIME2,
    ReviewNote NVARCHAR(500),

    CONSTRAINT FK_RewardPenalty_Employee FOREIGN KEY (EmployeeId) REFERENCES dbo.Employee(EmployeeId),
    CONSTRAINT FK_RewardPenalty_Rule FOREIGN KEY (RuleId) REFERENCES dbo.RuleCatalog(RuleId),
    CONSTRAINT FK_RewardPenalty_Violation FOREIGN KEY (ViolationEventId) REFERENCES dbo.ViolationEvent(ViolationEventId),
    CONSTRAINT FK_RewardPenalty_Creator FOREIGN KEY (ProposedBy) REFERENCES dbo.AppUser(UserId),
    CONSTRAINT FK_RewardPenalty_Reviewer FOREIGN KEY (ApprovedBy) REFERENCES dbo.AppUser(UserId),
    CONSTRAINT CK_RewardPenalty_Type CHECK (DecisionType IN ('REWARD','PENALTY')),
    CONSTRAINT CK_RewardPenalty_Status CHECK (DecisionStatus IN ('PENDING','APPROVED','REJECTED','CANCELLED','APPLIED')),
    CONSTRAINT CK_RewardPenalty_Amount CHECK (Amount IS NULL OR Amount >= 0)
);

GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- 30. Kỳ chốt công
IF OBJECT_ID('dbo.PayrollPeriod', 'U') IS NULL
CREATE TABLE dbo.PayrollPeriod (
    PayrollPeriodId BIGINT IDENTITY(1,1) PRIMARY KEY,
    PeriodCode VARCHAR(20) NOT NULL UNIQUE,
    StartDate DATE NOT NULL,
    EndDate DATE NOT NULL,
    PeriodStatus VARCHAR(20) NOT NULL DEFAULT 'OPEN',
    CreatedBy BIGINT NOT NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    ManagerApprovedBy BIGINT,
    ManagerApprovedAt DATETIME2,
    HrApprovedBy BIGINT,
    HrApprovedAt DATETIME2,
    LockedBy BIGINT,
    LockedAt DATETIME2,
    ReopenedAt DATETIME2,
    Note NVARCHAR(500),

    CONSTRAINT FK_Payroll_Creator
        FOREIGN KEY (CreatedBy) REFERENCES dbo.AppUser(UserId),
    CONSTRAINT FK_Payroll_Manager
        FOREIGN KEY (ManagerApprovedBy) REFERENCES dbo.AppUser(UserId),
    CONSTRAINT FK_Payroll_HR
        FOREIGN KEY (HrApprovedBy) REFERENCES dbo.AppUser(UserId),
    CONSTRAINT FK_Payroll_Locker
        FOREIGN KEY (LockedBy) REFERENCES dbo.AppUser(UserId),
    CONSTRAINT CK_Payroll_Dates CHECK (EndDate >= StartDate),
    CONSTRAINT CK_Payroll_Status
        CHECK (PeriodStatus IN ('OPEN','MANAGER_REVIEW','HR_REVIEW','APPROVED','LOCKED'))
);
GO


GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- 32. Thông báo
IF OBJECT_ID('dbo.Notification', 'U') IS NULL
CREATE TABLE dbo.Notification (
    NotificationId BIGINT IDENTITY(1,1) PRIMARY KEY,
    UserId BIGINT NOT NULL,
    NotificationType VARCHAR(40) NOT NULL,
    Title NVARCHAR(200) NOT NULL,
    Message NVARCHAR(1000) NOT NULL,
    RelatedEntityType VARCHAR(50),
    RelatedEntityId BIGINT,
    ScheduledAt DATETIME2,
    SentAt DATETIME2,
    ReadAt DATETIME2,
    DeliveryStatus VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    AttemptCount TINYINT NOT NULL DEFAULT 0,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),

    -- Khóa chống gửi lặp thông báo (BR-REM-03)
    DedupKey VARCHAR(200),

    CONSTRAINT FK_Notification_User
        FOREIGN KEY (UserId) REFERENCES dbo.AppUser(UserId),
    CONSTRAINT CK_Notification_Status
        CHECK (DeliveryStatus IN ('PENDING','SENT','FAILED','CANCELLED')),
    CONSTRAINT CK_Notification_Attempts CHECK (AttemptCount BETWEEN 0 AND 10)
);
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Notification_User_Read' AND object_id = OBJECT_ID('dbo.Notification'))
    CREATE INDEX IX_Notification_User_Read
        ON dbo.Notification(UserId, ReadAt, CreatedAt);
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_Notification_Dedup' AND object_id = OBJECT_ID('dbo.Notification'))
    CREATE UNIQUE INDEX UX_Notification_Dedup
        ON dbo.Notification(DedupKey)
        WHERE DedupKey IS NOT NULL;
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- 33. Nhật ký kiểm toán
IF OBJECT_ID('dbo.AuditLog', 'U') IS NULL
CREATE TABLE dbo.AuditLog (
    AuditLogId BIGINT IDENTITY(1,1) PRIMARY KEY,
    ActorUserId BIGINT,
    ActionCode VARCHAR(80) NOT NULL,
    EntityType VARCHAR(80) NOT NULL,
    EntityId NVARCHAR(100),
    BeforeJson NVARCHAR(MAX),
    AfterJson NVARCHAR(MAX),
    IpAddress VARCHAR(45),
    UserAgent NVARCHAR(500),
    CorrelationId VARCHAR(64),
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),

    CONSTRAINT FK_AuditLog_Actor
        FOREIGN KEY (ActorUserId) REFERENCES dbo.AppUser(UserId)
);
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_AuditLog_Entity' AND object_id = OBJECT_ID('dbo.AuditLog'))
    CREATE INDEX IX_AuditLog_Entity
        ON dbo.AuditLog(EntityType, EntityId, CreatedAt);
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- 8. Kỹ năng và đánh giá kỹ năng nhân viên (FR-012)
IF OBJECT_ID('dbo.Skill', 'U') IS NULL
CREATE TABLE dbo.Skill (
    SkillId INT IDENTITY(1,1) PRIMARY KEY,
    SkillCode VARCHAR(40) NOT NULL UNIQUE,
    SkillName NVARCHAR(150) NOT NULL,
    Description NVARCHAR(500),
    IsActive BIT NOT NULL DEFAULT 1
);
GO
IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

IF OBJECT_ID('dbo.EmployeeSkill', 'U') IS NULL
CREATE TABLE dbo.EmployeeSkill (
    AssessmentId BIGINT IDENTITY(1,1) PRIMARY KEY,
    EmployeeId BIGINT NOT NULL,
    SkillId INT NOT NULL,
    SkillLevel INT NOT NULL,
    Note NVARCHAR(500),
    AssessedBy BIGINT NOT NULL,
    AssessedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT CK_EmployeeSkillAssessment_Level CHECK (SkillLevel BETWEEN 1 AND 5),
    CONSTRAINT FK_SkillAssessment_Employee FOREIGN KEY (EmployeeId) REFERENCES dbo.Employee(EmployeeId),
    CONSTRAINT FK_SkillAssessment_Skill FOREIGN KEY (SkillId) REFERENCES dbo.Skill(SkillId),
    CONSTRAINT FK_SkillAssessment_Assessor FOREIGN KEY (AssessedBy) REFERENCES dbo.AppUser(UserId)
);
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- B-17: lưu các lần xác minh thất bại, không tạo Attendance giả.
IF OBJECT_ID('dbo.AttendanceVerificationAttempt', 'U') IS NULL
CREATE TABLE dbo.AttendanceVerificationAttempt (
    AttemptId          BIGINT IDENTITY(1,1) PRIMARY KEY,
    EmployeeId         BIGINT NOT NULL,
    ShiftAssignmentId  BIGINT NULL,
    EventType          VARCHAR(10) NOT NULL,
    VerificationType   VARCHAR(10) NOT NULL,
    FailureCode        VARCHAR(60) NOT NULL,
    DeviceId           BIGINT NULL,
    AttemptedAt        DATETIME2 NOT NULL,
    CONSTRAINT FK_VerifAttempt_Employee FOREIGN KEY (EmployeeId) REFERENCES dbo.Employee(EmployeeId),
    CONSTRAINT FK_VerifAttempt_Shift FOREIGN KEY (ShiftAssignmentId) REFERENCES dbo.ShiftAssignment(ShiftAssignmentId),
    CONSTRAINT CK_VerifAttempt_Event CHECK (EventType IN ('CHECK_IN','CHECK_OUT')),
    CONSTRAINT CK_VerifAttempt_Type CHECK (VerificationType IN ('GPS','FACE'))
);
GO
IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_VerifAttempt_Employee_Time')
    CREATE INDEX IX_VerifAttempt_Employee_Time ON dbo.AttendanceVerificationAttempt (EmployeeId, AttemptedAt);
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- Khuyến nghị: AuditLog chỉ append (tài khoản ứng dụng không được sửa/xóa)
-- DENY UPDATE, DELETE ON dbo.AuditLog TO <app_db_user>;
GO

IF OBJECT_ID('tempdb..#HrmInstallGuard') IS NULL
    THROW 51001, N'Cài đặt đã bị dừng: không tạo mới được database. Không tiếp tục chạy các batch schema.', 1;

-- Xác nhận schema đã được tạo.
SELECT COUNT(*) AS CreatedTableCount
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'dbo' AND TABLE_TYPE = 'BASE TABLE';
GO
