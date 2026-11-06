-- ============================================================================
-- seeddata.sql
-- Dữ liệu nền (role, permission, danh mục) và dữ liệu demo/test.
-- Chạy SAU config.sql. File có thể chạy lại; dữ liệu demo được bỏ qua nếu đã tồn tại.
-- Trước production: rà soát và xóa phần dữ liệu demo/test, giữ lại dữ liệu nền cần thiết.
-- ============================================================================
USE HRM_CoffeeShop;
GO

-- ============================================================================
-- DỮ LIỆU NỀN: vai trò, quyền, chức vụ, loại giấy tờ, quy tắc, nhắc việc, admin.
-- Các INSERT đều kiểm tra khóa nghiệp vụ trước khi thêm nên có thể chạy lại.
-- ============================================================================
-- Vai trò
IF NOT EXISTS (SELECT 1 FROM dbo.Role WHERE RoleCode = 'SYSTEM_ADMIN')
    INSERT INTO dbo.Role (RoleCode, RoleName, Description)
    VALUES ('SYSTEM_ADMIN', N'Quản trị hệ thống', N'Quản lý tài khoản và cấu hình hệ thống');

IF NOT EXISTS (SELECT 1 FROM dbo.Role WHERE RoleCode = 'STORE_MANAGER')
    INSERT INTO dbo.Role (RoleCode, RoleName, Description)
    VALUES ('STORE_MANAGER', N'Quản lý cửa hàng', N'Quản lý lịch làm, chấm công và vận hành');

IF NOT EXISTS (SELECT 1 FROM dbo.Role WHERE RoleCode = 'EMPLOYEE')
    INSERT INTO dbo.Role (RoleCode, RoleName, Description)
    VALUES ('EMPLOYEE', N'Nhân viên', N'Xem lịch, chấm công và thực hiện checklist');

-- HR KHÔNG phải role mà là tập quyền (D-01), gán trực tiếp cho người dùng qua dbo.UserPermission
IF NOT EXISTS (SELECT 1 FROM dbo.Role WHERE RoleCode = 'OPERATIONS_DIRECTOR')
    INSERT INTO dbo.Role (RoleCode, RoleName, Description)
    VALUES ('OPERATIONS_DIRECTOR', N'Giám đốc vận hành', N'Duyệt thưởng/phạt nghiêm trọng, mở lại kỳ công');
GO


-- Nhắc việc mặc định
IF NOT EXISTS (SELECT 1 FROM dbo.ReminderRule WHERE RuleCode = 'SHIFT_REMINDER')
    INSERT INTO dbo.ReminderRule (RuleCode, RuleName, LeadMinutes) VALUES ('SHIFT_REMINDER', N'Nhắc nhân viên trước giờ vào ca', 15);
IF NOT EXISTS (SELECT 1 FROM dbo.ReminderRule WHERE RuleCode = 'CHECKLIST_DUE_SOON')
    INSERT INTO dbo.ReminderRule (RuleCode, RuleName, LeadMinutes) VALUES ('CHECKLIST_DUE_SOON', N'Nhắc checklist sắp đến hạn', 15);
IF NOT EXISTS (SELECT 1 FROM dbo.ReminderRule WHERE RuleCode = 'CHECKLIST_OVERDUE')
    INSERT INTO dbo.ReminderRule (RuleCode, RuleName, IntervalMinutes, MaxAttempts) VALUES ('CHECKLIST_OVERDUE', N'Nhắc checklist quá hạn', 5, 3);

-- Danh mục chức vụ (SRS 7.3)
IF NOT EXISTS (SELECT 1 FROM dbo.JobPosition WHERE PositionCode = 'QL')
    INSERT INTO dbo.JobPosition (PositionCode, PositionName) VALUES ('QL', N'Quản lý cửa hàng');
IF NOT EXISTS (SELECT 1 FROM dbo.JobPosition WHERE PositionCode = 'THU_NGAN')
    INSERT INTO dbo.JobPosition (PositionCode, PositionName) VALUES ('THU_NGAN', N'Thu ngân');
IF NOT EXISTS (SELECT 1 FROM dbo.JobPosition WHERE PositionCode = 'PHA_CHE')
    INSERT INTO dbo.JobPosition (PositionCode, PositionName) VALUES ('PHA_CHE', N'Pha chế');
IF NOT EXISTS (SELECT 1 FROM dbo.JobPosition WHERE PositionCode = 'PHUC_VU')
    INSERT INTO dbo.JobPosition (PositionCode, PositionName) VALUES ('PHUC_VU', N'Phục vụ');
IF NOT EXISTS (SELECT 1 FROM dbo.JobPosition WHERE PositionCode = 'DAU_BEP')
    INSERT INTO dbo.JobPosition (PositionCode, PositionName) VALUES ('DAU_BEP', N'Đầu bếp');

-- Danh mục giấy tờ (không còn cờ bắt buộc: xem PositionDocumentRequirement)
IF NOT EXISTS (SELECT 1 FROM dbo.DocumentType WHERE DocumentCode = 'CITIZEN_ID')
    INSERT INTO dbo.DocumentType (DocumentCode, DocumentName)
    VALUES ('CITIZEN_ID', N'Căn cước công dân');

IF NOT EXISTS (SELECT 1 FROM dbo.DocumentType WHERE DocumentCode = 'RESUME')
    INSERT INTO dbo.DocumentType (DocumentCode, DocumentName)
    VALUES ('RESUME', N'Sơ yếu lý lịch');

IF NOT EXISTS (SELECT 1 FROM dbo.DocumentType WHERE DocumentCode = 'COMMITMENT')
    INSERT INTO dbo.DocumentType (DocumentCode, DocumentName)
    VALUES ('COMMITMENT', N'Giấy cam kết');

IF NOT EXISTS (SELECT 1 FROM dbo.DocumentType WHERE DocumentCode = 'FOOD_SAFETY_CERT')
    INSERT INTO dbo.DocumentType (DocumentCode, DocumentName)
    VALUES ('FOOD_SAFETY_CERT', N'Chứng chỉ an toàn thực phẩm');

-- Bộ hồ sơ theo chức vụ: 3 giấy tờ chung cho mọi chức vụ, chứng chỉ thực phẩm cho Đầu bếp
INSERT INTO dbo.PositionDocumentRequirement (PositionId, DocumentTypeId, IsMandatory, EffectiveFrom)
SELECT p.PositionId, d.DocumentTypeId, 1, '2000-01-01'
FROM dbo.JobPosition p CROSS JOIN dbo.DocumentType d
WHERE d.DocumentCode IN ('CITIZEN_ID', 'RESUME', 'COMMITMENT')
  AND NOT EXISTS (SELECT 1 FROM dbo.PositionDocumentRequirement r
                  WHERE r.PositionId = p.PositionId AND r.DocumentTypeId = d.DocumentTypeId
                    AND r.EffectiveFrom = '2000-01-01');

INSERT INTO dbo.PositionDocumentRequirement (PositionId, DocumentTypeId, IsMandatory, EffectiveFrom)
SELECT p.PositionId, d.DocumentTypeId, 1, '2000-01-01'
FROM dbo.JobPosition p CROSS JOIN dbo.DocumentType d
WHERE p.PositionCode = 'DAU_BEP' AND d.DocumentCode = 'FOOD_SAFETY_CERT'
  AND NOT EXISTS (SELECT 1 FROM dbo.PositionDocumentRequirement r
                  WHERE r.PositionId = p.PositionId AND r.DocumentTypeId = d.DocumentTypeId
                    AND r.EffectiveFrom = '2000-01-01');
GO

-- Quy tắc vi phạm
IF NOT EXISTS (SELECT 1 FROM dbo.RuleCatalog WHERE RuleCode = 'LATE_MINOR')
    INSERT INTO dbo.RuleCatalog
        (RuleCode, RuleName, RuleType, Severity, DefaultAmount, IsAutomatic, Description)
    VALUES
        ('LATE_MINOR', N'Đi muộn', 'VIOLATION', 'MINOR', 0, 1,
         N'Ghi nhận dựa trên thời gian đi muộn sau khi hết ân hạn');

IF NOT EXISTS (SELECT 1 FROM dbo.RuleCatalog WHERE RuleCode = 'CHECKLIST_MISSED')
    INSERT INTO dbo.RuleCatalog
        (RuleCode, RuleName, RuleType, Severity, DefaultAmount, IsAutomatic, Description)
    VALUES
        ('CHECKLIST_MISSED', N'Bỏ sót checklist', 'VIOLATION', 'MINOR', 0, 1,
         N'Ghi nhận sau khi hết số lần nhắc');

IF NOT EXISTS (SELECT 1 FROM dbo.RuleCatalog WHERE RuleCode = 'ATTENDANCE_SPOT_CHECK_MISSED')
    INSERT INTO dbo.RuleCatalog
        (RuleCode, RuleName, RuleType, Severity, DefaultAmount, IsAutomatic, Description)
    VALUES
        ('ATTENDANCE_SPOT_CHECK_MISSED', N'Không phản hồi kiểm tra giữa ca', 'VIOLATION', 'MINOR', 0, 1,
         N'Ghi nhận khi nhân viên không phản hồi yêu cầu kiểm tra hiện diện trong 5 phút');

IF NOT EXISTS (SELECT 1 FROM dbo.RuleCatalog WHERE RuleCode = 'SERVICE_ISSUE')
    INSERT INTO dbo.RuleCatalog
        (RuleCode, RuleName, RuleType, Severity, DefaultAmount, IsAutomatic, Description)
    VALUES
        ('SERVICE_ISSUE', N'Lỗi dịch vụ', 'VIOLATION', 'MAJOR', NULL, 0,
         N'Quản lý phải xem xét trước khi áp dụng');

-- Quy tắc khen thưởng
IF NOT EXISTS (SELECT 1 FROM dbo.RuleCatalog WHERE RuleCode = 'CUSTOMER_COMPLIMENT')
    INSERT INTO dbo.RuleCatalog
        (RuleCode, RuleName, RuleType, Severity, DefaultAmount, IsAutomatic, Description)
    VALUES
        ('CUSTOMER_COMPLIMENT', N'Được khách hàng khen', 'REWARD', 'MINOR', NULL, 0,
         N'Cần xác minh minh chứng trước khi duyệt');

IF NOT EXISTS (SELECT 1 FROM dbo.RuleCatalog WHERE RuleCode = 'KPI_EXCEEDED')
    INSERT INTO dbo.RuleCatalog
        (RuleCode, RuleName, RuleType, Severity, DefaultAmount, IsAutomatic, Description)
    VALUES
        ('KPI_EXCEEDED', N'Vượt KPI', 'REWARD', 'MAJOR', NULL, 0,
         N'Áp dụng theo KPI và thẩm quyền phê duyệt');
GO

-- Danh mục quyền
INSERT INTO dbo.Permission (PermissionCode, PermissionName)
SELECT v.Code, v.Name FROM (VALUES
 ('SCHEDULE_VIEW_SELF',      N'Xem lịch làm của mình'),
 ('ATTENDANCE_SELF',         N'Chấm công cho mình'),
 ('DEVICE_REGISTER',         N'Đăng ký thiết bị chấm công'),
 ('DOCUMENT_SUBMIT_SELF',    N'Nộp hồ sơ của mình'),
 ('TRAINING_SELF',           N'Học và xem đào tạo của mình'),
 ('CHECKLIST_EXECUTE',       N'Thực hiện checklist được giao'),
 ('EXPLANATION_SUBMIT',      N'Gửi giải trình'),
 ('SCHEDULE_MANAGE',         N'Lập lịch và phân ca'),
 ('ATTENDANCE_REVIEW',       N'Duyệt giải trình/OT/điều chỉnh công (bước quản lý)'),
 ('ATTENDANCE_VIEW_ALL',     N'Xem chấm công toàn cửa hàng'),
 ('ATTENDANCE_ADJUST_HR',    N'Duyệt tổng hợp điều chỉnh công (bước HR)'),
 ('DEVICE_APPROVE',          N'Duyệt/từ chối/thu hồi thiết bị'),
 ('CHECKLIST_REVIEW',        N'Duyệt checklist'),
 ('CHECKLIST_VIEW',          N'Xem checklist toàn cửa hàng'),
 ('DASHBOARD_MANAGER',       N'Xem dashboard và báo cáo quản lý'),
 ('STAFF_REVIEW',            N'Rà soát dữ liệu nhân viên của cửa hàng'),
 ('EMPLOYEE_VIEW',           N'Xem hồ sơ nhân viên'),
 ('EMPLOYEE_MANAGE',         N'Tạo/sửa/đổi trạng thái nhân viên'),
 ('EMPLOYEE_PII_VIEW',       N'Xem đầy đủ số định danh nhân viên'),
 ('DOCUMENT_REVIEW',         N'Rà soát và duyệt hồ sơ nhân viên'),
 ('TRAINING_MANAGE',         N'Ghi kết quả thi và xem tiến độ đào tạo'),
 ('VIOLATION_REVIEW',        N'Xác nhận/bác bỏ vi phạm'),
 ('REWARD_VIEW',             N'Xem quyết định thưởng/phạt'),
 ('REWARD_PROPOSE',          N'Đề xuất thưởng/phạt'),
 ('REWARD_APPROVE',          N'Duyệt thưởng/phạt thông thường'),
 ('REWARD_APPROVE_CRITICAL', N'Duyệt thưởng/phạt nghiêm trọng'),
 ('EVIDENCE_VIEW',           N'Xem ảnh xác minh chấm công'),
 ('EVIDENCE_DOWNLOAD',       N'Tải ảnh xác minh chấm công (quyền nhạy cảm, cấp riêng)'),
 ('PAYROLL_VIEW',            N'Xem kỳ công'),
 ('PAYROLL_PERIOD_MANAGE',   N'Tạo kỳ công'),
 ('PAYROLL_MANAGER_CONFIRM', N'Quản lý xác nhận kỳ công'),
 ('PAYROLL_FINALIZE',        N'Chốt kỳ công'),
 ('PAYROLL_REOPEN',          N'Mở lại kỳ công'),
 ('CONFIG_MANAGE',           N'Quản lý cấu hình hệ thống'),
 ('USER_MANAGE',             N'Quản lý tài khoản và phân quyền'),
 ('AUDIT_VIEW',              N'Xem audit log'),
 ('TEMPLATE_MANAGE',         N'Quản lý template checklist')
) AS v(Code, Name)
WHERE NOT EXISTS (SELECT 1 FROM dbo.Permission p WHERE p.PermissionCode = v.Code);
GO

-- Quyền mặc định theo role (KHÔNG có HR: HR là tập quyền gán cho người dùng, xem dbo.UserPermission)
INSERT INTO dbo.RolePermission (RoleId, PermissionId)
SELECT r.RoleId, p.PermissionId
FROM (VALUES
 ('EMPLOYEE','SCHEDULE_VIEW_SELF'),('EMPLOYEE','ATTENDANCE_SELF'),('EMPLOYEE','DEVICE_REGISTER'),
 ('EMPLOYEE','DOCUMENT_SUBMIT_SELF'),('EMPLOYEE','TRAINING_SELF'),('EMPLOYEE','CHECKLIST_EXECUTE'),
 ('EMPLOYEE','EXPLANATION_SUBMIT'),
 ('STORE_MANAGER','SCHEDULE_MANAGE'),('STORE_MANAGER','ATTENDANCE_REVIEW'),('STORE_MANAGER','ATTENDANCE_VIEW_ALL'),
 ('STORE_MANAGER','DEVICE_APPROVE'),('STORE_MANAGER','CHECKLIST_REVIEW'),('STORE_MANAGER','CHECKLIST_VIEW'),
 ('STORE_MANAGER','DASHBOARD_MANAGER'),('STORE_MANAGER','STAFF_REVIEW'),('STORE_MANAGER','EMPLOYEE_VIEW'),
 ('STORE_MANAGER','EMPLOYEE_MANAGE'),('STORE_MANAGER','DOCUMENT_REVIEW'),('STORE_MANAGER','TRAINING_MANAGE'),
 ('STORE_MANAGER','VIOLATION_REVIEW'),('STORE_MANAGER','REWARD_VIEW'),('STORE_MANAGER','REWARD_PROPOSE'),
 ('STORE_MANAGER','REWARD_APPROVE'),('STORE_MANAGER','EVIDENCE_VIEW'),('STORE_MANAGER','PAYROLL_VIEW'),
 ('STORE_MANAGER','PAYROLL_MANAGER_CONFIRM'),
 ('OPERATIONS_DIRECTOR','REWARD_APPROVE_CRITICAL'),('OPERATIONS_DIRECTOR','REWARD_APPROVE'),
 ('OPERATIONS_DIRECTOR','REWARD_PROPOSE'),('OPERATIONS_DIRECTOR','REWARD_VIEW'),
 ('OPERATIONS_DIRECTOR','VIOLATION_REVIEW'),('OPERATIONS_DIRECTOR','PAYROLL_VIEW'),
 ('OPERATIONS_DIRECTOR','PAYROLL_REOPEN'),
 ('SYSTEM_ADMIN','CONFIG_MANAGE'),('SYSTEM_ADMIN','USER_MANAGE'),('SYSTEM_ADMIN','AUDIT_VIEW'),
 ('SYSTEM_ADMIN','TEMPLATE_MANAGE'),('SYSTEM_ADMIN','PAYROLL_REOPEN'),('SYSTEM_ADMIN','EMPLOYEE_VIEW'),
 ('SYSTEM_ADMIN','EMPLOYEE_MANAGE'),('SYSTEM_ADMIN','EMPLOYEE_PII_VIEW'),('SYSTEM_ADMIN','PAYROLL_VIEW'),
 ('SYSTEM_ADMIN','PAYROLL_PERIOD_MANAGE')
) AS m(RoleCode, PermCode)
JOIN dbo.Role r ON r.RoleCode = m.RoleCode
JOIN dbo.Permission p ON p.PermissionCode = m.PermCode
WHERE NOT EXISTS (SELECT 1 FROM dbo.RolePermission rp WHERE rp.RoleId = r.RoleId AND rp.PermissionId = p.PermissionId);
GO

-- Tài khoản quản trị đầu tiên (đăng nhập bằng Google)
IF NOT EXISTS (SELECT 1 FROM dbo.AppUser WHERE Email='baonvhe181955@fpt.edu.vn')
BEGIN
    INSERT INTO dbo.AppUser (Email, DisplayName, UserStatus) VALUES ('baonvhe181955@fpt.edu.vn', N'Admin', 'ACTIVE');
    INSERT INTO dbo.UserRole (UserId, RoleId)
    SELECT u.UserId, r.RoleId FROM dbo.AppUser u CROSS JOIN dbo.Role r
    WHERE u.Email='baonvhe181955@fpt.edu.vn' AND r.RoleCode='SYSTEM_ADMIN';
END
GO

GO

-- =====================================================================================
-- DỮ LIỆU TEST TỐI GIẢN
-- Tổng cộng 3 tài khoản: admin, manager và một employee. Demo được tạo một lần cho CF-HN01.
-- Test password: đặt DEV_PASSWORD_LOGIN_ENABLED=true, BOOTSTRAP_ADMIN_PASSWORD và TEST_ACCOUNTS_PASSWORD.
-- Để thử chấm công: đăng nhập panchisuru@gmail.com, đăng ký thiết bị với fingerprint seed-device-an
-- (hoặc đăng ký thiết bị mới và duyệt bằng tài khoản quản lý), rồi dùng GPS trong bán kính 30 m.
-- =====================================================================================
GO

SET XACT_ABORT ON;
IF EXISTS (SELECT 1 FROM dbo.Store WHERE StoreCode = 'CF-HN01')
    PRINT N'Dữ liệu demo tối giản đã tồn tại (CF-HN01) - bỏ qua.';
ELSE
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @D DATE = CAST(DATEADD(HOUR, 7, SYSUTCDATETIME()) AS DATE);
        DECLARE @T0 DATETIME2 = DATEADD(HOUR, -7, CAST(@D AS DATETIME2));
        DECLARE @ManagerRoleId INT = (SELECT RoleId FROM dbo.Role WHERE RoleCode = 'STORE_MANAGER');
        DECLARE @EmployeeRoleId INT = (SELECT RoleId FROM dbo.Role WHERE RoleCode = 'EMPLOYEE');

        INSERT INTO dbo.Store (StoreCode, Name, AddressLine, Latitude, Longitude, AttendanceRadiusMeters, IsActive)
        VALUES ('CF-HN01', N'Cà phê Mộc – Cửa hàng Test', N'1 Tràng Tiền, Hoàn Kiếm, Hà Nội', 21.0278000, 105.8342000, 30, 1);

        DECLARE @StoreId INT = (SELECT StoreId FROM dbo.Store WHERE StoreCode = 'CF-HN01');

        IF NOT EXISTS (SELECT 1 FROM dbo.AppUser WHERE Email = 'baonvchaos@gmail.com')
            INSERT INTO dbo.AppUser (Email, DisplayName, PhoneNumber, UserStatus)
            VALUES ('baonvchaos@gmail.com', N'Manager', '0901000002', 'ACTIVE');

        IF NOT EXISTS (SELECT 1 FROM dbo.AppUser WHERE Email = 'panchisuru@gmail.com')
            INSERT INTO dbo.AppUser (Email, DisplayName, PhoneNumber, UserStatus)
            VALUES ('panchisuru@gmail.com', N'Employee', '0901000004', 'ACTIVE');

        DECLARE @ManagerId BIGINT = (SELECT UserId FROM dbo.AppUser WHERE Email = 'baonvchaos@gmail.com');
        DECLARE @EmployeeUserId BIGINT = (SELECT UserId FROM dbo.AppUser WHERE Email = 'panchisuru@gmail.com');

        INSERT INTO dbo.UserRole (UserId, RoleId)
        SELECT @ManagerId, @ManagerRoleId
        WHERE NOT EXISTS (SELECT 1 FROM dbo.UserRole WHERE UserId = @ManagerId AND RoleId = @ManagerRoleId);

        INSERT INTO dbo.UserRole (UserId, RoleId)
        SELECT @EmployeeUserId, @EmployeeRoleId
        WHERE NOT EXISTS (SELECT 1 FROM dbo.UserRole WHERE UserId = @EmployeeUserId AND RoleId = @EmployeeRoleId);

        INSERT INTO dbo.Employee
            (UserId, EmployeeCode, StoreId, JobTitle, PositionId, EmploymentType, EmploymentStatus,
             DateOfBirth, HireDate, IdentityNumber, Address, EmergencyContact, ProfileStatus)
        SELECT @ManagerId, 'QL001', @StoreId, N'Quản lý cửa hàng',
               (SELECT PositionId FROM dbo.JobPosition WHERE PositionCode = 'QL'),
               'FULL_TIME', 'ACTIVE', '1990-05-12', DATEADD(DAY, -900, @D),
               '000000000001', N'Hà Nội', N'Người thân – 0912000000', 'COMPLETE'
        WHERE NOT EXISTS (SELECT 1 FROM dbo.Employee WHERE UserId = @ManagerId);

        INSERT INTO dbo.Employee
            (UserId, EmployeeCode, StoreId, JobTitle, PositionId, EmploymentType, EmploymentStatus,
             DateOfBirth, HireDate, IdentityNumber, Address, EmergencyContact, ProfileStatus)
        SELECT @EmployeeUserId, 'NV001', @StoreId, N'Pha chế',
               (SELECT PositionId FROM dbo.JobPosition WHERE PositionCode = 'PHA_CHE'),
               'FULL_TIME', 'ACTIVE', '1998-02-14', DATEADD(DAY, -400, @D),
               '000000000002', N'Hà Nội', N'Người thân – 0912000000', 'COMPLETE'
        WHERE NOT EXISTS (SELECT 1 FROM dbo.Employee WHERE UserId = @EmployeeUserId);

        DECLARE @EmployeeId BIGINT = (SELECT EmployeeId FROM dbo.Employee WHERE UserId = @EmployeeUserId);
        DECLARE @ManagerEmployeeId BIGINT = (SELECT EmployeeId FROM dbo.Employee WHERE UserId = @ManagerId);

        -- Một bộ khóa học nhỏ giúp thử màn đào tạo và giữ nhân viên đủ điều kiện nhận ca.
        INSERT INTO dbo.TrainingCourse (CourseCode, CourseName, Description, PassingScore)
        SELECT v.CourseCode, v.CourseName, v.Description, v.PassingScore
        FROM (VALUES
            ('FOOD_SAFETY_101', N'An toàn vệ sinh thực phẩm cơ bản', N'Bắt buộc với mọi nhân viên', 80),
            ('HOUSE_RULES', N'Nội quy và quy trình cửa hàng', N'Bắt buộc với mọi nhân viên', 80),
            ('BARISTA_BASIC', N'Kỹ thuật pha chế cơ bản', N'Dành cho nhân viên pha chế', 70),
            ('COFFEE_TASTING', N'Thử nếm và phân biệt hương vị cà phê', N'Khóa tự chọn', 60)
        ) AS v(CourseCode, CourseName, Description, PassingScore)
        WHERE NOT EXISTS (SELECT 1 FROM dbo.TrainingCourse c WHERE c.CourseCode = v.CourseCode);

        INSERT INTO dbo.PositionTrainingRequirement
            (PositionId, CourseId, IsMandatory, BlocksShiftAssignment, EffectiveFrom)
        SELECT p.PositionId, c.CourseId, 1, 1, '2000-01-01'
        FROM dbo.JobPosition p
        CROSS JOIN dbo.TrainingCourse c
        WHERE c.CourseCode IN ('FOOD_SAFETY_101', 'HOUSE_RULES')
          AND NOT EXISTS (
              SELECT 1 FROM dbo.PositionTrainingRequirement r
              WHERE r.PositionId = p.PositionId AND r.CourseId = c.CourseId
                AND r.EffectiveFrom = '2000-01-01'
          );

        INSERT INTO dbo.EmployeeTraining
            (EmployeeId, CourseId, AssignedAt, DueAt, CompletedAt, TestScore, TrainingStatus)
        SELECT v.EmployeeId, c.CourseId, DATEADD(DAY, -30, SYSUTCDATETIME()),
               DATEADD(DAY, 30, SYSUTCDATETIME()),
               CASE WHEN v.TrainingStatus = 'PASSED' THEN DATEADD(DAY, -25, SYSUTCDATETIME()) END,
               v.TestScore, v.TrainingStatus
        FROM (VALUES
            (@ManagerEmployeeId, 'FOOD_SAFETY_101', 'PASSED', 95.0),
            (@ManagerEmployeeId, 'HOUSE_RULES', 'PASSED', 90.0),
            (@EmployeeId, 'FOOD_SAFETY_101', 'PASSED', 92.0),
            (@EmployeeId, 'HOUSE_RULES', 'PASSED', 88.0),
            (@EmployeeId, 'BARISTA_BASIC', 'IN_PROGRESS', CAST(NULL AS DECIMAL(5,2))),
            (@EmployeeId, 'COFFEE_TASTING', 'NOT_STARTED', CAST(NULL AS DECIMAL(5,2)))
        ) AS v(EmployeeId, CourseCode, TrainingStatus, TestScore)
        JOIN dbo.TrainingCourse c ON c.CourseCode = v.CourseCode
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.EmployeeTraining et
            WHERE et.EmployeeId = v.EmployeeId AND et.CourseId = c.CourseId
        );

        -- Hai mẫu checklist cơ bản để quản lý có thể tạo checklist cho ca được phân.
        IF NOT EXISTS (SELECT 1 FROM dbo.ChecklistTemplate WHERE StoreId = @StoreId AND ChecklistCode = 'OPEN_STORE' AND Version = 1)
            INSERT INTO dbo.ChecklistTemplate (StoreId, ChecklistCode, ChecklistName, ChecklistType, IsManagerApprovalRequired)
            VALUES (@StoreId, 'OPEN_STORE', N'Mở cửa hàng', 'OPENING', 0);
        IF NOT EXISTS (SELECT 1 FROM dbo.ChecklistTemplate WHERE StoreId = @StoreId AND ChecklistCode = 'HANDOVER_SHIFT' AND Version = 1)
            INSERT INTO dbo.ChecklistTemplate (StoreId, ChecklistCode, ChecklistName, ChecklistType, IsManagerApprovalRequired)
            VALUES (@StoreId, 'HANDOVER_SHIFT', N'Bàn giao ca', 'HANDOVER', 1);

        DECLARE @OpenTemplateId INT =
            (SELECT ChecklistTemplateId FROM dbo.ChecklistTemplate WHERE StoreId = @StoreId AND ChecklistCode = 'OPEN_STORE' AND Version = 1);
        DECLARE @HandoverTemplateId INT =
            (SELECT ChecklistTemplateId FROM dbo.ChecklistTemplate WHERE StoreId = @StoreId AND ChecklistCode = 'HANDOVER_SHIFT' AND Version = 1);

        INSERT INTO dbo.ChecklistTemplateItem
            (ChecklistTemplateId, ItemName, Instructions, IsMandatory, RequiresEvidence, RequiresManagerApproval, SortOrder)
        SELECT v.ChecklistTemplateId, v.ItemName, v.Instructions, 1, 0, 0, v.SortOrder
        FROM (VALUES
            (@OpenTemplateId, N'Kiểm tra khu vực phục vụ', N'Đảm bảo khu vực sạch và sẵn sàng đón khách', 1),
            (@OpenTemplateId, N'Kiểm tra thiết bị', N'Kiểm tra máy pha và các thiết bị đầu ca', 2),
            (@HandoverTemplateId, N'Bàn giao tiền và hóa đơn', N'Đối chiếu số liệu trước khi bàn giao', 1),
            (@HandoverTemplateId, N'Bàn giao tồn kho', N'Ghi nhận vật tư cần bổ sung', 2)
        ) AS v(ChecklistTemplateId, ItemName, Instructions, SortOrder)
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.ChecklistTemplateItem i
            WHERE i.ChecklistTemplateId = v.ChecklistTemplateId AND i.SortOrder = v.SortOrder
        );

        IF NOT EXISTS (
            SELECT 1 FROM dbo.AttendanceDevice
            WHERE DeviceFingerprint = LOWER(CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'seed-device-an'), 2))
        )
            INSERT INTO dbo.AttendanceDevice
                (EmployeeId, DeviceFingerprint, DeviceName, Platform, Status, RequestedAt, ApprovedBy, ApprovedAt)
            VALUES
                (@EmployeeId,
                 LOWER(CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'seed-device-an'), 2)),
                 N'Thiết bị test của An', 'ANDROID', 'ACTIVE', DATEADD(DAY, -30, SYSUTCDATETIME()),
                 @ManagerId, DATEADD(DAY, -29, SYSUTCDATETIME()));

        IF NOT EXISTS (SELECT 1 FROM dbo.WorkShift WHERE StoreId = @StoreId AND ShiftCode = 'CA_TEST')
            INSERT INTO dbo.WorkShift
                (StoreId, ShiftCode, ShiftName, StartTime, EndTime, BreakMinutes, EarlyCheckInMinutes, GraceMinutes)
            VALUES
                (@StoreId, 'CA_TEST', N'Ca TEST cả ngày', '00:00', '23:59', 0, 15, 5);

        DECLARE @TestShiftId INT =
            (SELECT WorkShiftId FROM dbo.WorkShift WHERE StoreId = @StoreId AND ShiftCode = 'CA_TEST');

        ;WITH TestDays AS (
            SELECT 0 AS DayOffset
            UNION ALL
            SELECT DayOffset + 1 FROM TestDays WHERE DayOffset < 6
        )
        INSERT INTO dbo.ShiftAssignment
            (EmployeeId, WorkShiftId, WorkDate, PlannedStartAt, PlannedEndAt,
             ScheduleStatus, CreatedBy, CreatedAt, UpdatedAt, Note)
        SELECT @EmployeeId, @TestShiftId, DATEADD(DAY, d.DayOffset, @D),
               DATEADD(DAY, d.DayOffset, @T0),
               DATEADD(MINUTE, 1439, DATEADD(DAY, d.DayOffset, @T0)),
               'PUBLISHED', @ManagerId, SYSUTCDATETIME(), SYSUTCDATETIME(),
               N'Ca TEST cả ngày'
        FROM TestDays d
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.ShiftAssignment sa
            WHERE sa.EmployeeId = @EmployeeId
              AND sa.WorkShiftId = @TestShiftId
              AND sa.WorkDate = DATEADD(DAY, d.DayOffset, @D)
              AND sa.ScheduleStatus <> 'CANCELLED'
        )
        OPTION (MAXRECURSION 7);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- ============================================================================
-- DỮ LIỆU DEMO MỞ RỘNG: có thể chạy lại sau khi CF-HN01 đã tồn tại.
-- AppUser được giữ đúng ba tài khoản demo; lịch sử ca được tạo riêng 30 ngày.
-- ============================================================================
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;

    -- Chuyển các tài khoản demo cũ sang đúng email được yêu cầu, giữ nguyên khóa ngoại/UserId.
    IF NOT EXISTS (SELECT 1 FROM dbo.AppUser WHERE Email = 'baonvchaos@gmail.com')
       AND EXISTS (SELECT 1 FROM dbo.AppUser WHERE Email = 'quanly@hrm.test')
        UPDATE dbo.AppUser SET Email = 'baonvchaos@gmail.com' WHERE Email = 'quanly@hrm.test';
    IF NOT EXISTS (SELECT 1 FROM dbo.AppUser WHERE Email = 'panchisuru@gmail.com')
       AND EXISTS (SELECT 1 FROM dbo.AppUser WHERE Email = 'nv.an@hrm.test')
        UPDATE dbo.AppUser SET Email = 'panchisuru@gmail.com' WHERE Email = 'nv.an@hrm.test';

    UPDATE dbo.AppUser
       SET DisplayName = N'Admin', PhoneNumber = NULL, UserStatus = 'ACTIVE'
     WHERE Email = 'baonvhe181955@fpt.edu.vn';
    UPDATE dbo.AppUser
       SET DisplayName = N'Manager', PhoneNumber = '0901000002', UserStatus = 'ACTIVE'
     WHERE Email = 'baonvchaos@gmail.com';
    UPDATE dbo.AppUser
       SET DisplayName = N'Employee', PhoneNumber = '0901000004', UserStatus = 'ACTIVE'
     WHERE Email = 'panchisuru@gmail.com';

    DECLARE @AdminUserId BIGINT = (SELECT UserId FROM dbo.AppUser WHERE Email = 'baonvhe181955@fpt.edu.vn');
    DECLARE @ManagerUserId BIGINT = (SELECT UserId FROM dbo.AppUser WHERE Email = 'baonvchaos@gmail.com');
    DECLARE @EmployeeUserId BIGINT = (SELECT UserId FROM dbo.AppUser WHERE Email = 'panchisuru@gmail.com');
    DECLARE @ManagerRoleId INT = (SELECT RoleId FROM dbo.Role WHERE RoleCode = 'STORE_MANAGER');
    DECLARE @EmployeeRoleId INT = (SELECT RoleId FROM dbo.Role WHERE RoleCode = 'EMPLOYEE');
    DECLARE @AdminRoleId INT = (SELECT RoleId FROM dbo.Role WHERE RoleCode = 'SYSTEM_ADMIN');
    DECLARE @Today DATE = CAST(DATEADD(HOUR, 7, SYSUTCDATETIME()) AS DATE);

    INSERT INTO dbo.UserRole (UserId, RoleId)
    SELECT @AdminUserId, @AdminRoleId
    WHERE NOT EXISTS (SELECT 1 FROM dbo.UserRole WHERE UserId = @AdminUserId AND RoleId = @AdminRoleId);
    INSERT INTO dbo.UserRole (UserId, RoleId)
    SELECT @ManagerUserId, @ManagerRoleId
    WHERE NOT EXISTS (SELECT 1 FROM dbo.UserRole WHERE UserId = @ManagerUserId AND RoleId = @ManagerRoleId);
    INSERT INTO dbo.UserRole (UserId, RoleId)
    SELECT @EmployeeUserId, @EmployeeRoleId
    WHERE NOT EXISTS (SELECT 1 FROM dbo.UserRole WHERE UserId = @EmployeeUserId AND RoleId = @EmployeeRoleId);

    INSERT INTO dbo.RefreshToken (UserId, TokenHash, ExpiresAt)
    SELECT v.UserId, LOWER(CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', v.TokenSeed), 2)), DATEADD(DAY, -1, SYSUTCDATETIME())
    FROM (VALUES
        (@AdminUserId, 'demo-refresh-admin'),
        (@ManagerUserId, 'demo-refresh-manager'),
        (@EmployeeUserId, 'demo-refresh-employee')
    ) v(UserId, TokenSeed)
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.RefreshToken t
        WHERE t.TokenHash = LOWER(CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', v.TokenSeed), 2))
    );

    INSERT INTO dbo.UserPermission (UserId, PermissionId, GrantedBy)
    SELECT v.UserId, p.PermissionId, @AdminUserId
    FROM (VALUES
        (@AdminUserId, 'AUDIT_VIEW'),
        (@ManagerUserId, 'ATTENDANCE_VIEW_ALL'),
        (@EmployeeUserId, 'ATTENDANCE_SELF')
    ) v(UserId, PermissionCode)
    JOIN dbo.Permission p ON p.PermissionCode = v.PermissionCode
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.UserPermission up
        WHERE up.UserId = v.UserId AND up.PermissionId = p.PermissionId
    );

    IF NOT EXISTS (SELECT 1 FROM dbo.Store WHERE StoreCode = 'CF-HN02')
        INSERT INTO dbo.Store (StoreCode, Name, AddressLine, Latitude, Longitude, AttendanceRadiusMeters, IsActive)
        VALUES ('CF-HN02', N'Cà phê Mộc – Cửa hàng Demo 02', N'12 Hàng Bài, Hoàn Kiếm, Hà Nội', 21.0171000, 105.8525000, 30, 0);
    IF NOT EXISTS (SELECT 1 FROM dbo.Store WHERE StoreCode = 'CF-HN03')
        INSERT INTO dbo.Store (StoreCode, Name, AddressLine, Latitude, Longitude, AttendanceRadiusMeters, IsActive)
        VALUES ('CF-HN03', N'Cà phê Mộc – Cửa hàng Demo 03', N'25 Lê Đại Hành, Hai Bà Trưng, Hà Nội', 21.0108000, 105.8483000, 30, 0);

    DECLARE @StoreId INT = (SELECT StoreId FROM dbo.Store WHERE StoreCode = 'CF-HN01');
    DECLARE @EmployeeId BIGINT = (SELECT EmployeeId FROM dbo.Employee WHERE UserId = @EmployeeUserId);
    DECLARE @ManagerEmployeeId BIGINT = (SELECT EmployeeId FROM dbo.Employee WHERE UserId = @ManagerUserId);
    DECLARE @AdminEmployeeId BIGINT = (SELECT EmployeeId FROM dbo.Employee WHERE UserId = @AdminUserId);

    IF @StoreId IS NULL OR @EmployeeId IS NULL OR @ManagerEmployeeId IS NULL
        THROW 51010, N'Dữ liệu demo cơ sở chưa có cửa hàng/nhân viên cần thiết.', 1;

    IF @AdminEmployeeId IS NULL
        INSERT INTO dbo.Employee
            (UserId, EmployeeCode, StoreId, JobTitle, PositionId, EmploymentType, EmploymentStatus,
             DateOfBirth, HireDate, IdentityNumber, Address, EmergencyContact, ProfileStatus)
        VALUES
            (@AdminUserId, 'ADM001', @StoreId, N'Tài khoản quản trị demo',
             (SELECT PositionId FROM dbo.JobPosition WHERE PositionCode = 'QL'),
             'FULL_TIME', 'RESIGNED', '1988-01-10', DATEADD(DAY, -900, @Today),
             '000000000003', N'Hà Nội', N'Liên hệ demo – 0912000003', 'INCOMPLETE');

    DECLARE @AdminEmployeeIdNow BIGINT = (SELECT EmployeeId FROM dbo.Employee WHERE UserId = @AdminUserId);

    INSERT INTO dbo.EmployeeDocument
        (EmployeeId, DocumentTypeId, FileName, StorageKey, ReviewStatus, UploadedAt)
    SELECT @EmployeeId, d.DocumentTypeId, v.FileName,
           CONCAT('private-documents/employee-', @EmployeeId, '/', v.FileName), 'PENDING', DATEADD(DAY, -v.DaysAgo, SYSUTCDATETIME())
    FROM (VALUES
        ('CITIZEN_ID', 'demo-identity.pdf', 20),
        ('RESUME', 'demo-resume.pdf', 18),
        ('COMMITMENT', 'demo-commitment.pdf', 15)
    ) v(DocumentCode, FileName, DaysAgo)
    JOIN dbo.DocumentType d ON d.DocumentCode = v.DocumentCode
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.EmployeeDocument x
        WHERE x.EmployeeId = @EmployeeId AND x.DocumentTypeId = d.DocumentTypeId AND x.FileName = v.FileName
    );

    -- Thiết bị An dùng được để test; thiết bị Admin đang chờ duyệt tạo hàng đợi thao tác thật.
    IF NOT EXISTS (SELECT 1 FROM dbo.AttendanceDevice WHERE DeviceFingerprint = LOWER(CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'seed-device-admin'), 2)))
        INSERT INTO dbo.AttendanceDevice (EmployeeId, DeviceFingerprint, DeviceName, Platform, Status, RequestedAt)
        VALUES (@AdminEmployeeIdNow, LOWER(CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'seed-device-admin'), 2)),
                N'Thiết bị demo của Admin', 'WEB', 'PENDING', DATEADD(DAY, -2, SYSUTCDATETIME()));
    IF NOT EXISTS (SELECT 1 FROM dbo.AttendanceDevice WHERE DeviceFingerprint = LOWER(CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'seed-device-manager'), 2)))
        INSERT INTO dbo.AttendanceDevice (EmployeeId, DeviceFingerprint, DeviceName, Platform, Status, RequestedAt, ApprovedBy, ApprovedAt, LockReason)
        VALUES (@ManagerEmployeeId, LOWER(CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'seed-device-manager'), 2)),
                N'Thiết bị demo cũ của Manager', 'ANDROID', 'REJECTED', DATEADD(DAY, -10, SYSUTCDATETIME()),
                @AdminUserId, DATEADD(DAY, -9, SYSUTCDATETIME()), N'Dữ liệu demo');

    IF NOT EXISTS (SELECT 1 FROM dbo.WorkShift WHERE StoreId = @StoreId AND ShiftCode = 'CA_SANG')
        INSERT INTO dbo.WorkShift (StoreId, ShiftCode, ShiftName, StartTime, EndTime, BreakMinutes, EarlyCheckInMinutes, GraceMinutes)
        VALUES (@StoreId, 'CA_SANG', N'Ca sáng', '07:00', '11:00', 15, 15, 5);
    IF NOT EXISTS (SELECT 1 FROM dbo.WorkShift WHERE StoreId = @StoreId AND ShiftCode = 'CA_CHIEU')
        INSERT INTO dbo.WorkShift (StoreId, ShiftCode, ShiftName, StartTime, EndTime, BreakMinutes, EarlyCheckInMinutes, GraceMinutes)
        VALUES (@StoreId, 'CA_CHIEU', N'Ca chiều', '12:00', '16:00', 15, 15, 5);
    IF NOT EXISTS (SELECT 1 FROM dbo.WorkShift WHERE StoreId = @StoreId AND ShiftCode = 'CA_TOI')
        INSERT INTO dbo.WorkShift (StoreId, ShiftCode, ShiftName, StartTime, EndTime, BreakMinutes, EarlyCheckInMinutes, GraceMinutes)
        VALUES (@StoreId, 'CA_TOI', N'Ca tối', '17:00', '21:00', 15, 15, 5);

    DECLARE @MorningShiftId INT = (SELECT WorkShiftId FROM dbo.WorkShift WHERE StoreId = @StoreId AND ShiftCode = 'CA_SANG');
    DECLARE @AfternoonShiftId INT = (SELECT WorkShiftId FROM dbo.WorkShift WHERE StoreId = @StoreId AND ShiftCode = 'CA_CHIEU');
    DECLARE @EveningShiftId INT = (SELECT WorkShiftId FROM dbo.WorkShift WHERE StoreId = @StoreId AND ShiftCode = 'CA_TOI');

    ;WITH PastDays AS (
        SELECT 1 AS DayOffset
        UNION ALL
        SELECT DayOffset + 1 FROM PastDays WHERE DayOffset < 30
    )
    INSERT INTO dbo.ShiftAssignment
        (EmployeeId, WorkShiftId, WorkDate, PlannedStartAt, PlannedEndAt, ScheduleStatus, CreatedBy, CreatedAt, UpdatedAt, Note)
    SELECT @EmployeeId, x.WorkShiftId, x.WorkDate, t.PlannedStartAt, t.PlannedEndAt,
           'COMPLETED', @ManagerUserId, DATEADD(DAY, -d.DayOffset, SYSUTCDATETIME()),
           DATEADD(DAY, -d.DayOffset, SYSUTCDATETIME()), N'Ca demo lịch sử'
    FROM PastDays d
    CROSS APPLY (SELECT DATEADD(DAY, -d.DayOffset, @Today) AS WorkDate) wd
    CROSS APPLY (SELECT CASE d.DayOffset % 3 WHEN 0 THEN @EveningShiftId WHEN 1 THEN @MorningShiftId ELSE @AfternoonShiftId END AS WorkShiftId) shid
    CROSS APPLY (
        SELECT shid.WorkShiftId, wd.WorkDate,
               DATEADD(HOUR, -7, DATEADD(MINUTE, DATEDIFF(MINUTE, CAST('00:00' AS TIME), ws.StartTime), CAST(wd.WorkDate AS DATETIME2))) AS PlannedStartAt,
               DATEADD(HOUR, -7, DATEADD(MINUTE, DATEDIFF(MINUTE, CAST('00:00' AS TIME), ws.EndTime),
                   DATEADD(DAY, CASE WHEN ws.EndTime <= ws.StartTime THEN 1 ELSE 0 END, CAST(wd.WorkDate AS DATETIME2)))) AS PlannedEndAt
        FROM dbo.WorkShift ws WHERE ws.WorkShiftId = shid.WorkShiftId
    ) x
    CROSS APPLY (SELECT x.PlannedStartAt, x.PlannedEndAt) t
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.ShiftAssignment sa
        WHERE sa.EmployeeId = @EmployeeId AND sa.WorkShiftId = x.WorkShiftId AND sa.WorkDate = x.WorkDate
    )
    OPTION (MAXRECURSION 32);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

-- Attendance, approval queues, and checklist execution history.
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @Today DATE = CAST(DATEADD(HOUR, 7, SYSUTCDATETIME()) AS DATE);
    DECLARE @StoreId INT = (SELECT StoreId FROM dbo.Store WHERE StoreCode = 'CF-HN01');
    DECLARE @EmployeeUserId BIGINT = (SELECT UserId FROM dbo.AppUser WHERE Email = 'panchisuru@gmail.com');
    DECLARE @ManagerUserId BIGINT = (SELECT UserId FROM dbo.AppUser WHERE Email = 'baonvchaos@gmail.com');
    DECLARE @AdminUserId BIGINT = (SELECT UserId FROM dbo.AppUser WHERE Email = 'baonvhe181955@fpt.edu.vn');
    DECLARE @EmployeeId BIGINT = (SELECT EmployeeId FROM dbo.Employee WHERE UserId = @EmployeeUserId);
    DECLARE @MorningShiftId INT = (SELECT WorkShiftId FROM dbo.WorkShift WHERE StoreId = @StoreId AND ShiftCode = 'CA_SANG');
    DECLARE @AfternoonShiftId INT = (SELECT WorkShiftId FROM dbo.WorkShift WHERE StoreId = @StoreId AND ShiftCode = 'CA_CHIEU');
    DECLARE @EveningShiftId INT = (SELECT WorkShiftId FROM dbo.WorkShift WHERE StoreId = @StoreId AND ShiftCode = 'CA_TOI');
    DECLARE @OpenTemplateId INT = (SELECT ChecklistTemplateId FROM dbo.ChecklistTemplate WHERE StoreId = @StoreId AND ChecklistCode = 'OPEN_STORE' AND Version = 1);
    DECLARE @HandoverTemplateId INT = (SELECT ChecklistTemplateId FROM dbo.ChecklistTemplate WHERE StoreId = @StoreId AND ChecklistCode = 'HANDOVER_SHIFT' AND Version = 1);

    IF NOT EXISTS (SELECT 1 FROM dbo.ChecklistTemplate WHERE StoreId = @StoreId AND ChecklistCode = 'DAILY_SERVICE' AND Version = 1)
        INSERT INTO dbo.ChecklistTemplate (StoreId, ChecklistCode, ChecklistName, ChecklistType, IsManagerApprovalRequired)
        VALUES (@StoreId, 'DAILY_SERVICE', N'Phục vụ trong ca', 'SERVICE', 1);
    DECLARE @ServiceTemplateId INT = (SELECT ChecklistTemplateId FROM dbo.ChecklistTemplate WHERE StoreId = @StoreId AND ChecklistCode = 'DAILY_SERVICE' AND Version = 1);

    IF NOT EXISTS (SELECT 1 FROM dbo.ChecklistTemplateItem WHERE ChecklistTemplateId = @ServiceTemplateId AND SortOrder = 1)
        INSERT INTO dbo.ChecklistTemplateItem (ChecklistTemplateId, ItemName, Instructions, IsMandatory, RequiresEvidence, RequiresManagerApproval, SortOrder)
        VALUES (@ServiceTemplateId, N'Kiểm tra khu vực phục vụ', N'Đảm bảo khu vực phục vụ sạch và sẵn sàng', 1, 0, 0, 1);
    IF NOT EXISTS (SELECT 1 FROM dbo.ChecklistTemplateItem WHERE ChecklistTemplateId = @ServiceTemplateId AND SortOrder = 2)
        INSERT INTO dbo.ChecklistTemplateItem (ChecklistTemplateId, ItemName, Instructions, IsMandatory, RequiresEvidence, RequiresManagerApproval, SortOrder)
        VALUES (@ServiceTemplateId, N'Kiểm tra dụng cụ', N'Kiểm tra dụng cụ và vật tư trong ca', 1, 0, 0, 2);

    DECLARE @History TABLE (DayOffset INT PRIMARY KEY, ShiftAssignmentId BIGINT, AttendanceId BIGINT);
    INSERT INTO @History (DayOffset, ShiftAssignmentId)
    SELECT v.DayOffset, sa.ShiftAssignmentId
    FROM (VALUES (1, @MorningShiftId), (2, @AfternoonShiftId), (3, @EveningShiftId)) v(DayOffset, WorkShiftId)
    JOIN dbo.ShiftAssignment sa ON sa.EmployeeId = @EmployeeId
        AND sa.WorkShiftId = v.WorkShiftId AND sa.WorkDate = DATEADD(DAY, -v.DayOffset, @Today);

    INSERT INTO dbo.Attendance
        (ShiftAssignmentId, EmployeeId, CheckInAt, CheckOutAt,
         CheckInLatitude, CheckInLongitude, CheckInAccuracyM,
         CheckOutLatitude, CheckOutLongitude, CheckOutAccuracyM,
         CheckInMethod, CheckOutMethod, AttendanceStatus, LateMinutes,
         WorkedMinutes, CheckInDeviceId, CheckOutDeviceId, GraceApplied, Note)
    SELECT h.ShiftAssignmentId, @EmployeeId,
           DATEADD(MINUTE, CASE WHEN h.DayOffset = 3 THEN 12 ELSE 0 END, sa.PlannedStartAt),
           sa.PlannedEndAt, st.Latitude, st.Longitude, 5.0,
           st.Latitude, st.Longitude, 5.0, 'GPS', 'GPS',
           CASE WHEN h.DayOffset = 3 THEN 'LATE' ELSE 'PRESENT' END,
           CASE WHEN h.DayOffset = 3 THEN 7 ELSE 0 END,
           DATEDIFF(MINUTE, sa.PlannedStartAt, sa.PlannedEndAt) - ws.BreakMinutes,
           dev.DeviceId, dev.DeviceId, 0, N'Bản ghi demo lịch sử; mẫu thứ ba minh họa có mặt muộn'
    FROM @History h
    JOIN dbo.ShiftAssignment sa ON sa.ShiftAssignmentId = h.ShiftAssignmentId
    JOIN dbo.WorkShift ws ON ws.WorkShiftId = sa.WorkShiftId
    JOIN dbo.Store st ON st.StoreId = @StoreId
    JOIN dbo.AttendanceDevice dev ON dev.EmployeeId = @EmployeeId AND dev.Status = 'ACTIVE'
    WHERE NOT EXISTS (SELECT 1 FROM dbo.Attendance a WHERE a.ShiftAssignmentId = h.ShiftAssignmentId);

    UPDATE h SET AttendanceId = a.AttendanceId
    FROM @History h JOIN dbo.Attendance a ON a.ShiftAssignmentId = h.ShiftAssignmentId;

    INSERT INTO dbo.AttendanceVerification
        (AttendanceId, DeviceId, VerificationType, EventType, Latitude, Longitude, AccuracyMeters,
         DistanceMeters, VerificationStatus, VerifiedAt, RetainUntil)
    SELECT h.AttendanceId, dev.DeviceId, 'GPS', 'CHECK_IN', st.Latitude, st.Longitude, 5.0,
           5.0, 'PASSED', a.CheckInAt, DATEADD(MONTH, 12, CAST(a.CheckInAt AS DATE))
    FROM @History h
    JOIN dbo.Attendance a ON a.AttendanceId = h.AttendanceId
    JOIN dbo.Store st ON st.StoreId = @StoreId
    JOIN dbo.AttendanceDevice dev ON dev.DeviceId = a.CheckInDeviceId
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.AttendanceVerification v
        WHERE v.AttendanceId = a.AttendanceId AND v.EventType = 'CHECK_IN' AND v.VerificationType = 'GPS'
    );

    INSERT INTO dbo.AttendanceSpotCheck
        (AttendanceId, EmployeeId, ShiftAssignmentId, IsSelected, Status, RequestedAt, ResponseDeadlineAt, RespondedAt)
    SELECT h.AttendanceId, @EmployeeId, h.ShiftAssignmentId, v.IsSelected, v.Status,
           CASE WHEN v.Status IN ('VERIFIED','MISSED') THEN DATEADD(HOUR, 1, a.CheckInAt) END,
           CASE WHEN v.Status IN ('VERIFIED','MISSED') THEN DATEADD(HOUR, 1, DATEADD(MINUTE, 5, a.CheckInAt)) END,
           CASE WHEN v.Status = 'VERIFIED' THEN DATEADD(HOUR, 1, DATEADD(MINUTE, 2, a.CheckInAt)) END
    FROM @History h
    JOIN dbo.Attendance a ON a.AttendanceId = h.AttendanceId
    JOIN (VALUES (1, CAST(1 AS BIT), 'VERIFIED'), (2, CAST(1 AS BIT), 'MISSED'), (3, CAST(0 AS BIT), 'CANCELLED'))
         v(DayOffset, IsSelected, Status) ON v.DayOffset = h.DayOffset
    WHERE NOT EXISTS (SELECT 1 FROM dbo.AttendanceSpotCheck c WHERE c.AttendanceId = h.AttendanceId);

    INSERT INTO dbo.OvertimeRequest (ShiftAssignmentId, EmployeeId, RequestedStartAt, RequestedEndAt, Reason, ApprovalStatus, RequestedAt)
    SELECT h.ShiftAssignmentId, @EmployeeId, sa.PlannedEndAt, DATEADD(HOUR, 1, sa.PlannedEndAt),
           CONCAT(N'Demo xin tăng ca cho ca ngày ', CONVERT(VARCHAR(10), sa.WorkDate, 23)), 'PENDING', DATEADD(DAY, -h.DayOffset, SYSUTCDATETIME())
    FROM @History h JOIN dbo.ShiftAssignment sa ON sa.ShiftAssignmentId = h.ShiftAssignmentId
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.OvertimeRequest o
        WHERE o.ShiftAssignmentId = h.ShiftAssignmentId AND o.Reason = CONCAT(N'Demo xin tăng ca cho ca ngày ', CONVERT(VARCHAR(10), sa.WorkDate, 23))
    );

    INSERT INTO dbo.AttendanceExceptionRequest
        (EmployeeId, ShiftAssignmentId, AttendanceId, RequestType, Reason, RequestStatus, SubmittedAt)
    SELECT @EmployeeId, h.ShiftAssignmentId, h.AttendanceId, v.RequestType,
           CONCAT(N'Giải trình demo cho ca ngày ', CONVERT(VARCHAR(10), sa.WorkDate, 23)), 'PENDING', DATEADD(DAY, -h.DayOffset, SYSUTCDATETIME())
    FROM @History h
    JOIN dbo.ShiftAssignment sa ON sa.ShiftAssignmentId = h.ShiftAssignmentId
    JOIN (VALUES (1, 'CAMERA_ISSUE'), (2, 'DEVICE_ISSUE'), (3, 'OTHER')) v(DayOffset, RequestType)
        ON v.DayOffset = h.DayOffset
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.AttendanceExceptionRequest e
        WHERE e.ShiftAssignmentId = h.ShiftAssignmentId AND e.Reason = CONCAT(N'Giải trình demo cho ca ngày ', CONVERT(VARCHAR(10), sa.WorkDate, 23))
    );

    INSERT INTO dbo.AttendanceAdjustmentRequest
        (AttendanceId, RequestedBy, FieldName, OldValue, NewValue, Reason, ManagerStatus, HrStatus, CreatedAt)
    SELECT h.AttendanceId, @EmployeeUserId, 'CHECK_IN', CONVERT(VARCHAR(30), a.CheckInAt, 126),
           CONVERT(VARCHAR(30), DATEADD(MINUTE, -1, a.CheckInAt), 126),
           CONCAT(N'Điều chỉnh demo chờ quản lý cho ca ', h.DayOffset), 'PENDING', 'PENDING', DATEADD(DAY, -h.DayOffset, SYSUTCDATETIME())
    FROM @History h JOIN dbo.Attendance a ON a.AttendanceId = h.AttendanceId
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.AttendanceAdjustmentRequest r
        WHERE r.AttendanceId = h.AttendanceId AND r.FieldName = 'CHECK_IN' AND r.Reason = CONCAT(N'Điều chỉnh demo chờ quản lý cho ca ', h.DayOffset)
    );

    INSERT INTO dbo.AttendanceAdjustmentRequest
        (AttendanceId, RequestedBy, FieldName, OldValue, NewValue, Reason,
         ManagerStatus, ManagerReviewedBy, ManagerReviewedAt, HrStatus, HrReviewedBy, HrReviewedAt, CreatedAt)
    SELECT h.AttendanceId, @EmployeeUserId, 'WORKED_MINUTES',
           CONVERT(VARCHAR(20), a.WorkedMinutes), CONVERT(VARCHAR(20), a.WorkedMinutes + 5),
           CONCAT(N'Điều chỉnh demo đã duyệt cho ca ', h.DayOffset),
           'APPROVED', @ManagerUserId, DATEADD(DAY, -h.DayOffset, SYSUTCDATETIME()),
           'APPROVED', @AdminUserId, DATEADD(DAY, -h.DayOffset, SYSUTCDATETIME()),
           DATEADD(DAY, -h.DayOffset, SYSUTCDATETIME())
    FROM @History h JOIN dbo.Attendance a ON a.AttendanceId = h.AttendanceId
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.AttendanceAdjustmentRequest r
        WHERE r.AttendanceId = h.AttendanceId AND r.FieldName = 'WORKED_MINUTES' AND r.Reason = CONCAT(N'Điều chỉnh demo đã duyệt cho ca ', h.DayOffset)
    );

    INSERT INTO dbo.AttendanceAdjustmentHistory
        (AttendanceAdjustmentRequestId, AttendanceId, FieldName, OldValue, NewValue, ChangedBy, ChangedAt)
    SELECT r.AttendanceAdjustmentRequestId, r.AttendanceId, r.FieldName, r.OldValue, r.NewValue,
           @AdminUserId, r.HrReviewedAt
    FROM dbo.AttendanceAdjustmentRequest r
    JOIN @History h ON h.AttendanceId = r.AttendanceId
    WHERE r.FieldName = 'WORKED_MINUTES' AND r.ManagerStatus = 'APPROVED' AND r.HrStatus = 'APPROVED'
      AND r.Reason = CONCAT(N'Điều chỉnh demo đã duyệt cho ca ', h.DayOffset)
      AND NOT EXISTS (SELECT 1 FROM dbo.AttendanceAdjustmentHistory x WHERE x.AttendanceAdjustmentRequestId = r.AttendanceAdjustmentRequestId);

    DECLARE @ChecklistRuns TABLE (DayOffset INT PRIMARY KEY, TaskId BIGINT, Status VARCHAR(20));
    INSERT INTO dbo.ChecklistInstance (ChecklistTemplateId, WorkDate, WorkShiftId)
    SELECT v.TemplateId, sa.WorkDate, sa.WorkShiftId
    FROM (VALUES
        (1, @OpenTemplateId), (2, @HandoverTemplateId), (3, @ServiceTemplateId),
        (4, @OpenTemplateId), (5, @HandoverTemplateId), (6, @ServiceTemplateId)
    ) v(DayOffset, TemplateId)
    JOIN dbo.ShiftAssignment sa ON sa.EmployeeId = @EmployeeId AND sa.WorkDate = DATEADD(DAY, -v.DayOffset, @Today)
    WHERE v.TemplateId IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM dbo.ChecklistInstance i
        WHERE i.ChecklistTemplateId = v.TemplateId AND i.WorkDate = sa.WorkDate AND i.WorkShiftId = sa.WorkShiftId
      );

    INSERT INTO dbo.ChecklistTask
        (ChecklistTemplateId, ShiftAssignmentId, EmployeeId, DueAt, StartedAt, SubmittedAt, RunStatus, ManagerStatus, ChecklistInstanceId)
    SELECT v.TemplateId, sa.ShiftAssignmentId, @EmployeeId,
           DATEADD(HOUR, 3, sa.PlannedEndAt), DATEADD(MINUTE, 15, sa.PlannedStartAt),
           DATEADD(MINUTE, 30, sa.PlannedStartAt), v.RunStatus, v.ManagerStatus, i.ChecklistInstanceId
    FROM (VALUES
        (1, @OpenTemplateId, 'SUBMITTED', 'PENDING'),
        (2, @HandoverTemplateId, 'SUBMITTED', 'PENDING'),
        (3, @ServiceTemplateId, 'SUBMITTED', 'PENDING'),
        (4, @OpenTemplateId, 'APPROVED', 'APPROVED'),
        (5, @HandoverTemplateId, 'REJECTED', 'REJECTED'),
        (6, @ServiceTemplateId, 'APPROVED', 'APPROVED')
    ) v(DayOffset, TemplateId, RunStatus, ManagerStatus)
    JOIN dbo.ShiftAssignment sa ON sa.EmployeeId = @EmployeeId AND sa.WorkDate = DATEADD(DAY, -v.DayOffset, @Today)
    JOIN dbo.ChecklistInstance i ON i.ChecklistTemplateId = v.TemplateId AND i.WorkDate = sa.WorkDate AND i.WorkShiftId = sa.WorkShiftId
    WHERE v.TemplateId IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM dbo.ChecklistTask t WHERE t.ShiftAssignmentId = sa.ShiftAssignmentId AND t.ChecklistTemplateId = v.TemplateId);

    INSERT INTO @ChecklistRuns (DayOffset, TaskId, Status)
    SELECT v.DayOffset, t.ChecklistTaskId, v.RunStatus
    FROM (VALUES
        (1, 'SUBMITTED'), (2, 'SUBMITTED'), (3, 'SUBMITTED'),
        (4, 'APPROVED'), (5, 'REJECTED'), (6, 'APPROVED')
    ) v(DayOffset, RunStatus)
    JOIN dbo.ShiftAssignment sa ON sa.EmployeeId = @EmployeeId AND sa.WorkDate = DATEADD(DAY, -v.DayOffset, @Today)
    JOIN dbo.ChecklistTask t ON t.ShiftAssignmentId = sa.ShiftAssignmentId;

    INSERT INTO dbo.ChecklistTaskItem (ChecklistTaskId, ChecklistTemplateItemId, IsCompleted, CompletedAt, CompletedBy, Note)
    SELECT r.TaskId, ti.ChecklistTemplateItemId, 1, DATEADD(MINUTE, 30, sa.PlannedStartAt), @EmployeeUserId, N'Đã hoàn tất dữ liệu demo'
    FROM @ChecklistRuns r
    JOIN dbo.ChecklistTask t ON t.ChecklistTaskId = r.TaskId
    JOIN dbo.ShiftAssignment sa ON sa.ShiftAssignmentId = t.ShiftAssignmentId
    JOIN dbo.ChecklistTemplateItem ti ON ti.ChecklistTemplateId = t.ChecklistTemplateId
    WHERE NOT EXISTS (
        SELECT 1 FROM dbo.ChecklistTaskItem x
        WHERE x.ChecklistTaskId = r.TaskId AND x.ChecklistTemplateItemId = ti.ChecklistTemplateItemId
    );

    INSERT INTO dbo.ChecklistEvidence (ChecklistTaskId, ChecklistTaskItemId, StorageKey, UploadedBy, UploadedAt)
    SELECT r.TaskId, ti.ChecklistTaskItemId,
           CONCAT('demo/checklist-evidence/task-', r.TaskId, '-item-', ti.ChecklistTaskItemId, '.txt'),
           @EmployeeUserId, DATEADD(MINUTE, 30, sa.PlannedStartAt)
    FROM @ChecklistRuns r
    JOIN dbo.ChecklistTask t ON t.ChecklistTaskId = r.TaskId
    JOIN dbo.ShiftAssignment sa ON sa.ShiftAssignmentId = t.ShiftAssignmentId
    CROSS APPLY (SELECT TOP (1) ChecklistTaskItemId FROM dbo.ChecklistTaskItem i WHERE i.ChecklistTaskId = r.TaskId ORDER BY ChecklistTaskItemId) ti
    WHERE r.DayOffset <= 3
      AND NOT EXISTS (SELECT 1 FROM dbo.ChecklistEvidence e WHERE e.ChecklistTaskId = r.TaskId);

    INSERT INTO dbo.ChecklistReview (ChecklistTaskId, ReviewerId, Decision, Reason, ReviewedAt)
    SELECT r.TaskId, @ManagerUserId, r.Status,
           CASE WHEN r.Status = 'REJECTED' THEN N'Dữ liệu demo: cần bổ sung mục bàn giao' ELSE N'Dữ liệu demo: checklist đã được duyệt' END,
           DATEADD(DAY, -r.DayOffset, SYSUTCDATETIME())
    FROM @ChecklistRuns r
    WHERE r.DayOffset > 3
      AND NOT EXISTS (SELECT 1 FROM dbo.ChecklistReview x WHERE x.ChecklistTaskId = r.TaskId);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

-- Training, violations, reward decisions, payroll periods, and operational logs.
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @Today DATE = CAST(DATEADD(HOUR, 7, SYSUTCDATETIME()) AS DATE);
    DECLARE @AdminUserId BIGINT = (SELECT UserId FROM dbo.AppUser WHERE Email = 'baonvhe181955@fpt.edu.vn');
    DECLARE @ManagerUserId BIGINT = (SELECT UserId FROM dbo.AppUser WHERE Email = 'baonvchaos@gmail.com');
    DECLARE @EmployeeUserId BIGINT = (SELECT UserId FROM dbo.AppUser WHERE Email = 'panchisuru@gmail.com');
    DECLARE @EmployeeId BIGINT = (SELECT EmployeeId FROM dbo.Employee WHERE UserId = @EmployeeUserId);
    DECLARE @FoodCourseId INT = (SELECT CourseId FROM dbo.TrainingCourse WHERE CourseCode = 'FOOD_SAFETY_101');
    DECLARE @RulesCourseId INT = (SELECT CourseId FROM dbo.TrainingCourse WHERE CourseCode = 'HOUSE_RULES');
    DECLARE @BaristaCourseId INT = (SELECT CourseId FROM dbo.TrainingCourse WHERE CourseCode = 'BARISTA_BASIC');
    DECLARE @LateRuleId INT = (SELECT RuleId FROM dbo.RuleCatalog WHERE RuleCode = 'LATE_MINOR');
    DECLARE @SpotMissedRuleId INT = (SELECT RuleId FROM dbo.RuleCatalog WHERE RuleCode = 'ATTENDANCE_SPOT_CHECK_MISSED');
    DECLARE @ServiceRuleId INT = (SELECT RuleId FROM dbo.RuleCatalog WHERE RuleCode = 'SERVICE_ISSUE');
    DECLARE @ComplimentRuleId INT = (SELECT RuleId FROM dbo.RuleCatalog WHERE RuleCode = 'CUSTOMER_COMPLIMENT');
    DECLARE @KpiRuleId INT = (SELECT RuleId FROM dbo.RuleCatalog WHERE RuleCode = 'KPI_EXCEEDED');
    DECLARE @HistoryAttendance1 BIGINT = (SELECT a.AttendanceId FROM dbo.Attendance a JOIN dbo.ShiftAssignment sa ON sa.ShiftAssignmentId = a.ShiftAssignmentId WHERE sa.EmployeeId = @EmployeeId AND sa.WorkDate = DATEADD(DAY, -1, @Today));
    DECLARE @HistoryAttendance2 BIGINT = (SELECT a.AttendanceId FROM dbo.Attendance a JOIN dbo.ShiftAssignment sa ON sa.ShiftAssignmentId = a.ShiftAssignmentId WHERE sa.EmployeeId = @EmployeeId AND sa.WorkDate = DATEADD(DAY, -2, @Today));
    DECLARE @HistoryAttendance3 BIGINT = (SELECT a.AttendanceId FROM dbo.Attendance a JOIN dbo.ShiftAssignment sa ON sa.ShiftAssignmentId = a.ShiftAssignmentId WHERE sa.EmployeeId = @EmployeeId AND sa.WorkDate = DATEADD(DAY, -3, @Today));
    DECLARE @LateViolationId BIGINT;

    -- Heal the two demo violations created without AttendanceId if a prior seed run
    -- stopped before the attendance/checklist batch could complete.
    UPDATE v
       SET AttendanceId = @HistoryAttendance3, SourceType = 'ATTENDANCE', SourceId = @HistoryAttendance3
    FROM dbo.ViolationEvent v
    WHERE @HistoryAttendance3 IS NOT NULL AND v.EmployeeId = @EmployeeId AND v.RuleId = @LateRuleId
      AND v.AttendanceId IS NULL AND v.Details = N'Dữ liệu demo: có mặt muộn 7 phút sau ân hạn';

    UPDATE v
       SET AttendanceId = @HistoryAttendance2, SourceType = 'ATTENDANCE', SourceId = @HistoryAttendance2
    FROM dbo.ViolationEvent v
    WHERE @HistoryAttendance2 IS NOT NULL AND v.EmployeeId = @EmployeeId AND v.RuleId = @SpotMissedRuleId
      AND v.AttendanceId IS NULL AND v.Details = N'Dữ liệu demo: không phản hồi kiểm tra giữa ca';

    INSERT INTO dbo.UserPermission (UserId, PermissionId, GrantedBy)
    SELECT @AdminUserId, p.PermissionId, @AdminUserId
    FROM dbo.Permission p WHERE p.PermissionCode = 'ATTENDANCE_ADJUST_HR'
      AND NOT EXISTS (SELECT 1 FROM dbo.UserPermission up WHERE up.UserId = @AdminUserId AND up.PermissionId = p.PermissionId);

    INSERT INTO dbo.PositionTrainingRequirement (PositionId, CourseId, IsMandatory, BlocksShiftAssignment, EffectiveFrom)
    SELECT p.PositionId, c.CourseId, 1, 1, '2000-01-01'
    FROM dbo.JobPosition p CROSS JOIN dbo.TrainingCourse c
    WHERE c.CourseCode = 'FOOD_SAFETY_101'
      AND NOT EXISTS (SELECT 1 FROM dbo.PositionTrainingRequirement r
          WHERE r.PositionId = p.PositionId AND r.CourseId = c.CourseId AND r.EffectiveFrom = '2000-01-01');

    INSERT INTO dbo.TrainingAttempt (EmployeeId, CourseId, AttemptNo, Score, IsPassed, Source, RecordedBy, RecordedAt, AnswersJson)
    SELECT @EmployeeId, c.CourseId, v.AttemptNo, v.Score, v.IsPassed, 'QUIZ', @EmployeeUserId,
           DATEADD(DAY, -v.DaysAgo, SYSUTCDATETIME()), v.AnswersJson
    FROM (VALUES
        ('FOOD_SAFETY_101', 1, CAST(92.0 AS DECIMAL(5,2)), CAST(1 AS BIT), 25, N'{"1":"A","2":"B"}'),
        ('HOUSE_RULES', 1, CAST(88.0 AS DECIMAL(5,2)), CAST(1 AS BIT), 20, N'{"1":"B","2":"A"}'),
        ('BARISTA_BASIC', 1, CAST(55.0 AS DECIMAL(5,2)), CAST(0 AS BIT), 10, N'{"1":"C","2":"D"}')
    ) v(CourseCode, AttemptNo, Score, IsPassed, DaysAgo, AnswersJson)
    JOIN dbo.TrainingCourse c ON c.CourseCode = v.CourseCode
    WHERE NOT EXISTS (SELECT 1 FROM dbo.TrainingAttempt a WHERE a.EmployeeId = @EmployeeId AND a.CourseId = c.CourseId AND a.AttemptNo = v.AttemptNo);

    INSERT INTO dbo.TrainingQuestion (CourseId, QuestionText, OptionA, OptionB, OptionC, OptionD, CorrectOption, SortOrder)
    SELECT @FoodCourseId, v.QuestionText, v.OptionA, v.OptionB, v.OptionC, v.OptionD, v.CorrectOption, v.SortOrder
    FROM (VALUES
        (N'Nhiệt độ bảo quản lạnh phù hợp giúp hạn chế điều gì?', N'Vi khuẩn phát triển', N'Màu cốc thay đổi', N'Máy pha nóng lên', N'Không điều nào', 'A', 1),
        (N'Khi nào cần rửa tay trước khi chế biến?', N'Chỉ cuối ca', N'Trước và sau khi xử lý thực phẩm', N'Chỉ khi quản lý nhắc', N'Không cần', 'B', 2),
        (N'Thực phẩm sống nên được bảo quản thế nào?', N'Đặt trên thực phẩm chín', N'Để chung mọi loại', N'Tách riêng và đậy kín', N'Để ngoài quầy', 'C', 3)
    ) v(QuestionText, OptionA, OptionB, OptionC, OptionD, CorrectOption, SortOrder)
    WHERE NOT EXISTS (SELECT 1 FROM dbo.TrainingQuestion q WHERE q.CourseId = @FoodCourseId AND q.SortOrder = v.SortOrder);

    INSERT INTO dbo.Skill (SkillCode, SkillName, Description)
    SELECT v.SkillCode, v.SkillName, v.Description
    FROM (VALUES
        ('CUSTOMER_SERVICE', N'Phục vụ khách hàng', N'Giao tiếp và hỗ trợ khách hàng'),
        ('BEVERAGE_PREP', N'Pha chế đồ uống', N'Thực hiện công thức và thao tác pha chế'),
        ('CASH_HANDLING', N'Quản lý tiền mặt', N'Thu ngân và đối soát tiền')
    ) v(SkillCode, SkillName, Description)
    WHERE NOT EXISTS (SELECT 1 FROM dbo.Skill s WHERE s.SkillCode = v.SkillCode);

    INSERT INTO dbo.EmployeeSkill (EmployeeId, SkillId, SkillLevel, Note, AssessedBy, AssessedAt)
    SELECT @EmployeeId, s.SkillId, v.SkillLevel, v.Note, @ManagerUserId, DATEADD(DAY, -v.DaysAgo, SYSUTCDATETIME())
    FROM (VALUES
        ('CUSTOMER_SERVICE', 4, N'Đánh giá demo: giao tiếp tốt', 12),
        ('BEVERAGE_PREP', 3, N'Đánh giá demo: đạt yêu cầu cơ bản', 9),
        ('CASH_HANDLING', 3, N'Đánh giá demo: cần tiếp tục luyện tập', 6)
    ) v(SkillCode, SkillLevel, Note, DaysAgo)
    JOIN dbo.Skill s ON s.SkillCode = v.SkillCode
    WHERE NOT EXISTS (SELECT 1 FROM dbo.EmployeeSkill es WHERE es.EmployeeId = @EmployeeId AND es.SkillId = s.SkillId AND es.Note = v.Note);

    INSERT INTO dbo.AttendanceVerificationAttempt
        (EmployeeId, ShiftAssignmentId, EventType, VerificationType, FailureCode, DeviceId, AttemptedAt)
    SELECT @EmployeeId, sa.ShiftAssignmentId, v.EventType, 'GPS', v.FailureCode, dev.DeviceId,
           DATEADD(DAY, -v.DayOffset, SYSUTCDATETIME())
    FROM (VALUES (1, 'CHECK_IN', 'GPS_STALE'), (2, 'CHECK_OUT', 'GPS_OUTSIDE_RADIUS'), (3, 'SPOT_CHECK', 'GPS_LOW_ACCURACY'))
         v(DayOffset, EventType, FailureCode)
    JOIN dbo.ShiftAssignment sa ON sa.EmployeeId = @EmployeeId AND sa.WorkDate = DATEADD(DAY, -v.DayOffset, @Today)
    JOIN dbo.AttendanceDevice dev ON dev.EmployeeId = @EmployeeId AND dev.Status = 'ACTIVE'
    WHERE NOT EXISTS (SELECT 1 FROM dbo.AttendanceVerificationAttempt a
        WHERE a.ShiftAssignmentId = sa.ShiftAssignmentId AND a.EventType = v.EventType AND a.FailureCode = v.FailureCode);

    DECLARE @ReviewTaskId BIGINT = (
        SELECT TOP (1) t.ChecklistTaskId
        FROM dbo.ChecklistTask t JOIN dbo.ShiftAssignment sa ON sa.ShiftAssignmentId = t.ShiftAssignmentId
        WHERE t.EmployeeId = @EmployeeId AND sa.WorkDate = DATEADD(DAY, -5, @Today)
        ORDER BY t.ChecklistTaskId
    );

    INSERT INTO dbo.ViolationEvent
        (EmployeeId, RuleId, AttendanceId, SourceType, SourceId, Details, RecordStatus, IsAutoGenerated, CreatedBy, OccurredAt)
    SELECT @EmployeeId, @LateRuleId, @HistoryAttendance3, 'ATTENDANCE', @HistoryAttendance3,
           N'Dữ liệu demo: có mặt muộn 7 phút sau ân hạn', 'PENDING', 1, @ManagerUserId, DATEADD(DAY, -3, SYSUTCDATETIME())
    WHERE NOT EXISTS (SELECT 1 FROM dbo.ViolationEvent v WHERE v.EmployeeId = @EmployeeId AND v.RuleId = @LateRuleId AND v.AttendanceId = @HistoryAttendance3);
    INSERT INTO dbo.ViolationEvent
        (EmployeeId, RuleId, AttendanceId, SourceType, SourceId, Details, RecordStatus, IsAutoGenerated, CreatedBy, OccurredAt)
    SELECT @EmployeeId, @SpotMissedRuleId, @HistoryAttendance2, 'ATTENDANCE', @HistoryAttendance2,
           N'Dữ liệu demo: không phản hồi kiểm tra giữa ca', 'PENDING', 1, @ManagerUserId, DATEADD(DAY, -2, SYSUTCDATETIME())
    WHERE NOT EXISTS (SELECT 1 FROM dbo.ViolationEvent v WHERE v.EmployeeId = @EmployeeId AND v.RuleId = @SpotMissedRuleId AND v.AttendanceId = @HistoryAttendance2);
    INSERT INTO dbo.ViolationEvent
        (EmployeeId, RuleId, ChecklistTaskId, SourceType, SourceId, Details, RecordStatus, IsAutoGenerated, CreatedBy, OccurredAt)
    SELECT @EmployeeId, @ServiceRuleId, NULL, 'MANUAL', NULL,
           N'Dữ liệu demo: cần quản lý xem xét vấn đề dịch vụ', 'PENDING', 0, @ManagerUserId, DATEADD(DAY, -1, SYSUTCDATETIME())
    WHERE NOT EXISTS (SELECT 1 FROM dbo.ViolationEvent v WHERE v.EmployeeId = @EmployeeId AND v.RuleId = @ServiceRuleId AND v.Details = N'Dữ liệu demo: cần quản lý xem xét vấn đề dịch vụ');

    SET @LateViolationId = (SELECT TOP (1) ViolationEventId FROM dbo.ViolationEvent WHERE EmployeeId = @EmployeeId AND RuleId = @LateRuleId AND AttendanceId = @HistoryAttendance3 ORDER BY ViolationEventId);
    UPDATE d
       SET ViolationEventId = @LateViolationId
    FROM dbo.EmployeeRewardPenalty d
    WHERE @LateViolationId IS NOT NULL AND d.EmployeeId = @EmployeeId AND d.ProposedBy = @ManagerUserId
      AND d.Details = N'Demo phạt: vi phạm đi muộn cần xem xét' AND d.ViolationEventId IS NULL;
    DECLARE @SpotMissedViolationId BIGINT = (
        SELECT TOP (1) ViolationEventId FROM dbo.ViolationEvent
        WHERE EmployeeId = @EmployeeId AND RuleId = @SpotMissedRuleId AND AttendanceId = @HistoryAttendance2
        ORDER BY ViolationEventId
    );
    DECLARE @ServiceViolationId BIGINT = (
        SELECT TOP (1) ViolationEventId FROM dbo.ViolationEvent
        WHERE EmployeeId = @EmployeeId AND RuleId = @ServiceRuleId
          AND Details = N'Dữ liệu demo: cần quản lý xem xét vấn đề dịch vụ'
        ORDER BY ViolationEventId
    );

    INSERT INTO dbo.ViolationExplanation (ViolationEventId, EmployeeId, Reason, CreatedAt)
    SELECT v.ViolationEventId, @EmployeeId, x.Reason, DATEADD(DAY, -x.DaysAgo, SYSUTCDATETIME())
    FROM (VALUES
        (@LateViolationId, N'Giải trình demo: xe gặp sự cố trên đường', 2),
        (@SpotMissedViolationId, N'Giải trình demo: không nhìn thấy thông báo kiểm tra', 1),
        (@ServiceViolationId, N'Giải trình demo: đã trao đổi với khách hàng', 1)
    ) x(ViolationEventId, Reason, DaysAgo)
    JOIN dbo.ViolationEvent v ON v.ViolationEventId = x.ViolationEventId
    WHERE NOT EXISTS (SELECT 1 FROM dbo.ViolationExplanation e WHERE e.ViolationEventId = v.ViolationEventId AND e.Reason = x.Reason);

    INSERT INTO dbo.EmployeeRewardPenalty
        (DecisionType, EmployeeId, RuleId, ViolationEventId, EffectiveDate, Details, Amount, DecisionStatus, ProposedBy)
    SELECT v.DecisionType, @EmployeeId, r.RuleId, v.ViolationEventId, DATEADD(DAY, -v.DaysAgo, SYSUTCDATETIME()),
           v.Details, v.Amount, 'PENDING', @ManagerUserId
    FROM (VALUES
        ('REWARD', 'CUSTOMER_COMPLIMENT', CAST(NULL AS BIGINT), N'Demo thưởng: được khách hàng khen', CAST(100000 AS DECIMAL(12,2)), 10),
        ('REWARD', 'KPI_EXCEEDED', CAST(NULL AS BIGINT), N'Demo thưởng: hoàn thành KPI', CAST(150000 AS DECIMAL(12,2)), 7),
        ('PENALTY', 'LATE_MINOR', @LateViolationId, N'Demo phạt: vi phạm đi muộn cần xem xét', CAST(0 AS DECIMAL(12,2)), 3)
    ) v(DecisionType, RuleCode, ViolationEventId, Details, Amount, DaysAgo)
    JOIN dbo.RuleCatalog r ON r.RuleCode = v.RuleCode
    WHERE NOT EXISTS (SELECT 1 FROM dbo.EmployeeRewardPenalty d WHERE d.EmployeeId = @EmployeeId AND d.ProposedBy = @ManagerUserId AND d.Details = v.Details);

    INSERT INTO dbo.PayrollPeriod (PeriodCode, StartDate, EndDate, PeriodStatus, CreatedBy, Note)
    SELECT v.PeriodCode, DATEADD(MONTH, v.MonthOffset, DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1)),
           EOMONTH(DATEADD(MONTH, v.MonthOffset, DATEFROMPARTS(YEAR(@Today), MONTH(@Today), 1))),
           'OPEN', @ManagerUserId, N'Kỳ công demo để kiểm tra danh sách'
    FROM (VALUES ('DEMO-01', -2), ('DEMO-02', -1), ('DEMO-03', 0)) v(PeriodCode, MonthOffset)
    WHERE NOT EXISTS (SELECT 1 FROM dbo.PayrollPeriod p WHERE p.PeriodCode = v.PeriodCode);

    INSERT INTO dbo.Notification (UserId, NotificationType, Title, Message, DeliveryStatus, AttemptCount, CreatedAt, SentAt, DedupKey)
    SELECT v.UserId, 'DEMO_NOTICE', v.Title, v.Message, 'SENT', 1, DATEADD(DAY, -v.DaysAgo, SYSUTCDATETIME()),
           DATEADD(DAY, -v.DaysAgo, SYSUTCDATETIME()), v.DedupKey
    FROM (VALUES
        (@AdminUserId, N'Dữ liệu demo hệ thống', N'Tài khoản quản trị đã sẵn sàng.', 3, 'DEMO-NOTICE-ADMIN'),
        (@ManagerUserId, N'Dữ liệu demo công việc', N'Mở Trung tâm công việc để xử lý các hàng đợi demo.', 2, 'DEMO-NOTICE-MANAGER'),
        (@EmployeeUserId, N'Dữ liệu demo lịch sử', N'Lịch làm và lịch sử chấm công demo đã được tạo.', 1, 'DEMO-NOTICE-EMPLOYEE')
    ) v(UserId, Title, Message, DaysAgo, DedupKey)
    WHERE NOT EXISTS (SELECT 1 FROM dbo.Notification n WHERE n.DedupKey = v.DedupKey);

    INSERT INTO dbo.AuditLog (ActorUserId, ActionCode, EntityType, EntityId, AfterJson, UserAgent, CreatedAt)
    SELECT @AdminUserId, 'DEMO_DATA_INITIALIZED', 'DemoData', v.EntityId, v.AfterJson, N'SEEDDATA', DATEADD(DAY, -v.DaysAgo, SYSUTCDATETIME())
    FROM (VALUES
        ('accounts', N'{"accounts":3}', 3),
        ('shift-history', N'{"historicalDays":30}', 2),
        ('approval-queues', N'{"demoRecords":3}', 1)
    ) v(EntityId, AfterJson, DaysAgo)
    WHERE NOT EXISTS (SELECT 1 FROM dbo.AuditLog a WHERE a.ActionCode = 'DEMO_DATA_INITIALIZED' AND a.EntityId = v.EntityId);

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO


-- Report row counts; the demo is intentionally rich enough to exercise every table.
DECLARE @CountSql NVARCHAR(MAX);
DECLARE @Counts TABLE (TableName SYSNAME NOT NULL, RowTotal BIGINT NOT NULL);
SELECT @CountSql = STRING_AGG(
    CONVERT(NVARCHAR(MAX), N'SELECT N''' + REPLACE(t.name, N'''', N'''''') + N''' AS TableName, COUNT_BIG(*) AS RowTotal FROM ' + QUOTENAME(s.name) + N'.' + QUOTENAME(t.name)),
    N' UNION ALL ')
FROM sys.tables t JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE s.name = 'dbo';
INSERT INTO @Counts EXEC sys.sp_executesql @CountSql;
SELECT TableName, RowTotal FROM @Counts ORDER BY TableName;
IF EXISTS (SELECT 1 FROM @Counts WHERE RowTotal < 3)
    THROW 51011, N'Có bảng chưa đủ ba dòng dữ liệu demo; xem báo cáo số dòng ở trên.', 1;
GO

