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
    INSERT INTO dbo.AppUser (Email, DisplayName, UserStatus) VALUES ('baonvhe181955@fpt.edu.vn', N'System Admin', 'ACTIVE');
    INSERT INTO dbo.UserRole (UserId, RoleId)
    SELECT u.UserId, r.RoleId FROM dbo.AppUser u CROSS JOIN dbo.Role r
    WHERE u.Email='baonvhe181955@fpt.edu.vn' AND r.RoleCode='SYSTEM_ADMIN';
END
GO

GO

-- =====================================================================================
-- DỮ LIỆU TEST (chỉ để thử API; XÓA CẢ KHỐI NÀY khi lên production)
-- Chạy lại nhiều lần vẫn an toàn: nếu cửa hàng CF-HN01 đã có thì bỏ qua. Lỗi giữa chừng sẽ rollback toàn bộ.
-- Mọi mốc thời gian tính theo NGÀY CHẠY SCRIPT (giờ VN), nên lịch "hôm nay" luôn mới.
--
-- Tài khoản (chưa có mật khẩu: đặt DEV_PASSWORD_LOGIN_ENABLED=true cùng BOOTSTRAP_ADMIN_PASSWORD (admin) và TEST_ACCOUNTS_PASSWORD (*@hrm.test) rồi khởi động app; hoặc dùng Google ID token):
--   baonvhe181955@fpt.edu.vn   SYSTEM_ADMIN          tài khoản, cấu hình, audit log, mẫu checklist
--   giamdoc@hrm.test    OPERATIONS_DIRECTOR   duyệt thưởng/phạt CRITICAL, mở lại kỳ công
--   quanly@hrm.test     STORE_MANAGER         lịch, duyệt giải trình/OT/thiết bị/checklist, xác nhận kỳ công
--   hr@hrm.test         EMPLOYEE + tập quyền HR (+ EVIDENCE_DOWNLOAD)   chốt kỳ công, duyệt điều chỉnh bước HR
--   nv.an@hrm.test      EMPLOYEE  thiết bị đã duyệt, đủ đào tạo  -> check-in/out thành công hôm nay
--   nv.binh@hrm.test    EMPLOYEE  thiết bị đang chờ duyệt        -> check-in báo DEVICE_NOT_ACTIVE; thử duyệt/từ chối thiết bị
--   nv.chi@hrm.test     EMPLOYEE  chưa đạt đào tạo bắt buộc      -> check-in báo SHIFT_NOT_ELIGIBLE
--   nv.dung@hrm.test    EMPLOYEE  chưa có thiết bị, hồ sơ thiếu  -> thử đăng ký thiết bị, nộp hồ sơ
--   nv.khoa@hrm.test    tài khoản LOCKED, nhân viên đã nghỉ      -> thử trạng thái tài khoản bị khóa
-- Vị trí cửa hàng: lat 21.0278, lon 105.8342, bán kính 30 m (dùng tọa độ này để check-in qua GPS).
-- Kỳ công: kỳ A (hôm nay-27..-14) sạch -> thử xác nhận + chốt; kỳ B (hôm nay-13..-1) còn đơn treo -> readiness báo vướng.
-- Hôm nay: An/Bình/Chi/Hà đều có ca CA_TEST cả ngày; Hà đã check-in sẵn để thử check-out.
-- =====================================================================================
GO

SET XACT_ABORT ON;
IF EXISTS (SELECT 1 FROM dbo.Store WHERE StoreCode = 'CF-HN01')
    PRINT N'Dữ liệu test đã tồn tại (CF-HN01) - bỏ qua.';
ELSE
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @D  DATE      = CAST(DATEADD(HOUR, 7, SYSUTCDATETIME()) AS DATE);  -- hôm nay theo giờ VN
        DECLARE @T0 DATETIME2 = DATEADD(HOUR, -7, CAST(@D AS DATETIME2));          -- 00:00 hôm nay (VN) quy ra UTC

        -- 1. Cửa hàng + tài khoản + vai trò + quyền
        DECLARE @uAdmin BIGINT = (SELECT UserId FROM dbo.AppUser WHERE Email = 'baonvhe181955@fpt.edu.vn');
        DECLARE @rAdmin INT = (SELECT RoleId FROM dbo.Role WHERE RoleCode = 'SYSTEM_ADMIN');
        DECLARE @rMgr INT = (SELECT RoleId FROM dbo.Role WHERE RoleCode = 'STORE_MANAGER');
        DECLARE @rEmp INT = (SELECT RoleId FROM dbo.Role WHERE RoleCode = 'EMPLOYEE');
        DECLARE @rDir INT = (SELECT RoleId FROM dbo.Role WHERE RoleCode = 'OPERATIONS_DIRECTOR');
        INSERT INTO dbo.Store (StoreCode, Name, AddressLine, Latitude, Longitude, AttendanceRadiusMeters, IsActive)
        VALUES
            ('CF-HN01', N'Cà phê Mộc – Cửa hàng Test', N'1 Tràng Tiền, Hoàn Kiếm, Hà Nội', 21.0278000, 105.8342000, 30, 1);

        DECLARE @sId INT = (SELECT StoreId FROM dbo.Store WHERE StoreCode = 'CF-HN01');
        INSERT INTO dbo.AppUser (Email, DisplayName, PhoneNumber, UserStatus)
        VALUES
            ('giamdoc@hrm.test', N'Nguyễn Văn Hùng', '0901000001', 'ACTIVE'),
            ('quanly@hrm.test', N'Trần Thị Mai', '0901000002', 'ACTIVE'),
            ('hr@hrm.test', N'Lê Thu Hà', '0901000003', 'ACTIVE'),
            ('nv.an@hrm.test', N'Phạm Minh An', '0901000004', 'ACTIVE'),
            ('nv.binh@hrm.test', N'Vũ Quốc Bình', '0901000005', 'ACTIVE'),
            ('nv.chi@hrm.test', N'Đỗ Khánh Chi', '0901000006', 'ACTIVE'),
            ('nv.dung@hrm.test', N'Hoàng Tiến Dũng', '0901000007', 'ACTIVE'),
            ('nv.khoa@hrm.test', N'Lý Đăng Khoa', '0901000008', 'LOCKED');

        DECLARE @uDir BIGINT = (SELECT UserId FROM dbo.AppUser WHERE Email = 'giamdoc@hrm.test');
        DECLARE @uMgr BIGINT = (SELECT UserId FROM dbo.AppUser WHERE Email = 'quanly@hrm.test');
        DECLARE @uHr BIGINT = (SELECT UserId FROM dbo.AppUser WHERE Email = 'hr@hrm.test');
        DECLARE @uAn BIGINT = (SELECT UserId FROM dbo.AppUser WHERE Email = 'nv.an@hrm.test');
        DECLARE @uBinh BIGINT = (SELECT UserId FROM dbo.AppUser WHERE Email = 'nv.binh@hrm.test');
        DECLARE @uChi BIGINT = (SELECT UserId FROM dbo.AppUser WHERE Email = 'nv.chi@hrm.test');
        DECLARE @uDung BIGINT = (SELECT UserId FROM dbo.AppUser WHERE Email = 'nv.dung@hrm.test');
        DECLARE @uKhoa BIGINT = (SELECT UserId FROM dbo.AppUser WHERE Email = 'nv.khoa@hrm.test');
        INSERT INTO dbo.UserRole (UserId, RoleId)
        VALUES
            (@uDir, @rDir),
            (@uMgr, @rMgr),
            (@uHr, @rEmp),
            (@uAn, @rEmp),
            (@uBinh, @rEmp),
            (@uChi, @rEmp),
            (@uDung, @rEmp),
            (@uKhoa, @rEmp);

        INSERT INTO dbo.UserPermission (UserId, PermissionId, GrantedBy)
        SELECT @uHr, p.PermissionId, @uAdmin
        FROM dbo.Permission p
        WHERE p.PermissionCode IN ('DOCUMENT_REVIEW', 'STAFF_REVIEW', 'EMPLOYEE_VIEW', 'EMPLOYEE_MANAGE', 'EMPLOYEE_PII_VIEW', 'ATTENDANCE_VIEW_ALL', 'ATTENDANCE_ADJUST_HR', 'PAYROLL_VIEW', 'PAYROLL_PERIOD_MANAGE', 'PAYROLL_FINALIZE', 'DEVICE_APPROVE', 'DASHBOARD_MANAGER', 'CHECKLIST_VIEW', 'TRAINING_MANAGE', 'VIOLATION_REVIEW', 'REWARD_VIEW', 'REWARD_PROPOSE', 'REWARD_APPROVE', 'EVIDENCE_VIEW', 'EVIDENCE_DOWNLOAD');


        -- 2. Hồ sơ nhân viên (key, mã, chức danh, loại HĐ, trạng thái làm việc, ngày vào làm trước hôm nay, hồ sơ giấy tờ)
        INSERT INTO dbo.Employee (UserId, EmployeeCode, StoreId, JobTitle, PositionId, EmploymentType, EmploymentStatus, DateOfBirth, HireDate, IdentityNumber, Address, EmergencyContact, ProfileStatus)
        VALUES
            (@uMgr, 'QL001', @sId, N'Quản lý cửa hàng', (SELECT PositionId FROM dbo.JobPosition WHERE PositionName = N'Quản lý cửa hàng'), 'FULL_TIME', 'ACTIVE', '1990-05-12', DATEADD(DAY, -900, @D), '000000000001', N'Hà Nội', N'Người thân – 0912000000', 'COMPLETE'),
            (@uHr, 'NV004', @sId, N'Thu ngân', (SELECT PositionId FROM dbo.JobPosition WHERE PositionName = N'Thu ngân'), 'FULL_TIME', 'ACTIVE', '1995-08-20', DATEADD(DAY, -600, @D), '000000000004', N'Hà Nội', N'Người thân – 0912000000', 'COMPLETE'),
            (@uAn, 'NV001', @sId, N'Pha chế', (SELECT PositionId FROM dbo.JobPosition WHERE PositionName = N'Pha chế'), 'FULL_TIME', 'ACTIVE', '1998-02-14', DATEADD(DAY, -400, @D), '000000000002', N'Hà Nội', N'Người thân – 0912000000', 'COMPLETE'),
            (@uBinh, 'NV002', @sId, N'Pha chế', (SELECT PositionId FROM dbo.JobPosition WHERE PositionName = N'Pha chế'), 'PART_TIME', 'ACTIVE', '2002-11-03', DATEADD(DAY, -250, @D), '000000000003', N'Hà Nội', N'Người thân – 0912000000', 'UNDER_REVIEW'),
            (@uChi, 'NV003', @sId, N'Phục vụ', (SELECT PositionId FROM dbo.JobPosition WHERE PositionName = N'Phục vụ'), 'FULL_TIME', 'ACTIVE', '2001-07-25', DATEADD(DAY, -120, @D), '000000000005', N'Hà Nội', N'Người thân – 0912000000', 'UNDER_REVIEW'),
            (@uDung, 'NV005', @sId, N'Đầu bếp', (SELECT PositionId FROM dbo.JobPosition WHERE PositionName = N'Đầu bếp'), 'PROBATION', 'ACTIVE', '1997-12-01', DATEADD(DAY, -20, @D), NULL, N'Hà Nội', N'Người thân – 0912000000', 'INCOMPLETE'),
            (@uKhoa, 'NV006', @sId, N'Phục vụ', (SELECT PositionId FROM dbo.JobPosition WHERE PositionName = N'Phục vụ'), 'TEMPORARY', 'RESIGNED', '2003-03-09', DATEADD(DAY, -300, @D), '000000000006', N'Hà Nội', N'Người thân – 0912000000', 'COMPLETE');

        DECLARE @eMgr BIGINT = (SELECT EmployeeId FROM dbo.Employee WHERE UserId = @uMgr);
        DECLARE @eHr BIGINT = (SELECT EmployeeId FROM dbo.Employee WHERE UserId = @uHr);
        DECLARE @eAn BIGINT = (SELECT EmployeeId FROM dbo.Employee WHERE UserId = @uAn);
        DECLARE @eBinh BIGINT = (SELECT EmployeeId FROM dbo.Employee WHERE UserId = @uBinh);
        DECLARE @eChi BIGINT = (SELECT EmployeeId FROM dbo.Employee WHERE UserId = @uChi);
        DECLARE @eDung BIGINT = (SELECT EmployeeId FROM dbo.Employee WHERE UserId = @uDung);
        DECLARE @eKhoa BIGINT = (SELECT EmployeeId FROM dbo.Employee WHERE UserId = @uKhoa);

        -- 3. Giấy tờ nhân viên (loại giấy tờ lấy từ danh mục có sẵn ở phần dữ liệu nền)
        DECLARE @dtCccd INT = (SELECT DocumentTypeId FROM dbo.DocumentType WHERE DocumentCode = 'CITIZEN_ID');
        DECLARE @dtResume INT = (SELECT DocumentTypeId FROM dbo.DocumentType WHERE DocumentCode = 'RESUME');
        DECLARE @dtCommit INT = (SELECT DocumentTypeId FROM dbo.DocumentType WHERE DocumentCode = 'COMMITMENT');
        DECLARE @dtFood INT = (SELECT DocumentTypeId FROM dbo.DocumentType WHERE DocumentCode = 'FOOD_SAFETY_CERT');
        INSERT INTO dbo.EmployeeDocument (EmployeeId, DocumentTypeId, FileName, StorageKey, ReviewStatus, ReviewedBy, ReviewedAt, ExpiresAt, UploadedAt, RejectionReason)
        VALUES
            (@eMgr, @dtCccd, 'cccd-mgr.jpg', 'private-documents/seed/mgr-cccd.jpg', 'APPROVED', @uHr, DATEADD(MINUTE, -28800, @T0), NULL, DATEADD(MINUTE, -36000, @T0), NULL),
            (@eMgr, @dtResume, 'so-yeu-ly-lich-mgr.jpg', 'private-documents/seed/mgr-so-yeu-ly-lich.jpg', 'APPROVED', @uHr, DATEADD(MINUTE, -28800, @T0), NULL, DATEADD(MINUTE, -36000, @T0), NULL),
            (@eMgr, @dtCommit, 'cam-ket-mgr.jpg', 'private-documents/seed/mgr-cam-ket.jpg', 'APPROVED', @uHr, DATEADD(MINUTE, -28800, @T0), NULL, DATEADD(MINUTE, -36000, @T0), NULL),
            (@eHr, @dtCccd, 'cccd-hr.jpg', 'private-documents/seed/hr-cccd.jpg', 'APPROVED', @uMgr, DATEADD(MINUTE, -28800, @T0), NULL, DATEADD(MINUTE, -36000, @T0), NULL),
            (@eHr, @dtResume, 'so-yeu-ly-lich-hr.jpg', 'private-documents/seed/hr-so-yeu-ly-lich.jpg', 'APPROVED', @uMgr, DATEADD(MINUTE, -28800, @T0), NULL, DATEADD(MINUTE, -36000, @T0), NULL),
            (@eHr, @dtCommit, 'cam-ket-hr.jpg', 'private-documents/seed/hr-cam-ket.jpg', 'APPROVED', @uMgr, DATEADD(MINUTE, -28800, @T0), NULL, DATEADD(MINUTE, -36000, @T0), NULL),
            (@eAn, @dtCccd, 'cccd-an.jpg', 'private-documents/seed/an-cccd.jpg', 'APPROVED', @uHr, DATEADD(MINUTE, -28800, @T0), NULL, DATEADD(MINUTE, -36000, @T0), NULL),
            (@eAn, @dtResume, 'so-yeu-ly-lich-an.jpg', 'private-documents/seed/an-so-yeu-ly-lich.jpg', 'APPROVED', @uHr, DATEADD(MINUTE, -28800, @T0), NULL, DATEADD(MINUTE, -36000, @T0), NULL),
            (@eAn, @dtCommit, 'cam-ket-an.jpg', 'private-documents/seed/an-cam-ket.jpg', 'APPROVED', @uHr, DATEADD(MINUTE, -28800, @T0), NULL, DATEADD(MINUTE, -36000, @T0), NULL),
            (@eBinh, @dtCccd, 'cccd-binh.jpg', 'private-documents/seed/binh-cccd.jpg', 'APPROVED', @uHr, DATEADD(MINUTE, -28800, @T0), NULL, DATEADD(MINUTE, -36000, @T0), NULL),
            (@eBinh, @dtResume, 'so-yeu-ly-lich-binh.jpg', 'private-documents/seed/binh-so-yeu-ly-lich.jpg', 'PENDING', NULL, NULL, NULL, DATEADD(MINUTE, -36000, @T0), NULL),
            (@eBinh, @dtCommit, 'cam-ket-binh.jpg', 'private-documents/seed/binh-cam-ket.jpg', 'PENDING', NULL, NULL, NULL, DATEADD(MINUTE, -36000, @T0), NULL),
            (@eChi, @dtCccd, 'cccd-chi.jpg', 'private-documents/seed/chi-cccd.jpg', 'PENDING', NULL, NULL, NULL, DATEADD(MINUTE, -36000, @T0), NULL),
            (@eChi, @dtResume, 'so-yeu-ly-lich-chi.jpg', 'private-documents/seed/chi-so-yeu-ly-lich.jpg', 'REJECTED', @uHr, DATEADD(MINUTE, -28800, @T0), NULL, DATEADD(MINUTE, -36000, @T0), N'Ảnh bị mờ, vui lòng chụp lại rõ nét'),
            (@eDung, @dtCccd, 'cccd-dung.jpg', 'private-documents/seed/dung-cccd.jpg', 'APPROVED', @uHr, DATEADD(MINUTE, -28800, @T0), NULL, DATEADD(MINUTE, -36000, @T0), NULL),
            (@eDung, @dtFood, 'an-toan-thuc-pham-dung.jpg', 'private-documents/seed/dung-an-toan-thuc-pham.jpg', 'EXPIRED', @uHr, DATEADD(MINUTE, -28800, @T0), DATEADD(DAY, -30, @D), DATEADD(MINUTE, -36000, @T0), N'Chứng chỉ đã hết hạn, cần nộp bản mới');


        -- 4. Thiết bị chấm công. Vân hạn là SHA-256 của chuỗi 'seed-device-<tên>' (gọi /attendance/devices/register với đúng chuỗi này để thử luồng 'cài lại app')
        INSERT INTO dbo.AttendanceDevice (EmployeeId, DeviceFingerprint, DeviceName, Platform, Status, RequestedAt, ApprovedBy, ApprovedAt, LockedAt, LockReason)
        VALUES
            (@eAn, LOWER(CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'seed-device-an'), 2)), N'Pixel 7 của An', 'ANDROID', 'ACTIVE', DATEADD(MINUTE, -432000, @T0), @uMgr, DATEADD(MINUTE, -430560, @T0), NULL, NULL),
            (@eAn, LOWER(CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'seed-device-an-old'), 2)), N'iPhone 8 cũ của An', 'IOS', 'LOCKED', DATEADD(MINUTE, -432000, @T0), @uMgr, DATEADD(MINUTE, -430560, @T0), DATEADD(MINUTE, -144000, @T0), N'Mất máy, đã thu hồi'),
            (@eBinh, LOWER(CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'seed-device-binh-old'), 2)), N'Máy cũ của Bình', 'ANDROID', 'LOCKED', DATEADD(MINUTE, -432000, @T0), @uMgr, DATEADD(MINUTE, -430560, @T0), DATEADD(MINUTE, -144000, @T0), N'Đã đổi máy mới'),
            (@eBinh, LOWER(CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'seed-device-binh'), 2)), N'Galaxy A54 của Bình', 'ANDROID', 'PENDING', DATEADD(MINUTE, -432000, @T0), NULL, NULL, NULL, NULL),
            (@eChi, LOWER(CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'seed-device-chi'), 2)), N'Redmi Note 12 của Chi', 'ANDROID', 'ACTIVE', DATEADD(MINUTE, -432000, @T0), @uMgr, DATEADD(MINUTE, -430560, @T0), NULL, NULL),
            (@eHr, LOWER(CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'seed-device-hr'), 2)), N'iPhone 13 của Hà', 'IOS', 'ACTIVE', DATEADD(MINUTE, -432000, @T0), @uMgr, DATEADD(MINUTE, -430560, @T0), NULL, NULL),
            (@eDung, LOWER(CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'seed-device-dung-old'), 2)), N'Máy cũ của Dũng', 'ANDROID', 'REJECTED', DATEADD(MINUTE, -432000, @T0), @uMgr, NULL, NULL, N'Thông tin thiết bị không khớp');

        DECLARE @dvAn BIGINT = (SELECT DeviceId FROM dbo.AttendanceDevice WHERE DeviceFingerprint = LOWER(CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'seed-device-an'), 2)));
        DECLARE @dvBinhOld BIGINT = (SELECT DeviceId FROM dbo.AttendanceDevice WHERE DeviceFingerprint = LOWER(CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'seed-device-binh-old'), 2)));
        DECLARE @dvChi BIGINT = (SELECT DeviceId FROM dbo.AttendanceDevice WHERE DeviceFingerprint = LOWER(CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'seed-device-chi'), 2)));
        DECLARE @dvHr BIGINT = (SELECT DeviceId FROM dbo.AttendanceDevice WHERE DeviceFingerprint = LOWER(CONVERT(VARCHAR(64), HASHBYTES('SHA2_256', 'seed-device-hr'), 2)));

        -- 5. Mẫu ca. CA_TEST kéo dài cả ngày để bạn thử check-in/check-out bất kỳ lúc nào
        INSERT INTO dbo.WorkShift (StoreId, ShiftCode, ShiftName, StartTime, EndTime, BreakMinutes, EarlyCheckInMinutes, GraceMinutes)
        VALUES
            (@sId, 'CA_SANG', N'Ca sáng', '07:00', '12:00', 0, 15, 5),
            (@sId, 'CA_CHIEU', N'Ca chiều', '12:00', '17:00', 0, 15, 5),
            (@sId, 'CA_TOI', N'Ca tối', '17:00', '22:00', 0, 15, 5),
            (@sId, 'CA_FULL', N'Ca full-time (nghỉ 30 phút)', '07:00', '15:30', 30, 15, 5),
            (@sId, 'CA_TEST', N'Ca TEST cả ngày (check-in được mọi lúc trong ngày)', '00:00', '23:59', 0, 15, 5);

        DECLARE @shSang INT = (SELECT WorkShiftId FROM dbo.WorkShift WHERE StoreId = @sId AND ShiftCode = 'CA_SANG');
        DECLARE @shChieu INT = (SELECT WorkShiftId FROM dbo.WorkShift WHERE StoreId = @sId AND ShiftCode = 'CA_CHIEU');
        DECLARE @shToi INT = (SELECT WorkShiftId FROM dbo.WorkShift WHERE StoreId = @sId AND ShiftCode = 'CA_TOI');
        DECLARE @shFull INT = (SELECT WorkShiftId FROM dbo.WorkShift WHERE StoreId = @sId AND ShiftCode = 'CA_FULL');
        DECLARE @shTest INT = (SELECT WorkShiftId FROM dbo.WorkShift WHERE StoreId = @sId AND ShiftCode = 'CA_TEST');

        -- 6. Lịch làm: quá khứ (kỳ A + kỳ B), HÔM NAY và 6 ngày tới (CA_TEST), 1 ca đã hủy
        INSERT INTO dbo.ShiftAssignment (EmployeeId, WorkShiftId, WorkDate, PlannedStartAt, PlannedEndAt, ScheduleStatus, CreatedBy, CreatedAt, UpdatedAt, Note)
        VALUES
            (@eAn, @shSang, DATEADD(DAY, -27, @D), DATEADD(MINUTE, -38460, @T0), DATEADD(MINUTE, -38160, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -41340, @T0), DATEADD(MINUTE, -41340, @T0), NULL),
            (@eAn, @shSang, DATEADD(DAY, -26, @D), DATEADD(MINUTE, -37020, @T0), DATEADD(MINUTE, -36720, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -39900, @T0), DATEADD(MINUTE, -39900, @T0), NULL),
            (@eAn, @shSang, DATEADD(DAY, -25, @D), DATEADD(MINUTE, -35580, @T0), DATEADD(MINUTE, -35280, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -38460, @T0), DATEADD(MINUTE, -38460, @T0), NULL),
            (@eAn, @shSang, DATEADD(DAY, -24, @D), DATEADD(MINUTE, -34140, @T0), DATEADD(MINUTE, -33840, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -37020, @T0), DATEADD(MINUTE, -37020, @T0), NULL),
            (@eAn, @shSang, DATEADD(DAY, -23, @D), DATEADD(MINUTE, -32700, @T0), DATEADD(MINUTE, -32400, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -35580, @T0), DATEADD(MINUTE, -35580, @T0), NULL),
            (@eAn, @shSang, DATEADD(DAY, -22, @D), DATEADD(MINUTE, -31260, @T0), DATEADD(MINUTE, -30960, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -34140, @T0), DATEADD(MINUTE, -34140, @T0), NULL),
            (@eAn, @shSang, DATEADD(DAY, -20, @D), DATEADD(MINUTE, -28380, @T0), DATEADD(MINUTE, -28080, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -31260, @T0), DATEADD(MINUTE, -31260, @T0), NULL),
            (@eAn, @shSang, DATEADD(DAY, -19, @D), DATEADD(MINUTE, -26940, @T0), DATEADD(MINUTE, -26640, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -29820, @T0), DATEADD(MINUTE, -29820, @T0), NULL),
            (@eAn, @shSang, DATEADD(DAY, -18, @D), DATEADD(MINUTE, -25500, @T0), DATEADD(MINUTE, -25200, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -28380, @T0), DATEADD(MINUTE, -28380, @T0), NULL),
            (@eAn, @shSang, DATEADD(DAY, -17, @D), DATEADD(MINUTE, -24060, @T0), DATEADD(MINUTE, -23760, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -26940, @T0), DATEADD(MINUTE, -26940, @T0), NULL),
            (@eAn, @shSang, DATEADD(DAY, -16, @D), DATEADD(MINUTE, -22620, @T0), DATEADD(MINUTE, -22320, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -25500, @T0), DATEADD(MINUTE, -25500, @T0), NULL),
            (@eAn, @shSang, DATEADD(DAY, -15, @D), DATEADD(MINUTE, -21180, @T0), DATEADD(MINUTE, -20880, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -24060, @T0), DATEADD(MINUTE, -24060, @T0), NULL),
            (@eBinh, @shChieu, DATEADD(DAY, -26, @D), DATEADD(MINUTE, -36720, @T0), DATEADD(MINUTE, -36420, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -39600, @T0), DATEADD(MINUTE, -39600, @T0), NULL),
            (@eBinh, @shChieu, DATEADD(DAY, -24, @D), DATEADD(MINUTE, -33840, @T0), DATEADD(MINUTE, -33540, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -36720, @T0), DATEADD(MINUTE, -36720, @T0), NULL),
            (@eBinh, @shChieu, DATEADD(DAY, -22, @D), DATEADD(MINUTE, -30960, @T0), DATEADD(MINUTE, -30660, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -33840, @T0), DATEADD(MINUTE, -33840, @T0), NULL),
            (@eBinh, @shChieu, DATEADD(DAY, -20, @D), DATEADD(MINUTE, -28080, @T0), DATEADD(MINUTE, -27780, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -30960, @T0), DATEADD(MINUTE, -30960, @T0), NULL),
            (@eBinh, @shChieu, DATEADD(DAY, -18, @D), DATEADD(MINUTE, -25200, @T0), DATEADD(MINUTE, -24900, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -28080, @T0), DATEADD(MINUTE, -28080, @T0), NULL),
            (@eBinh, @shChieu, DATEADD(DAY, -16, @D), DATEADD(MINUTE, -22320, @T0), DATEADD(MINUTE, -22020, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -25200, @T0), DATEADD(MINUTE, -25200, @T0), NULL),
            (@eHr, @shFull, DATEADD(DAY, -27, @D), DATEADD(MINUTE, -38460, @T0), DATEADD(MINUTE, -37950, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -41340, @T0), DATEADD(MINUTE, -41340, @T0), NULL),
            (@eHr, @shFull, DATEADD(DAY, -25, @D), DATEADD(MINUTE, -35580, @T0), DATEADD(MINUTE, -35070, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -38460, @T0), DATEADD(MINUTE, -38460, @T0), NULL),
            (@eHr, @shFull, DATEADD(DAY, -23, @D), DATEADD(MINUTE, -32700, @T0), DATEADD(MINUTE, -32190, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -35580, @T0), DATEADD(MINUTE, -35580, @T0), NULL),
            (@eHr, @shFull, DATEADD(DAY, -21, @D), DATEADD(MINUTE, -29820, @T0), DATEADD(MINUTE, -29310, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -32700, @T0), DATEADD(MINUTE, -32700, @T0), NULL),
            (@eHr, @shFull, DATEADD(DAY, -19, @D), DATEADD(MINUTE, -26940, @T0), DATEADD(MINUTE, -26430, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -29820, @T0), DATEADD(MINUTE, -29820, @T0), NULL),
            (@eHr, @shFull, DATEADD(DAY, -17, @D), DATEADD(MINUTE, -24060, @T0), DATEADD(MINUTE, -23550, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -26940, @T0), DATEADD(MINUTE, -26940, @T0), NULL),
            (@eHr, @shFull, DATEADD(DAY, -15, @D), DATEADD(MINUTE, -21180, @T0), DATEADD(MINUTE, -20670, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -24060, @T0), DATEADD(MINUTE, -24060, @T0), NULL),
            (@eAn, @shSang, DATEADD(DAY, -13, @D), DATEADD(MINUTE, -18300, @T0), DATEADD(MINUTE, -18000, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -21180, @T0), DATEADD(MINUTE, -21180, @T0), NULL),
            (@eAn, @shSang, DATEADD(DAY, -12, @D), DATEADD(MINUTE, -16860, @T0), DATEADD(MINUTE, -16560, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -19740, @T0), DATEADD(MINUTE, -19740, @T0), NULL),
            (@eAn, @shSang, DATEADD(DAY, -11, @D), DATEADD(MINUTE, -15420, @T0), DATEADD(MINUTE, -15120, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -18300, @T0), DATEADD(MINUTE, -18300, @T0), NULL),
            (@eAn, @shSang, DATEADD(DAY, -10, @D), DATEADD(MINUTE, -13980, @T0), DATEADD(MINUTE, -13680, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -16860, @T0), DATEADD(MINUTE, -16860, @T0), NULL),
            (@eAn, @shSang, DATEADD(DAY, -9, @D), DATEADD(MINUTE, -12540, @T0), DATEADD(MINUTE, -12240, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -15420, @T0), DATEADD(MINUTE, -15420, @T0), NULL),
            (@eAn, @shSang, DATEADD(DAY, -8, @D), DATEADD(MINUTE, -11100, @T0), DATEADD(MINUTE, -10800, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -13980, @T0), DATEADD(MINUTE, -13980, @T0), NULL),
            (@eAn, @shSang, DATEADD(DAY, -7, @D), DATEADD(MINUTE, -9660, @T0), DATEADD(MINUTE, -9360, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -12540, @T0), DATEADD(MINUTE, -12540, @T0), NULL),
            (@eAn, @shSang, DATEADD(DAY, -6, @D), DATEADD(MINUTE, -8220, @T0), DATEADD(MINUTE, -7920, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -11100, @T0), DATEADD(MINUTE, -11100, @T0), NULL),
            (@eAn, @shSang, DATEADD(DAY, -5, @D), DATEADD(MINUTE, -6780, @T0), DATEADD(MINUTE, -6480, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -9660, @T0), DATEADD(MINUTE, -9660, @T0), NULL),
            (@eAn, @shSang, DATEADD(DAY, -4, @D), DATEADD(MINUTE, -5340, @T0), DATEADD(MINUTE, -5040, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -8220, @T0), DATEADD(MINUTE, -8220, @T0), NULL),
            (@eAn, @shSang, DATEADD(DAY, -3, @D), DATEADD(MINUTE, -3900, @T0), DATEADD(MINUTE, -3600, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -6780, @T0), DATEADD(MINUTE, -6780, @T0), NULL),
            (@eAn, @shSang, DATEADD(DAY, -2, @D), DATEADD(MINUTE, -2460, @T0), DATEADD(MINUTE, -2160, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -5340, @T0), DATEADD(MINUTE, -5340, @T0), NULL),
            (@eAn, @shSang, DATEADD(DAY, -1, @D), DATEADD(MINUTE, -1020, @T0), DATEADD(MINUTE, -720, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -3900, @T0), DATEADD(MINUTE, -3900, @T0), NULL),
            (@eBinh, @shChieu, DATEADD(DAY, -12, @D), DATEADD(MINUTE, -16560, @T0), DATEADD(MINUTE, -16260, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -19440, @T0), DATEADD(MINUTE, -19440, @T0), NULL),
            (@eBinh, @shChieu, DATEADD(DAY, -10, @D), DATEADD(MINUTE, -13680, @T0), DATEADD(MINUTE, -13380, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -16560, @T0), DATEADD(MINUTE, -16560, @T0), NULL),
            (@eBinh, @shChieu, DATEADD(DAY, -8, @D), DATEADD(MINUTE, -10800, @T0), DATEADD(MINUTE, -10500, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -13680, @T0), DATEADD(MINUTE, -13680, @T0), NULL),
            (@eBinh, @shChieu, DATEADD(DAY, -5, @D), DATEADD(MINUTE, -6480, @T0), DATEADD(MINUTE, -6180, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -9360, @T0), DATEADD(MINUTE, -9360, @T0), NULL),
            (@eBinh, @shChieu, DATEADD(DAY, -3, @D), DATEADD(MINUTE, -3600, @T0), DATEADD(MINUTE, -3300, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -6480, @T0), DATEADD(MINUTE, -6480, @T0), NULL),
            (@eBinh, @shChieu, DATEADD(DAY, -1, @D), DATEADD(MINUTE, -720, @T0), DATEADD(MINUTE, -420, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -3600, @T0), DATEADD(MINUTE, -3600, @T0), NULL),
            (@eHr, @shFull, DATEADD(DAY, -13, @D), DATEADD(MINUTE, -18300, @T0), DATEADD(MINUTE, -17790, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -21180, @T0), DATEADD(MINUTE, -21180, @T0), NULL),
            (@eHr, @shFull, DATEADD(DAY, -11, @D), DATEADD(MINUTE, -15420, @T0), DATEADD(MINUTE, -14910, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -18300, @T0), DATEADD(MINUTE, -18300, @T0), NULL),
            (@eHr, @shFull, DATEADD(DAY, -9, @D), DATEADD(MINUTE, -12540, @T0), DATEADD(MINUTE, -12030, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -15420, @T0), DATEADD(MINUTE, -15420, @T0), NULL),
            (@eHr, @shFull, DATEADD(DAY, -8, @D), DATEADD(MINUTE, -11100, @T0), DATEADD(MINUTE, -10590, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -13980, @T0), DATEADD(MINUTE, -13980, @T0), NULL),
            (@eHr, @shFull, DATEADD(DAY, -6, @D), DATEADD(MINUTE, -8220, @T0), DATEADD(MINUTE, -7710, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -11100, @T0), DATEADD(MINUTE, -11100, @T0), NULL),
            (@eHr, @shFull, DATEADD(DAY, -4, @D), DATEADD(MINUTE, -5340, @T0), DATEADD(MINUTE, -4830, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -8220, @T0), DATEADD(MINUTE, -8220, @T0), NULL),
            (@eHr, @shFull, DATEADD(DAY, -2, @D), DATEADD(MINUTE, -2460, @T0), DATEADD(MINUTE, -1950, @T0), 'PUBLISHED', @uMgr, DATEADD(MINUTE, -5340, @T0), DATEADD(MINUTE, -5340, @T0), NULL),
            (@eAn, @shTest, DATEADD(DAY, 0, @D), DATEADD(MINUTE, 0, @T0), DATEADD(MINUTE, 1439, @T0), 'PUBLISHED', @uMgr, SYSUTCDATETIME(), SYSUTCDATETIME(), N'Ca test: check-in được cả ngày'),
            (@eAn, @shTest, DATEADD(DAY, 1, @D), DATEADD(MINUTE, 1440, @T0), DATEADD(MINUTE, 2879, @T0), 'PUBLISHED', @uMgr, SYSUTCDATETIME(), SYSUTCDATETIME(), N'Ca test: check-in được cả ngày'),
            (@eAn, @shTest, DATEADD(DAY, 2, @D), DATEADD(MINUTE, 2880, @T0), DATEADD(MINUTE, 4319, @T0), 'PUBLISHED', @uMgr, SYSUTCDATETIME(), SYSUTCDATETIME(), N'Ca test: check-in được cả ngày'),
            (@eAn, @shTest, DATEADD(DAY, 3, @D), DATEADD(MINUTE, 4320, @T0), DATEADD(MINUTE, 5759, @T0), 'PUBLISHED', @uMgr, SYSUTCDATETIME(), SYSUTCDATETIME(), N'Ca test: check-in được cả ngày'),
            (@eAn, @shTest, DATEADD(DAY, 4, @D), DATEADD(MINUTE, 5760, @T0), DATEADD(MINUTE, 7199, @T0), 'PUBLISHED', @uMgr, SYSUTCDATETIME(), SYSUTCDATETIME(), N'Ca test: check-in được cả ngày'),
            (@eAn, @shTest, DATEADD(DAY, 5, @D), DATEADD(MINUTE, 7200, @T0), DATEADD(MINUTE, 8639, @T0), 'PUBLISHED', @uMgr, SYSUTCDATETIME(), SYSUTCDATETIME(), N'Ca test: check-in được cả ngày'),
            (@eAn, @shTest, DATEADD(DAY, 6, @D), DATEADD(MINUTE, 8640, @T0), DATEADD(MINUTE, 10079, @T0), 'PUBLISHED', @uMgr, SYSUTCDATETIME(), SYSUTCDATETIME(), N'Ca test: check-in được cả ngày'),
            (@eBinh, @shTest, DATEADD(DAY, 0, @D), DATEADD(MINUTE, 0, @T0), DATEADD(MINUTE, 1439, @T0), 'PUBLISHED', @uMgr, SYSUTCDATETIME(), SYSUTCDATETIME(), N'Ca test: check-in được cả ngày'),
            (@eChi, @shTest, DATEADD(DAY, 0, @D), DATEADD(MINUTE, 0, @T0), DATEADD(MINUTE, 1439, @T0), 'PUBLISHED', @uMgr, SYSUTCDATETIME(), SYSUTCDATETIME(), N'Ca test: check-in được cả ngày'),
            (@eHr, @shTest, DATEADD(DAY, 0, @D), DATEADD(MINUTE, 0, @T0), DATEADD(MINUTE, 1439, @T0), 'PUBLISHED', @uMgr, SYSUTCDATETIME(), SYSUTCDATETIME(), N'Ca test: check-in được cả ngày'),
            (@eAn, @shSang, DATEADD(DAY, 8, @D), DATEADD(MINUTE, 11940, @T0), DATEADD(MINUTE, 12240, @T0), 'CANCELLED', @uMgr, SYSUTCDATETIME(), SYSUTCDATETIME(), N'Ca đã hủy (thử lỗi check-in ca không còn hiệu lực)');


        -- 7. Chấm công (kết quả giờ vào/ra đã khớp công thức trong AttendanceMetricsService)
        INSERT INTO dbo.Attendance (ShiftAssignmentId, EmployeeId, CheckInAt, CheckOutAt, CheckInLatitude, CheckInLongitude, CheckInAccuracyM, CheckOutLatitude, CheckOutLongitude, CheckOutAccuracyM, CheckInMethod, CheckOutMethod, CheckInFaceStatus, CheckOutFaceStatus, AttendanceStatus, LateMinutes, EarlyLeaveMinutes, WorkedMinutes, ApprovedOTMinutes, ManagerReviewedBy, ManagerReviewedAt, PayrollStatus, Note, CreatedAt, UpdatedAt, CheckInDeviceId, CheckOutDeviceId, GraceApplied)
        VALUES
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eAn AND WorkDate = DATEADD(DAY, -27, @D)), @eAn, DATEADD(MINUTE, -38463, @T0), DATEADD(MINUTE, -38158, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'PRESENT', 0, 0, 300, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -38463, @T0), DATEADD(MINUTE, -38158, @T0), @dvAn, @dvAn, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eAn AND WorkDate = DATEADD(DAY, -26, @D)), @eAn, DATEADD(MINUTE, -37025, @T0), DATEADD(MINUTE, -36718, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'PRESENT', 0, 0, 300, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -37025, @T0), DATEADD(MINUTE, -36718, @T0), @dvAn, @dvAn, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eAn AND WorkDate = DATEADD(DAY, -25, @D)), @eAn, DATEADD(MINUTE, -35577, @T0), DATEADD(MINUTE, -35279, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'PRESENT', 0, 0, 297, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -35577, @T0), DATEADD(MINUTE, -35279, @T0), @dvAn, @dvAn, 1),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eAn AND WorkDate = DATEADD(DAY, -24, @D)), @eAn, DATEADD(MINUTE, -34125, @T0), DATEADD(MINUTE, -33839, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'LATE', 10, 0, 285, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -34125, @T0), DATEADD(MINUTE, -33839, @T0), @dvAn, @dvAn, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eAn AND WorkDate = DATEADD(DAY, -23, @D)), @eAn, DATEADD(MINUTE, -32705, @T0), DATEADD(MINUTE, -32398, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'PRESENT', 0, 0, 300, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -32705, @T0), DATEADD(MINUTE, -32398, @T0), @dvAn, @dvAn, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eAn AND WorkDate = DATEADD(DAY, -22, @D)), @eAn, DATEADD(MINUTE, -31264, @T0), DATEADD(MINUTE, -30915, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'PRESENT', 0, 0, 300, 45, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -31264, @T0), DATEADD(MINUTE, -30915, @T0), @dvAn, @dvAn, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eAn AND WorkDate = DATEADD(DAY, -20, @D)), @eAn, DATEADD(MINUTE, -28385, @T0), DATEADD(MINUTE, -28078, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'PRESENT', 0, 0, 300, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -28385, @T0), DATEADD(MINUTE, -28078, @T0), @dvAn, @dvAn, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eAn AND WorkDate = DATEADD(DAY, -19, @D)), @eAn, DATEADD(MINUTE, -26943, @T0), DATEADD(MINUTE, -26660, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'EARLY_LEAVE', 0, 20, 280, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -26943, @T0), DATEADD(MINUTE, -26660, @T0), @dvAn, @dvAn, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eAn AND WorkDate = DATEADD(DAY, -18, @D)), @eAn, DATEADD(MINUTE, -25500, @T0), DATEADD(MINUTE, -25200, @T0), NULL, NULL, NULL, NULL, NULL, NULL, 'MANUAL_APPROVAL', 'MANUAL_APPROVAL', 'NOT_RUN', 'NOT_RUN', 'APPROVED_EXCEPTION', 0, 0, 300, 0, @uMgr, DATEADD(MINUTE, -25080, @T0), 'OPEN', N'Chấm công thủ công được Quản lý duyệt (sự cố thiết bị)', DATEADD(MINUTE, -25500, @T0), DATEADD(MINUTE, -25200, @T0), NULL, NULL, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eAn AND WorkDate = DATEADD(DAY, -17, @D)), @eAn, DATEADD(MINUTE, -24065, @T0), DATEADD(MINUTE, -23758, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'PRESENT', 0, 0, 300, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -24065, @T0), DATEADD(MINUTE, -23758, @T0), @dvAn, @dvAn, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eAn AND WorkDate = DATEADD(DAY, -15, @D)), @eAn, DATEADD(MINUTE, -21185, @T0), DATEADD(MINUTE, -20878, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'PRESENT', 0, 0, 300, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -21185, @T0), DATEADD(MINUTE, -20878, @T0), @dvAn, @dvAn, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eBinh AND WorkDate = DATEADD(DAY, -26, @D)), @eBinh, DATEADD(MINUTE, -36725, @T0), DATEADD(MINUTE, -36418, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'PRESENT', 0, 0, 300, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -36725, @T0), DATEADD(MINUTE, -36418, @T0), @dvBinhOld, @dvBinhOld, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eBinh AND WorkDate = DATEADD(DAY, -24, @D)), @eBinh, DATEADD(MINUTE, -33845, @T0), DATEADD(MINUTE, -33538, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'PRESENT', 0, 0, 300, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -33845, @T0), DATEADD(MINUTE, -33538, @T0), @dvBinhOld, @dvBinhOld, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eBinh AND WorkDate = DATEADD(DAY, -22, @D)), @eBinh, DATEADD(MINUTE, -30945, @T0), DATEADD(MINUTE, -30659, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'LATE', 10, 0, 285, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -30945, @T0), DATEADD(MINUTE, -30659, @T0), @dvBinhOld, @dvBinhOld, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eBinh AND WorkDate = DATEADD(DAY, -20, @D)), @eBinh, DATEADD(MINUTE, -28085, @T0), DATEADD(MINUTE, -27778, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'PRESENT', 0, 0, 300, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -28085, @T0), DATEADD(MINUTE, -27778, @T0), @dvBinhOld, @dvBinhOld, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eBinh AND WorkDate = DATEADD(DAY, -18, @D)), @eBinh, DATEADD(MINUTE, -25205, @T0), DATEADD(MINUTE, -24898, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'PRESENT', 0, 0, 300, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -25205, @T0), DATEADD(MINUTE, -24898, @T0), @dvBinhOld, @dvBinhOld, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eBinh AND WorkDate = DATEADD(DAY, -16, @D)), @eBinh, DATEADD(MINUTE, -22324, @T0), DATEADD(MINUTE, -21975, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'PRESENT', 0, 0, 300, 45, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -22324, @T0), DATEADD(MINUTE, -21975, @T0), @dvBinhOld, @dvBinhOld, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eHr AND WorkDate = DATEADD(DAY, -27, @D)), @eHr, DATEADD(MINUTE, -38465, @T0), DATEADD(MINUTE, -37948, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'PRESENT', 0, 0, 480, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -38465, @T0), DATEADD(MINUTE, -37948, @T0), @dvHr, @dvHr, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eHr AND WorkDate = DATEADD(DAY, -25, @D)), @eHr, DATEADD(MINUTE, -35585, @T0), DATEADD(MINUTE, -35068, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'PRESENT', 0, 0, 480, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -35585, @T0), DATEADD(MINUTE, -35068, @T0), @dvHr, @dvHr, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eHr AND WorkDate = DATEADD(DAY, -23, @D)), @eHr, DATEADD(MINUTE, -32703, @T0), DATEADD(MINUTE, -32210, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'EARLY_LEAVE', 0, 20, 460, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -32703, @T0), DATEADD(MINUTE, -32210, @T0), @dvHr, @dvHr, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eHr AND WorkDate = DATEADD(DAY, -21, @D)), @eHr, DATEADD(MINUTE, -29825, @T0), DATEADD(MINUTE, -29308, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'PRESENT', 0, 0, 480, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -29825, @T0), DATEADD(MINUTE, -29308, @T0), @dvHr, @dvHr, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eHr AND WorkDate = DATEADD(DAY, -19, @D)), @eHr, DATEADD(MINUTE, -26945, @T0), DATEADD(MINUTE, -26428, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'PRESENT', 0, 0, 480, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -26945, @T0), DATEADD(MINUTE, -26428, @T0), @dvHr, @dvHr, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eHr AND WorkDate = DATEADD(DAY, -17, @D)), @eHr, DATEADD(MINUTE, -24065, @T0), DATEADD(MINUTE, -23548, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'PRESENT', 0, 0, 480, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -24065, @T0), DATEADD(MINUTE, -23548, @T0), @dvHr, @dvHr, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eHr AND WorkDate = DATEADD(DAY, -15, @D)), @eHr, DATEADD(MINUTE, -21185, @T0), DATEADD(MINUTE, -20668, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'PRESENT', 0, 0, 480, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -21185, @T0), DATEADD(MINUTE, -20668, @T0), @dvHr, @dvHr, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eAn AND WorkDate = DATEADD(DAY, -13, @D)), @eAn, DATEADD(MINUTE, -18305, @T0), DATEADD(MINUTE, -17998, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'PRESENT', 0, 0, 300, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -18305, @T0), DATEADD(MINUTE, -17998, @T0), @dvAn, @dvAn, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eAn AND WorkDate = DATEADD(DAY, -12, @D)), @eAn, DATEADD(MINUTE, -16865, @T0), DATEADD(MINUTE, -16558, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'PRESENT', 0, 0, 300, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -16865, @T0), DATEADD(MINUTE, -16558, @T0), @dvAn, @dvAn, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eAn AND WorkDate = DATEADD(DAY, -11, @D)), @eAn, DATEADD(MINUTE, -15405, @T0), DATEADD(MINUTE, -15119, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'LATE', 10, 0, 285, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -15405, @T0), DATEADD(MINUTE, -15119, @T0), @dvAn, @dvAn, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eAn AND WorkDate = DATEADD(DAY, -10, @D)), @eAn, DATEADD(MINUTE, -13985, @T0), DATEADD(MINUTE, -13650, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'PRESENT', 0, 0, 300, 0, NULL, NULL, 'OPEN', N'Check-out muộn, đã gửi yêu cầu điều chỉnh', DATEADD(MINUTE, -13985, @T0), DATEADD(MINUTE, -13650, @T0), @dvAn, @dvAn, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eAn AND WorkDate = DATEADD(DAY, -9, @D)), @eAn, DATEADD(MINUTE, -12545, @T0), DATEADD(MINUTE, -12238, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'PRESENT', 0, 0, 300, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -12545, @T0), DATEADD(MINUTE, -12238, @T0), @dvAn, @dvAn, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eAn AND WorkDate = DATEADD(DAY, -8, @D)), @eAn, DATEADD(MINUTE, -11075, @T0), DATEADD(MINUTE, -10800, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'LATE', 20, 0, 275, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -11075, @T0), DATEADD(MINUTE, -10800, @T0), @dvAn, @dvAn, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eAn AND WorkDate = DATEADD(DAY, -7, @D)), @eAn, DATEADD(MINUTE, -9664, @T0), DATEADD(MINUTE, -9315, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'PRESENT', 0, 0, 300, 45, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -9664, @T0), DATEADD(MINUTE, -9315, @T0), @dvAn, @dvAn, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eAn AND WorkDate = DATEADD(DAY, -6, @D)), @eAn, DATEADD(MINUTE, -8225, @T0), DATEADD(MINUTE, -7918, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'PRESENT', 0, 0, 300, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -8225, @T0), DATEADD(MINUTE, -7918, @T0), @dvAn, @dvAn, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eAn AND WorkDate = DATEADD(DAY, -5, @D)), @eAn, DATEADD(MINUTE, -6785, @T0), DATEADD(MINUTE, -6478, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'PRESENT', 0, 0, 300, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -6785, @T0), DATEADD(MINUTE, -6478, @T0), @dvAn, @dvAn, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eAn AND WorkDate = DATEADD(DAY, -4, @D)), @eAn, DATEADD(MINUTE, -5343, @T0), DATEADD(MINUTE, -5060, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'EARLY_LEAVE', 0, 20, 280, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -5343, @T0), DATEADD(MINUTE, -5060, @T0), @dvAn, @dvAn, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eAn AND WorkDate = DATEADD(DAY, -3, @D)), @eAn, DATEADD(MINUTE, -3902, @T0), NULL, 21.0278500, 105.8342400, 12.50, NULL, NULL, NULL, 'GPS', NULL, 'NOT_RUN', NULL, 'IN_PROGRESS', 0, 0, NULL, 0, NULL, NULL, 'OPEN', N'Chưa check-out (quên chấm công ra)', DATEADD(MINUTE, -3902, @T0), DATEADD(MINUTE, -3902, @T0), @dvAn, NULL, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eAn AND WorkDate = DATEADD(DAY, -2, @D)), @eAn, DATEADD(MINUTE, -2465, @T0), DATEADD(MINUTE, -2158, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'PRESENT', 0, 0, 300, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -2465, @T0), DATEADD(MINUTE, -2158, @T0), @dvAn, @dvAn, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eAn AND WorkDate = DATEADD(DAY, -1, @D)), @eAn, DATEADD(MINUTE, -1025, @T0), DATEADD(MINUTE, -718, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'PRESENT', 0, 0, 300, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -1025, @T0), DATEADD(MINUTE, -718, @T0), @dvAn, @dvAn, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eBinh AND WorkDate = DATEADD(DAY, -12, @D)), @eBinh, DATEADD(MINUTE, -16565, @T0), DATEADD(MINUTE, -16258, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'PRESENT', 0, 0, 300, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -16565, @T0), DATEADD(MINUTE, -16258, @T0), @dvBinhOld, @dvBinhOld, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eBinh AND WorkDate = DATEADD(DAY, -10, @D)), @eBinh, DATEADD(MINUTE, -13685, @T0), DATEADD(MINUTE, -13378, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'PRESENT', 0, 0, 300, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -13685, @T0), DATEADD(MINUTE, -13378, @T0), @dvBinhOld, @dvBinhOld, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eBinh AND WorkDate = DATEADD(DAY, -8, @D)), @eBinh, DATEADD(MINUTE, -10805, @T0), DATEADD(MINUTE, -10498, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'PRESENT', 0, 0, 300, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -10805, @T0), DATEADD(MINUTE, -10498, @T0), @dvBinhOld, @dvBinhOld, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eBinh AND WorkDate = DATEADD(DAY, -5, @D)), @eBinh, DATEADD(MINUTE, -6484, @T0), DATEADD(MINUTE, -6140, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'PRESENT', 0, 0, 300, 0, NULL, NULL, 'OPEN', N'Làm thêm giờ, chờ Quản lý duyệt OT', DATEADD(MINUTE, -6484, @T0), DATEADD(MINUTE, -6140, @T0), @dvBinhOld, @dvBinhOld, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eBinh AND WorkDate = DATEADD(DAY, -3, @D)), @eBinh, DATEADD(MINUTE, -3605, @T0), DATEADD(MINUTE, -3298, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'PRESENT', 0, 0, 300, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -3605, @T0), DATEADD(MINUTE, -3298, @T0), @dvBinhOld, @dvBinhOld, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eBinh AND WorkDate = DATEADD(DAY, -1, @D)), @eBinh, DATEADD(MINUTE, -725, @T0), DATEADD(MINUTE, -418, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'PRESENT', 0, 0, 300, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -725, @T0), DATEADD(MINUTE, -418, @T0), @dvBinhOld, @dvBinhOld, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eHr AND WorkDate = DATEADD(DAY, -13, @D)), @eHr, DATEADD(MINUTE, -18305, @T0), DATEADD(MINUTE, -17788, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'PRESENT', 0, 0, 480, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -18305, @T0), DATEADD(MINUTE, -17788, @T0), @dvHr, @dvHr, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eHr AND WorkDate = DATEADD(DAY, -11, @D)), @eHr, DATEADD(MINUTE, -15425, @T0), DATEADD(MINUTE, -14908, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'PRESENT', 0, 0, 480, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -15425, @T0), DATEADD(MINUTE, -14908, @T0), @dvHr, @dvHr, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eHr AND WorkDate = DATEADD(DAY, -9, @D)), @eHr, DATEADD(MINUTE, -12545, @T0), DATEADD(MINUTE, -12028, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'PRESENT', 0, 0, 480, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -12545, @T0), DATEADD(MINUTE, -12028, @T0), @dvHr, @dvHr, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eHr AND WorkDate = DATEADD(DAY, -6, @D)), @eHr, DATEADD(MINUTE, -8225, @T0), DATEADD(MINUTE, -7708, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'PRESENT', 0, 0, 480, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -8225, @T0), DATEADD(MINUTE, -7708, @T0), @dvHr, @dvHr, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eHr AND WorkDate = DATEADD(DAY, -4, @D)), @eHr, DATEADD(MINUTE, -5345, @T0), DATEADD(MINUTE, -4828, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'PRESENT', 0, 0, 480, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -5345, @T0), DATEADD(MINUTE, -4828, @T0), @dvHr, @dvHr, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eHr AND WorkDate = DATEADD(DAY, -2, @D)), @eHr, DATEADD(MINUTE, -2465, @T0), DATEADD(MINUTE, -1948, @T0), 21.0278500, 105.8342400, 12.50, 21.0278500, 105.8342400, 11.80, 'GPS', 'GPS', 'NOT_RUN', 'NOT_RUN', 'PRESENT', 0, 0, 480, 0, NULL, NULL, 'OPEN', NULL, DATEADD(MINUTE, -2465, @T0), DATEADD(MINUTE, -1948, @T0), @dvHr, @dvHr, 0),
            ((SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eHr AND WorkDate = DATEADD(DAY, 0, @D)), @eHr, DATEADD(MINUTE, 0, @T0), NULL, 21.0278300, 105.8342200, 9.60, NULL, NULL, NULL, 'GPS', NULL, 'NOT_RUN', NULL, 'IN_PROGRESS', 0, 0, NULL, 0, NULL, NULL, 'OPEN', N'Đã check-in sẵn để thử check-out', DATEADD(MINUTE, 0, @T0), DATEADD(MINUTE, 0, @T0), @dvHr, NULL, 0);


        -- 8. Kết quả xác minh chấm công (SRS 7.4): GPS, thiết bị và ảnh demo sinh từ bản ghi chấm công
        INSERT INTO dbo.AttendanceVerification (AttendanceId, VerificationType, EventType, Latitude, Longitude, AccuracyMeters, DistanceMeters, VerificationStatus, VerifiedAt)
        SELECT a.AttendanceId, 'GPS', 'CHECK_IN', a.CheckInLatitude, a.CheckInLongitude, a.CheckInAccuracyM, 12.00, 'PASSED', a.CheckInAt
        FROM dbo.Attendance a WHERE a.CheckInLatitude IS NOT NULL;

        INSERT INTO dbo.AttendanceVerification (AttendanceId, VerificationType, EventType, DeviceId, VerificationStatus, VerifiedAt)
        SELECT a.AttendanceId, 'DEVICE', 'CHECK_IN', a.CheckInDeviceId, 'PASSED', a.CheckInAt
        FROM dbo.Attendance a WHERE a.CheckInDeviceId IS NOT NULL;

        INSERT INTO dbo.AttendanceVerification (AttendanceId, VerificationType, EventType, EvidenceStorageKey, VerificationStatus, VerifiedAt, RetainUntil)
        SELECT a.AttendanceId, 'PHOTO', 'CHECK_IN', CONCAT('attendance-evidence/demo/', a.AttendanceId, '/checkin.jpg'), 'PASSED', a.CheckInAt,
               DATEADD(MONTH, 12, CAST(a.CheckInAt AS DATE))
        FROM dbo.Attendance a WHERE a.CheckInAt IS NOT NULL;

        -- 10. Đơn giải trình chấm công: chờ duyệt (làm vướng kỳ B), đã duyệt, bị từ chối
        INSERT INTO dbo.AttendanceExceptionRequest (EmployeeId, ShiftAssignmentId, AttendanceId, RequestType, RequestedCheckInAt, RequestedCheckOutAt, Reason, RequestStatus, SubmittedAt, ReviewedBy, ReviewedAt, ReviewNote)
        VALUES
            (@eHr, (SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eHr AND WorkDate = DATEADD(DAY, -8, @D)), NULL, 'MISSED_CHECK_IN', DATEADD(MINUTE, -11100, @T0), DATEADD(MINUTE, -10590, @T0), N'Quên chấm công cả ca, có mặt làm việc đủ giờ', 'PENDING', DATEADD(MINUTE, -10530, @T0), NULL, NULL, NULL),
            (@eAn, (SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eAn AND WorkDate = DATEADD(DAY, -18, @D)), (SELECT a.AttendanceId FROM dbo.Attendance a JOIN dbo.ShiftAssignment s ON s.ShiftAssignmentId = a.ShiftAssignmentId WHERE s.EmployeeId = @eAn AND s.WorkDate = DATEADD(DAY, -18, @D)), 'DEVICE_ISSUE', DATEADD(MINUTE, -25500, @T0), DATEADD(MINUTE, -25200, @T0), N'Điện thoại hỏng, không mở được app chấm công', 'APPROVED', DATEADD(MINUTE, -25140, @T0), @uMgr, DATEADD(MINUTE, -24480, @T0), N'Đã xác nhận với ca trực'),
            (@eBinh, (SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eBinh AND WorkDate = DATEADD(DAY, -22, @D)), (SELECT a.AttendanceId FROM dbo.Attendance a JOIN dbo.ShiftAssignment s ON s.ShiftAssignmentId = a.ShiftAssignmentId WHERE s.EmployeeId = @eBinh AND s.WorkDate = DATEADD(DAY, -22, @D)), 'DEVICE_ISSUE', DATEADD(MINUTE, -30945, @T0), DATEADD(MINUTE, -30659, @T0), N'Điện thoại treo nên vào ca muộn', 'REJECTED', DATEADD(MINUTE, -30600, @T0), @uMgr, DATEADD(MINUTE, -29940, @T0), N'Không có minh chứng sự cố thiết bị');


        -- 11. Điều chỉnh công (2 bước: Quản lý -> HR): đã duyệt, chờ Quản lý, chờ HR, bị từ chối. Giá trị là Instant UTC dạng ISO
        INSERT INTO dbo.AttendanceAdjustmentRequest (AttendanceId, RequestedBy, FieldName, OldValue, NewValue, Reason, ManagerStatus, ManagerReviewedBy, ManagerReviewedAt, HrStatus, HrReviewedBy, HrReviewedAt, CreatedAt)
        VALUES
            ((SELECT a.AttendanceId FROM dbo.Attendance a JOIN dbo.ShiftAssignment s ON s.ShiftAssignmentId = a.ShiftAssignmentId WHERE s.EmployeeId = @eAn AND s.WorkDate = DATEADD(DAY, -27, @D)), @uAn, 'CHECK_IN', CONVERT(VARCHAR(19), DATEADD(MINUTE, -38420, @T0), 126) + 'Z', CONVERT(VARCHAR(19), DATEADD(MINUTE, -38463, @T0), 126) + 'Z', N'FORGOT_CHECKIN: Quên bấm check-in, bấm muộn khi đã vào quầy', 'APPROVED', @uMgr, DATEADD(MINUTE, -37460, @T0), 'APPROVED', @uHr, DATEADD(MINUTE, -37260, @T0), DATEADD(MINUTE, -38130, @T0)),
            ((SELECT a.AttendanceId FROM dbo.Attendance a JOIN dbo.ShiftAssignment s ON s.ShiftAssignmentId = a.ShiftAssignmentId WHERE s.EmployeeId = @eAn AND s.WorkDate = DATEADD(DAY, -10, @D)), @uAn, 'CHECK_OUT', CONVERT(VARCHAR(19), DATEADD(MINUTE, -13650, @T0), 126) + 'Z', CONVERT(VARCHAR(19), DATEADD(MINUTE, -13678, @T0), 126) + 'Z', N'WRONG_TIME: Bấm check-out muộn so với giờ thực tế rời quầy', 'PENDING', NULL, NULL, 'PENDING', NULL, NULL, DATEADD(MINUTE, -13650, @T0)),
            ((SELECT a.AttendanceId FROM dbo.Attendance a JOIN dbo.ShiftAssignment s ON s.ShiftAssignmentId = a.ShiftAssignmentId WHERE s.EmployeeId = @eAn AND s.WorkDate = DATEADD(DAY, -8, @D)), @uAn, 'CHECK_IN', CONVERT(VARCHAR(19), DATEADD(MINUTE, -11075, @T0), 126) + 'Z', CONVERT(VARCHAR(19), DATEADD(MINUTE, -11101, @T0), 126) + 'Z', N'GPS_ERROR: GPS lỗi nên chấm công muộn dù đã có mặt', 'APPROVED', @uMgr, DATEADD(MINUTE, -10100, @T0), 'PENDING', NULL, NULL, DATEADD(MINUTE, -10770, @T0)),
            ((SELECT a.AttendanceId FROM dbo.Attendance a JOIN dbo.ShiftAssignment s ON s.ShiftAssignmentId = a.ShiftAssignmentId WHERE s.EmployeeId = @eBinh AND s.WorkDate = DATEADD(DAY, -18, @D)), @uBinh, 'CHECK_OUT', CONVERT(VARCHAR(19), DATEADD(MINUTE, -24898, @T0), 126) + 'Z', CONVERT(VARCHAR(19), DATEADD(MINUTE, -24880, @T0), 126) + 'Z', N'OTHER: Đề nghị tính thêm thời gian dọn quầy', 'REJECTED', @uMgr, DATEADD(MINUTE, -24200, @T0), 'PENDING', NULL, NULL, DATEADD(MINUTE, -24870, @T0));


        -- 12. Checklist: mẫu + mục
        INSERT INTO dbo.ChecklistTemplate (StoreId, ChecklistCode, ChecklistName, ChecklistType, IsManagerApprovalRequired)
        VALUES
            (@sId, 'OPEN_STORE', N'Mở cửa hàng', 'OPENING', 1),
            (@sId, 'CLOSE_STORE', N'Đóng cửa hàng', 'CLOSING', 1),
            (@sId, 'HANDOVER_SHIFT', N'Bàn giao ca', 'HANDOVER', 0),
            (@sId, 'INVENTORY_DAILY', N'Kiểm kho hằng ngày', 'INVENTORY', 0);

        DECLARE @tOpen INT = (SELECT ChecklistTemplateId FROM dbo.ChecklistTemplate WHERE StoreId = @sId AND ChecklistCode = 'OPEN_STORE');
        DECLARE @tClose INT = (SELECT ChecklistTemplateId FROM dbo.ChecklistTemplate WHERE StoreId = @sId AND ChecklistCode = 'CLOSE_STORE');
        DECLARE @tHand INT = (SELECT ChecklistTemplateId FROM dbo.ChecklistTemplate WHERE StoreId = @sId AND ChecklistCode = 'HANDOVER_SHIFT');
        DECLARE @tInv INT = (SELECT ChecklistTemplateId FROM dbo.ChecklistTemplate WHERE StoreId = @sId AND ChecklistCode = 'INVENTORY_DAILY');
        INSERT INTO dbo.ChecklistTemplateItem (ChecklistTemplateId, ItemName, Instructions, IsMandatory, RequiresEvidence, SortOrder)
        VALUES
            (@tOpen, N'Bật máy pha cà phê và kiểm tra áp suất', N'Chờ máy đạt áp suất rồi chụp đồng hồ', 1, 1, 1),
            (@tOpen, N'Vệ sinh quầy bar và bàn ghế', NULL, 1, 0, 2),
            (@tOpen, N'Kiểm tra nguyên liệu, ly cốc, đá', N'Ghi chú mục nào sắp hết', 1, 0, 3),
            (@tOpen, N'Chụp ảnh khu vực quầy bar sau khi chuẩn bị', N'Ảnh toàn cảnh quầy', 1, 1, 4),
            (@tClose, N'Vệ sinh máy pha và máy xay', NULL, 1, 0, 1),
            (@tClose, N'Kiểm đếm và niêm phong két tiền', N'Chụp ảnh túi niêm phong', 1, 1, 2),
            (@tClose, N'Tắt thiết bị điện, khóa cửa', NULL, 1, 0, 3),
            (@tClose, N'Ghi chú sự cố trong ngày (nếu có)', NULL, 0, 0, 4),
            (@tHand, N'Bàn giao tồn kho nguyên liệu', NULL, 1, 0, 1),
            (@tHand, N'Bàn giao tiền lẻ và hóa đơn', NULL, 1, 0, 2),
            (@tHand, N'Ghi chú việc cần theo dõi cho ca sau', NULL, 0, 0, 3),
            (@tInv, N'Đếm sữa và cà phê hạt', N'Chụp ảnh kệ kho', 1, 1, 1),
            (@tInv, N'Kiểm tra hạn sử dụng', NULL, 1, 0, 2),
            (@tInv, N'Đề xuất nhập hàng', NULL, 0, 0, 3);


        -- 13. Lần thực hiện checklist: PENDING, IN_PROGRESS, SUBMITTED, APPROVED, REJECTED; OVERDUE/WAIVED là trạng thái nghiệp vụ hợp lệ khác.
        -- Mỗi mục = một dòng ChecklistTaskItem; minh chứng = ChecklistEvidence; lịch sử duyệt = ChecklistReview
        INSERT INTO dbo.ChecklistTask (ChecklistTemplateId, ShiftAssignmentId, EmployeeId, DueAt, StartedAt, SubmittedAt, RunStatus, ManagerStatus)
        VALUES (@tOpen, NULL, @eAn, DATEADD(MINUTE, 2879, @T0), NULL, NULL, 'PENDING', 'NOT_REQUIRED');
        DECLARE @run1 BIGINT = SCOPE_IDENTITY();
        INSERT INTO dbo.ChecklistTaskItem (ChecklistTaskId, ChecklistTemplateItemId, IsCompleted, CompletedAt, CompletedBy, Note)
        VALUES
            (@run1, (SELECT ChecklistTemplateItemId FROM dbo.ChecklistTemplateItem WHERE ChecklistTemplateId = @tOpen AND SortOrder = 1), 0, NULL, NULL, NULL),
            (@run1, (SELECT ChecklistTemplateItemId FROM dbo.ChecklistTemplateItem WHERE ChecklistTemplateId = @tOpen AND SortOrder = 2), 0, NULL, NULL, NULL),
            (@run1, (SELECT ChecklistTemplateItemId FROM dbo.ChecklistTemplateItem WHERE ChecklistTemplateId = @tOpen AND SortOrder = 3), 0, NULL, NULL, NULL),
            (@run1, (SELECT ChecklistTemplateItemId FROM dbo.ChecklistTemplateItem WHERE ChecklistTemplateId = @tOpen AND SortOrder = 4), 0, NULL, NULL, NULL);
        INSERT INTO dbo.ChecklistTask (ChecklistTemplateId, ShiftAssignmentId, EmployeeId, DueAt, StartedAt, SubmittedAt, RunStatus, ManagerStatus)
        VALUES (@tHand, NULL, @eBinh, DATEADD(MINUTE, 2879, @T0), DATEADD(MINUTE, 10, @T0), NULL, 'IN_PROGRESS', 'NOT_REQUIRED');
        DECLARE @run2 BIGINT = SCOPE_IDENTITY();
        INSERT INTO dbo.ChecklistTaskItem (ChecklistTaskId, ChecklistTemplateItemId, IsCompleted, CompletedAt, CompletedBy, Note)
        VALUES
            (@run2, (SELECT ChecklistTemplateItemId FROM dbo.ChecklistTemplateItem WHERE ChecklistTemplateId = @tHand AND SortOrder = 1), 1, DATEADD(MINUTE, 15, @T0), @uBinh, NULL),
            (@run2, (SELECT ChecklistTemplateItemId FROM dbo.ChecklistTemplateItem WHERE ChecklistTemplateId = @tHand AND SortOrder = 2), 0, NULL, NULL, NULL),
            (@run2, (SELECT ChecklistTemplateItemId FROM dbo.ChecklistTemplateItem WHERE ChecklistTemplateId = @tHand AND SortOrder = 3), 0, NULL, NULL, NULL);
        INSERT INTO dbo.ChecklistTask (ChecklistTemplateId, ShiftAssignmentId, EmployeeId, DueAt, StartedAt, SubmittedAt, RunStatus, ManagerStatus)
        VALUES (@tOpen, (SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eAn AND WorkDate = DATEADD(DAY, -1, @D)), @eAn, DATEADD(MINUTE, -990, @T0), DATEADD(MINUTE, -1015, @T0), DATEADD(MINUTE, -970, @T0), 'SUBMITTED', 'PENDING');
        DECLARE @run3 BIGINT = SCOPE_IDENTITY();
        INSERT INTO dbo.ChecklistTaskItem (ChecklistTaskId, ChecklistTemplateItemId, IsCompleted, CompletedAt, CompletedBy, Note)
        VALUES
            (@run3, (SELECT ChecklistTemplateItemId FROM dbo.ChecklistTemplateItem WHERE ChecklistTemplateId = @tOpen AND SortOrder = 1), 1, DATEADD(MINUTE, -980, @T0), @uAn, NULL),
            (@run3, (SELECT ChecklistTemplateItemId FROM dbo.ChecklistTemplateItem WHERE ChecklistTemplateId = @tOpen AND SortOrder = 2), 1, DATEADD(MINUTE, -980, @T0), @uAn, NULL),
            (@run3, (SELECT ChecklistTemplateItemId FROM dbo.ChecklistTemplateItem WHERE ChecklistTemplateId = @tOpen AND SortOrder = 3), 1, DATEADD(MINUTE, -980, @T0), @uAn, NULL),
            (@run3, (SELECT ChecklistTemplateItemId FROM dbo.ChecklistTemplateItem WHERE ChecklistTemplateId = @tOpen AND SortOrder = 4), 1, DATEADD(MINUTE, -980, @T0), @uAn, NULL);
        INSERT INTO dbo.ChecklistTask (ChecklistTemplateId, ShiftAssignmentId, EmployeeId, DueAt, StartedAt, SubmittedAt, RunStatus, ManagerStatus)
        VALUES (@tInv, NULL, @eAn, DATEADD(MINUTE, -1441, @T0), DATEADD(MINUTE, -1920, @T0), DATEADD(MINUTE, -1880, @T0), 'APPROVED', 'NOT_REQUIRED');
        DECLARE @run4 BIGINT = SCOPE_IDENTITY();
        INSERT INTO dbo.ChecklistTaskItem (ChecklistTaskId, ChecklistTemplateItemId, IsCompleted, CompletedAt, CompletedBy, Note)
        VALUES
            (@run4, (SELECT ChecklistTemplateItemId FROM dbo.ChecklistTemplateItem WHERE ChecklistTemplateId = @tInv AND SortOrder = 1), 1, DATEADD(MINUTE, -1890, @T0), @uAn, NULL),
            (@run4, (SELECT ChecklistTemplateItemId FROM dbo.ChecklistTemplateItem WHERE ChecklistTemplateId = @tInv AND SortOrder = 2), 1, DATEADD(MINUTE, -1890, @T0), @uAn, NULL),
            (@run4, (SELECT ChecklistTemplateItemId FROM dbo.ChecklistTemplateItem WHERE ChecklistTemplateId = @tInv AND SortOrder = 3), 1, DATEADD(MINUTE, -1890, @T0), @uAn, NULL);
        INSERT INTO dbo.ChecklistTask (ChecklistTemplateId, ShiftAssignmentId, EmployeeId, DueAt, StartedAt, SubmittedAt, RunStatus, ManagerStatus)
        VALUES (@tOpen, (SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eHr AND WorkDate = DATEADD(DAY, -4, @D)), @eHr, DATEADD(MINUTE, -5310, @T0), DATEADD(MINUTE, -5335, @T0), DATEADD(MINUTE, -5280, @T0), 'REJECTED', 'REJECTED');
        DECLARE @run5 BIGINT = SCOPE_IDENTITY();
        INSERT INTO dbo.ChecklistTaskItem (ChecklistTaskId, ChecklistTemplateItemId, IsCompleted, CompletedAt, CompletedBy, Note)
        VALUES
            (@run5, (SELECT ChecklistTemplateItemId FROM dbo.ChecklistTemplateItem WHERE ChecklistTemplateId = @tOpen AND SortOrder = 1), 1, DATEADD(MINUTE, -5290, @T0), @uHr, NULL),
            (@run5, (SELECT ChecklistTemplateItemId FROM dbo.ChecklistTemplateItem WHERE ChecklistTemplateId = @tOpen AND SortOrder = 2), 1, DATEADD(MINUTE, -5290, @T0), @uHr, NULL),
            (@run5, (SELECT ChecklistTemplateItemId FROM dbo.ChecklistTemplateItem WHERE ChecklistTemplateId = @tOpen AND SortOrder = 3), 1, DATEADD(MINUTE, -5290, @T0), @uHr, NULL),
            (@run5, (SELECT ChecklistTemplateItemId FROM dbo.ChecklistTemplateItem WHERE ChecklistTemplateId = @tOpen AND SortOrder = 4), 0, NULL, NULL, NULL);
        INSERT INTO dbo.ChecklistTask (ChecklistTemplateId, ShiftAssignmentId, EmployeeId, DueAt, StartedAt, SubmittedAt, RunStatus, ManagerStatus)
        VALUES (@tOpen, (SELECT ShiftAssignmentId FROM dbo.ShiftAssignment WHERE EmployeeId = @eAn AND WorkDate = DATEADD(DAY, -6, @D)), @eAn, DATEADD(MINUTE, -8190, @T0), DATEADD(MINUTE, -8215, @T0), DATEADD(MINUTE, -8170, @T0), 'APPROVED', 'APPROVED');
        DECLARE @run6 BIGINT = SCOPE_IDENTITY();
        INSERT INTO dbo.ChecklistTaskItem (ChecklistTaskId, ChecklistTemplateItemId, IsCompleted, CompletedAt, CompletedBy, Note)
        VALUES
            (@run6, (SELECT ChecklistTemplateItemId FROM dbo.ChecklistTemplateItem WHERE ChecklistTemplateId = @tOpen AND SortOrder = 1), 1, DATEADD(MINUTE, -8180, @T0), @uAn, NULL),
            (@run6, (SELECT ChecklistTemplateItemId FROM dbo.ChecklistTemplateItem WHERE ChecklistTemplateId = @tOpen AND SortOrder = 2), 1, DATEADD(MINUTE, -8180, @T0), @uAn, NULL),
            (@run6, (SELECT ChecklistTemplateItemId FROM dbo.ChecklistTemplateItem WHERE ChecklistTemplateId = @tOpen AND SortOrder = 3), 1, DATEADD(MINUTE, -8180, @T0), @uAn, NULL),
            (@run6, (SELECT ChecklistTemplateItemId FROM dbo.ChecklistTemplateItem WHERE ChecklistTemplateId = @tOpen AND SortOrder = 4), 1, DATEADD(MINUTE, -8180, @T0), @uAn, NULL);

        -- Lịch sử duyệt (ChecklistReview)
        INSERT INTO dbo.ChecklistReview (ChecklistTaskId, ReviewerId, Decision, Reason, ReviewedAt)
        VALUES
            (@run5, @uMgr, 'REJECTED', N'Thiếu ảnh khu vực quầy bar, vui lòng làm lại mục 4', DATEADD(MINUTE, -5160, @T0)),
            (@run6, @uMgr, 'APPROVED', N'Đạt', DATEADD(MINUTE, -8080, @T0));

        -- Minh chứng (ChecklistEvidence): mỗi ảnh một dòng
        INSERT INTO dbo.ChecklistEvidence (ChecklistTaskId, ChecklistTaskItemId, StorageKey, UploadedBy, UploadedAt)
        VALUES
            (@run3, (SELECT ChecklistTaskItemId FROM dbo.ChecklistTaskItem WHERE ChecklistTaskId = @run3 AND ChecklistTemplateItemId = (SELECT ChecklistTemplateItemId FROM dbo.ChecklistTemplateItem WHERE ChecklistTemplateId = @tOpen AND SortOrder = 1)), 'checklist-evidence/seed/tOpen-1.jpg', @uAn, DATEADD(MINUTE, -980, @T0)),
            (@run3, (SELECT ChecklistTaskItemId FROM dbo.ChecklistTaskItem WHERE ChecklistTaskId = @run3 AND ChecklistTemplateItemId = (SELECT ChecklistTemplateItemId FROM dbo.ChecklistTemplateItem WHERE ChecklistTemplateId = @tOpen AND SortOrder = 4)), 'checklist-evidence/seed/tOpen-4.jpg', @uAn, DATEADD(MINUTE, -980, @T0)),
            (@run4, (SELECT ChecklistTaskItemId FROM dbo.ChecklistTaskItem WHERE ChecklistTaskId = @run4 AND ChecklistTemplateItemId = (SELECT ChecklistTemplateItemId FROM dbo.ChecklistTemplateItem WHERE ChecklistTemplateId = @tInv AND SortOrder = 1)), 'checklist-evidence/seed/tInv-1.jpg', @uAn, DATEADD(MINUTE, -1890, @T0)),
            (@run5, (SELECT ChecklistTaskItemId FROM dbo.ChecklistTaskItem WHERE ChecklistTaskId = @run5 AND ChecklistTemplateItemId = (SELECT ChecklistTemplateItemId FROM dbo.ChecklistTemplateItem WHERE ChecklistTemplateId = @tOpen AND SortOrder = 1)), 'checklist-evidence/seed/tOpen-1.jpg', @uHr, DATEADD(MINUTE, -5290, @T0)),
            (@run6, (SELECT ChecklistTaskItemId FROM dbo.ChecklistTaskItem WHERE ChecklistTaskId = @run6 AND ChecklistTemplateItemId = (SELECT ChecklistTemplateItemId FROM dbo.ChecklistTemplateItem WHERE ChecklistTemplateId = @tOpen AND SortOrder = 1)), 'checklist-evidence/seed/tOpen-1.jpg', @uAn, DATEADD(MINUTE, -8180, @T0)),
            (@run6, (SELECT ChecklistTaskItemId FROM dbo.ChecklistTaskItem WHERE ChecklistTaskId = @run6 AND ChecklistTemplateItemId = (SELECT ChecklistTemplateItemId FROM dbo.ChecklistTemplateItem WHERE ChecklistTemplateId = @tOpen AND SortOrder = 4)), 'checklist-evidence/seed/tOpen-4.jpg', @uAn, DATEADD(MINUTE, -8180, @T0));

        -- 14. Đào tạo: trạng thái học được theo dõi nhưng không chặn nhận ca
        INSERT INTO dbo.TrainingCourse (CourseCode, CourseName, Description, PassingScore)
        VALUES
            ('FOOD_SAFETY_101', N'An toàn vệ sinh thực phẩm cơ bản', N'Bắt buộc với mọi nhân viên', 80),
            ('HOUSE_RULES', N'Nội quy và quy trình cửa hàng', N'Bắt buộc với mọi nhân viên', 80),
            ('BARISTA_BASIC', N'Kỹ thuật pha chế cơ bản', N'Dành cho nhân viên pha chế', 70),
            ('COFFEE_TASTING', N'Thử nếm và phân biệt hương vị cà phê', N'Khóa tự chọn', 60);

        INSERT INTO dbo.TrainingQuestion
            (CourseId, QuestionText, OptionA, OptionB, OptionC, OptionD, CorrectOption, SortOrder)
        SELECT c.CourseId, q.QuestionText, q.OptionA, q.OptionB, q.OptionC, q.OptionD, q.CorrectOption, q.SortOrder
        FROM (VALUES
            ('FOOD_SAFETY_101', N'Nhân viên cần làm gì trước khi chế biến thực phẩm?', N'Rửa tay đúng quy trình', N'Đeo găng thay cho rửa tay', N'Chỉ lau tay bằng khăn', N'Không cần vệ sinh nếu tay sạch', 'A', 1),
            ('FOOD_SAFETY_101', N'Thực phẩm sống nên được bảo quản thế nào?', N'Đặt cạnh thực phẩm chín', N'Đậy kín và tách riêng thực phẩm chín', N'Để ở nhiệt độ phòng cả ngày', N'Đặt trực tiếp trên sàn', 'B', 2),
            ('FOOD_SAFETY_101', N'Khi phát hiện nguyên liệu hết hạn, cần làm gì?', N'Dùng trước để tránh lãng phí', N'Bỏ ngày hết hạn', N'Cách ly và báo người phụ trách', N'Pha trộn với nguyên liệu mới', 'C', 3),
            ('FOOD_SAFETY_101', N'Dụng cụ chế biến cần được vệ sinh khi nào?', N'Cuối tháng', N'Chỉ khi nhìn thấy vết bẩn', N'Sau mỗi lần sử dụng và theo quy trình', N'Mỗi tuần một lần', 'C', 4),
            ('FOOD_SAFETY_101', N'Khi có dấu hiệu nhiễm chéo, nhân viên nên làm gì?', N'Tiếp tục chế biến nhanh hơn', N'Dừng thao tác, vệ sinh và thay dụng cụ', N'Chỉ lau mặt bàn', N'Chuyển nguyên liệu sang khay khác', 'B', 5),
            ('HOUSE_RULES', N'Khi bắt đầu ca làm, nhân viên cần làm gì trước?', N'Kiểm tra lịch ca và nhận bàn giao', N'Tự đổi vị trí làm việc', N'Rời cửa hàng mua đồ', N'Bắt đầu trước khi chấm công', 'A', 1),
            ('HOUSE_RULES', N'Khi cần đổi ca, nhân viên nên làm gì?', N'Tự thỏa thuận rồi nghỉ', N'Báo và chờ quản lý xác nhận', N'Nhắn đồng nghiệp sau ca', N'Chỉ cập nhật lịch cá nhân', 'B', 2),
            ('HOUSE_RULES', N'Thông tin khách hàng cần được xử lý thế nào?', N'Chia sẻ lên mạng xã hội', N'Chỉ chia sẻ trong nhóm bạn', N'Giữ bí mật và dùng đúng mục đích công việc', N'Lưu vào điện thoại cá nhân', 'C', 3),
            ('HOUSE_RULES', N'Khi phát hiện sự cố tại cửa hàng, cần làm gì?', N'Bỏ qua nếu chưa ảnh hưởng khách', N'Báo quản lý và làm theo quy trình', N'Chờ hết ca mới báo', N'Tự ý đăng thông tin công khai', 'B', 4),
            ('HOUSE_RULES', N'Nhân viên cần làm gì khi kết thúc ca?', N'Bàn giao công việc và tài sản theo quy trình', N'Rời đi ngay khi hết giờ', N'Để người ca sau tự kiểm tra', N'Tắt thiết bị mà không ghi nhận', 'A', 5),
            ('BARISTA_BASIC', N'Tác dụng chính của việc cân cà phê là gì?', N'Kiểm soát tỷ lệ pha ổn định', N'Làm hạt cà phê ngọt hơn', N'Tăng nhiệt độ nước', N'Thay thế việc xay cà phê', 'A', 1),
            ('BARISTA_BASIC', N'Khi espresso chảy quá nhanh, nên kiểm tra gì trước?', N'Độ mịn và lượng cà phê xay', N'Màu của ly', N'Vị trí bàn khách', N'Kích thước khăn lau', 'A', 2),
            ('BARISTA_BASIC', N'Sữa dùng để đánh nóng nên được xử lý thế nào?', N'Tái sử dụng nhiều lần', N'Làm nóng theo nhiệt độ và quy trình quy định', N'Đun sôi hoàn toàn', N'Để ngoài quầy cả ngày', 'B', 3),
            ('BARISTA_BASIC', N'Sau khi chiết xuất espresso, cần làm gì với tay pha?', N'Để nguyên đến cuối ngày', N'Rửa sạch bã và lau khô', N'Ngâm trong sữa', N'Đặt lên khăn ướt', 'B', 4),
            ('BARISTA_BASIC', N'Để công thức đồ uống nhất quán, cần làm gì?', N'Ước lượng nguyên liệu bằng mắt', N'Tuân thủ định lượng và thứ tự pha', N'Thay đổi công thức mỗi lần', N'Bỏ qua thời gian chiết xuất', 'B', 5),
            ('COFFEE_TASTING', N'Hương vị chua sáng trong cà phê thường được mô tả là gì?', N'Độ acid cảm nhận được', N'Độ mặn', N'Độ cay', N'Độ lạnh', 'A', 1),
            ('COFFEE_TASTING', N'Body của cà phê mô tả điều gì?', N'Cảm giác độ dày khi uống', N'Màu của bao bì', N'Kích cỡ hạt', N'Nhiệt độ phòng', 'A', 2),
            ('COFFEE_TASTING', N'Khi thử nếm nhiều mẫu, cách so sánh phù hợp là gì?', N'Ghi nhận từng mẫu theo cùng tiêu chí', N'Chỉ chọn mẫu đậm nhất', N'Thêm đường vào mọi mẫu', N'Đổi tiêu chí sau mỗi mẫu', 'A', 3),
            ('COFFEE_TASTING', N'Mùi hương cà phê nên được đánh giá vào lúc nào?', N'Trước và trong khi nếm', N'Chỉ sau khi uống hết', N'Sau khi thêm nhiều đá', N'Không cần ngửi', 'A', 4),
            ('COFFEE_TASTING', N'Hậu vị là cảm nhận nào?', N'Cảm giác còn lại sau khi nuốt', N'Mùi của hạt chưa rang', N'Tiếng máy xay', N'Màu nước trong ly', 'A', 5)
        ) q(CourseCode, QuestionText, OptionA, OptionB, OptionC, OptionD, CorrectOption, SortOrder)
        JOIN dbo.TrainingCourse c ON c.CourseCode = q.CourseCode
        WHERE NOT EXISTS (
            SELECT 1 FROM dbo.TrainingQuestion existing WHERE existing.CourseId = c.CourseId
        );

        -- Khóa được theo dõi cho mọi chức vụ; tiến độ không chặn nhận ca
        INSERT INTO dbo.PositionTrainingRequirement (PositionId, CourseId, IsMandatory, BlocksShiftAssignment, EffectiveFrom)
        SELECT p.PositionId, c.CourseId, 1, 0, '2000-01-01'
        FROM dbo.JobPosition p CROSS JOIN dbo.TrainingCourse c
        WHERE c.CourseCode IN ('FOOD_SAFETY_101', 'HOUSE_RULES')
          AND NOT EXISTS (SELECT 1 FROM dbo.PositionTrainingRequirement r
                          WHERE r.PositionId = p.PositionId AND r.CourseId = c.CourseId
                            AND r.EffectiveFrom = '2000-01-01');

        DECLARE @cFood INT = (SELECT CourseId FROM dbo.TrainingCourse WHERE CourseCode = 'FOOD_SAFETY_101');
        DECLARE @cRules INT = (SELECT CourseId FROM dbo.TrainingCourse WHERE CourseCode = 'HOUSE_RULES');
        DECLARE @cBarista INT = (SELECT CourseId FROM dbo.TrainingCourse WHERE CourseCode = 'BARISTA_BASIC');
        DECLARE @cTasting INT = (SELECT CourseId FROM dbo.TrainingCourse WHERE CourseCode = 'COFFEE_TASTING');
        INSERT INTO dbo.EmployeeTraining (EmployeeId, CourseId, AssignedAt, DueAt, CompletedAt, TestScore, TrainingStatus)
        VALUES
            (@eMgr, @cFood, DATEADD(MINUTE, -86400, @T0), NULL, DATEADD(MINUTE, -72000, @T0), 95, 'PASSED'),
            (@eMgr, @cRules, DATEADD(MINUTE, -86400, @T0), NULL, DATEADD(MINUTE, -72000, @T0), 90, 'PASSED'),
            (@eHr, @cFood, DATEADD(MINUTE, -86400, @T0), NULL, DATEADD(MINUTE, -72000, @T0), 88, 'PASSED'),
            (@eHr, @cRules, DATEADD(MINUTE, -86400, @T0), NULL, DATEADD(MINUTE, -72000, @T0), 85, 'PASSED'),
            (@eAn, @cFood, DATEADD(MINUTE, -86400, @T0), NULL, DATEADD(MINUTE, -72000, @T0), 92, 'PASSED'),
            (@eAn, @cRules, DATEADD(MINUTE, -86400, @T0), NULL, DATEADD(MINUTE, -72000, @T0), 88, 'PASSED'),
            (@eAn, @cBarista, DATEADD(MINUTE, -86400, @T0), DATEADD(DAY, 14, @D), NULL, NULL, 'IN_PROGRESS'),
            (@eBinh, @cFood, DATEADD(MINUTE, -86400, @T0), NULL, DATEADD(MINUTE, -72000, @T0), 81, 'PASSED'),
            (@eBinh, @cRules, DATEADD(MINUTE, -86400, @T0), NULL, DATEADD(MINUTE, -72000, @T0), 84, 'PASSED'),
            (@eChi, @cFood, DATEADD(MINUTE, -86400, @T0), NULL, DATEADD(MINUTE, -72000, @T0), 65, 'FAILED'),
            (@eChi, @cRules, DATEADD(MINUTE, -86400, @T0), DATEADD(DAY, 7, @D), NULL, NULL, 'NOT_STARTED'),
            (@eDung, @cFood, DATEADD(MINUTE, -86400, @T0), DATEADD(DAY, 14, @D), NULL, NULL, 'NOT_STARTED'),
            (@eDung, @cRules, DATEADD(MINUTE, -86400, @T0), DATEADD(DAY, 14, @D), NULL, NULL, 'NOT_STARTED'),
            (@eKhoa, @cFood, DATEADD(MINUTE, -86400, @T0), NULL, DATEADD(MINUTE, -72000, @T0), 80, 'PASSED'),
            (@eKhoa, @cRules, DATEADD(MINUTE, -86400, @T0), DATEADD(DAY, -30, @D), NULL, NULL, 'EXPIRED');


        -- 15. Quy tắc thưởng/phạt bổ sung (cần có mức CRITICAL để thử luồng Giám đốc vận hành duyệt)
        INSERT INTO dbo.RuleCatalog (RuleCode, RuleName, RuleType, Severity, DefaultAmount, IsAutomatic, Description)
        VALUES
            ('ASSET_LOSS', N'Làm mất/hư hỏng tài sản', 'VIOLATION', 'CRITICAL', NULL, 0, N'Cần Giám đốc vận hành phê duyệt'),
            ('UNIFORM_VIOLATION', N'Sai đồng phục', 'VIOLATION', 'MINOR', 20000, 0, N'Quản lý/HR xử lý'),
            ('OUTSTANDING_ACHIEVEMENT', N'Thành tích xuất sắc', 'REWARD', 'CRITICAL', NULL, 0, N'Cần Giám đốc vận hành phê duyệt');

        DECLARE @ruLate INT = (SELECT RuleId FROM dbo.RuleCatalog WHERE RuleCode = 'LATE_MINOR');
        DECLARE @ruChk INT = (SELECT RuleId FROM dbo.RuleCatalog WHERE RuleCode = 'CHECKLIST_MISSED');
        DECLARE @ruSvc INT = (SELECT RuleId FROM dbo.RuleCatalog WHERE RuleCode = 'SERVICE_ISSUE');
        DECLARE @ruCompl INT = (SELECT RuleId FROM dbo.RuleCatalog WHERE RuleCode = 'CUSTOMER_COMPLIMENT');
        DECLARE @ruKpi INT = (SELECT RuleId FROM dbo.RuleCatalog WHERE RuleCode = 'KPI_EXCEEDED');
        DECLARE @ruAsset INT = (SELECT RuleId FROM dbo.RuleCatalog WHERE RuleCode = 'ASSET_LOSS');
        DECLARE @ruUniform INT = (SELECT RuleId FROM dbo.RuleCatalog WHERE RuleCode = 'UNIFORM_VIOLATION');
        DECLARE @ruOutstanding INT = (SELECT RuleId FROM dbo.RuleCatalog WHERE RuleCode = 'OUTSTANDING_ACHIEVEMENT');

        -- 16. Sự kiện vi phạm (ViolationEvent): ghi nhận tự động từ chấm công / checklist. PENDING = chờ xử lý
        INSERT INTO dbo.ViolationEvent (EmployeeId, RuleId, AttendanceId, OccurredAt, SourceType, Details, RecordStatus, IsAutoGenerated, CreatedBy, ReviewedBy, ReviewedAt, ReviewNote)
        VALUES
            (@eAn, @ruLate, (SELECT a.AttendanceId FROM dbo.Attendance a JOIN dbo.ShiftAssignment s ON s.ShiftAssignmentId = a.ShiftAssignmentId WHERE s.EmployeeId = @eAn AND s.WorkDate = DATEADD(DAY, -24, @D)), DATEADD(MINUTE, -33960, @T0), 'ATTENDANCE', N'Đi muộn 10 phút sau ân hạn', 'REJECTED', 1, NULL, @uMgr, DATEADD(MINUTE, -33870, @T0), N'Đã giải trình: tắc đường do tai nạn'),
            (@eBinh, @ruLate, (SELECT a.AttendanceId FROM dbo.Attendance a JOIN dbo.ShiftAssignment s ON s.ShiftAssignmentId = a.ShiftAssignmentId WHERE s.EmployeeId = @eBinh AND s.WorkDate = DATEADD(DAY, -22, @D)), DATEADD(MINUTE, -31080, @T0), 'ATTENDANCE', N'Đi muộn 10 phút sau ân hạn', 'APPROVED', 1, NULL, @uMgr, DATEADD(MINUTE, -30990, @T0), N'Xác nhận'),
            (@eAn, @ruLate, (SELECT a.AttendanceId FROM dbo.Attendance a JOIN dbo.ShiftAssignment s ON s.ShiftAssignmentId = a.ShiftAssignmentId WHERE s.EmployeeId = @eAn AND s.WorkDate = DATEADD(DAY, -11, @D)), DATEADD(MINUTE, -15240, @T0), 'ATTENDANCE', N'Đi muộn 10 phút sau ân hạn', 'PENDING', 1, NULL, NULL, NULL, NULL),
            (@eAn, @ruLate, (SELECT a.AttendanceId FROM dbo.Attendance a JOIN dbo.ShiftAssignment s ON s.ShiftAssignmentId = a.ShiftAssignmentId WHERE s.EmployeeId = @eAn AND s.WorkDate = DATEADD(DAY, -8, @D)), DATEADD(MINUTE, -10920, @T0), 'ATTENDANCE', N'Đi muộn 20 phút sau ân hạn', 'PENDING', 1, NULL, NULL, NULL, NULL),
            (@eChi, @ruChk, NULL, DATEADD(MINUTE, -2280, @T0), 'CHECKLIST', N'Bỏ sót checklist sau khi hết số lần nhắc', 'PENDING', 1, NULL, NULL, NULL, NULL);

        -- 16b. Quyết định phạt tiền (EmployeeRewardPenalty, DecisionType = PENALTY). ASSET_LOSS (CRITICAL) chỉ Giám đốc duyệt được
        INSERT INTO dbo.EmployeeRewardPenalty (DecisionType, EmployeeId, RuleId, EffectiveDate, Details, Amount, DecisionStatus, ProposedBy, ApprovedBy, ApprovedAt, ReviewNote)
        VALUES
            ('PENALTY', @eChi, @ruSvc, DATEADD(MINUTE, -2280, @T0), N'Làm sai món 3 lần trong ca, khách phản ánh', 50000, 'PENDING', @uMgr, NULL, NULL, NULL),
            ('PENALTY', @eDung, @ruAsset, DATEADD(MINUTE, -3720, @T0), N'Làm vỡ máy xay cà phê trong ca', 300000, 'PENDING', @uMgr, NULL, NULL, NULL),
            ('PENALTY', @eBinh, @ruSvc, DATEADD(MINUTE, -28200, @T0), N'Giao nhầm đơn hàng nhiều lần', 50000, 'APPROVED', @uMgr, @uHr, DATEADD(MINUTE, -28110, @T0), N'Đồng ý mức phạt'),
            ('PENALTY', @eChi, @ruUniform, DATEADD(MINUTE, -12360, @T0), N'Không mặc đồng phục theo quy định', 20000, 'CANCELLED', @uMgr, @uMgr, DATEADD(MINUTE, -12270, @T0), N'Đã nhắc nhở, hủy đề xuất');

        -- 17. Thưởng (EmployeeRewardPenalty, DecisionType = REWARD)
        INSERT INTO dbo.EmployeeRewardPenalty (DecisionType, EmployeeId, RuleId, EffectiveDate, Details, Amount, DecisionStatus, ProposedBy, ApprovedBy, ApprovedAt, ReviewNote)
        VALUES
            ('REWARD', @eAn, @ruCompl, DATEADD(MINUTE, -31080, @T0), N'Khách khen thái độ phục vụ, có ảnh phản hồi', 100000, 'APPROVED', @uMgr, @uHr, DATEADD(MINUTE, -30980, @T0), N'Đồng ý'),
            ('REWARD', @eBinh, @ruCompl, DATEADD(MINUTE, -2280, @T0), N'Khách để lại lời khen trên mạng xã hội', 50000, 'PENDING', @uMgr, NULL, NULL, NULL),
            ('REWARD', @eAn, @ruOutstanding, DATEADD(MINUTE, -840, @T0), N'Xử lý sự cố mất điện, giữ ca vận hành ổn định', 500000, 'PENDING', @uMgr, NULL, NULL, NULL),
            ('REWARD', @eHr, @ruKpi, DATEADD(MINUTE, -6600, @T0), N'Vượt KPI đối soát quý', 200000, 'REJECTED', @uMgr, @uDir, DATEADD(MINUTE, -6500, @T0), N'Chưa đủ số liệu minh chứng');


        -- 18. Kỳ chốt công: kỳ A sạch (chốt được), kỳ B còn đơn treo (readiness báo vướng). Hôm nay trở đi chưa có kỳ để bạn thử tạo mới
        INSERT INTO dbo.PayrollPeriod (PeriodCode, StartDate, EndDate, PeriodStatus, CreatedBy, CreatedAt, Note)
        VALUES ('KY-' + CONVERT(VARCHAR(8), DATEADD(DAY, -27, @D), 112), DATEADD(DAY, -27, @D), DATEADD(DAY, -14, @D), 'OPEN', @uHr, DATEADD(MINUTE, -20160, @T0), N'Kỳ A – sạch, đủ điều kiện chốt');

        INSERT INTO dbo.PayrollPeriod (PeriodCode, StartDate, EndDate, PeriodStatus, CreatedBy, CreatedAt, Note)
        VALUES ('KY-' + CONVERT(VARCHAR(8), DATEADD(DAY, -13, @D), 112), DATEADD(DAY, -13, @D), DATEADD(DAY, -1, @D), 'OPEN', @uHr, DATEADD(MINUTE, -1440, @T0), N'Kỳ B – còn đơn treo, chưa chốt được');


        -- 19. Thông báo mẫu (nhiều cái chưa đọc để thử /notifications/me/unread-count và read-all)
        INSERT INTO dbo.Notification (UserId, NotificationType, Title, Message, SentAt, ReadAt, DeliveryStatus, AttemptCount, CreatedAt)
        VALUES
            (@uAn, 'SHIFT_REMINDER', N'Sắp đến giờ vào ca', N'Ca làm của bạn bắt đầu lúc 07:00', DATEADD(MINUTE, -960, @T0), DATEADD(MINUTE, -940, @T0), 'SENT', 1, DATEADD(MINUTE, -960, @T0)),
            (@uAn, 'CHECKLIST_ASSIGNED', N'Bạn có checklist mới', N'Mở cửa hàng', SYSUTCDATETIME(), NULL, 'SENT', 1, SYSUTCDATETIME()),
            (@uAn, 'DEVICE_STATUS', N'Thiết bị đã được duyệt', N'Pixel 7 của An đã được duyệt', DATEADD(MINUTE, -430080, @T0), DATEADD(MINUTE, -430060, @T0), 'SENT', 1, DATEADD(MINUTE, -430080, @T0)),
            (@uBinh, 'CHECKLIST_ASSIGNED', N'Bạn có checklist mới', N'Bàn giao ca', SYSUTCDATETIME(), NULL, 'SENT', 1, SYSUTCDATETIME()),
            (@uChi, 'TRAINING_ASSIGNED', N'Bạn được giao khóa đào tạo', N'Nội quy và quy trình cửa hàng', DATEADD(MINUTE, -3840, @T0), NULL, 'SENT', 1, DATEADD(MINUTE, -3840, @T0)),
            (@uMgr, 'VIOLATION_PENDING', N'Có vi phạm cần xem xét', N'Đi muộn: Phạm Minh An', DATEADD(MINUTE, -15360, @T0), NULL, 'SENT', 1, DATEADD(MINUTE, -15360, @T0)),
            (@uMgr, 'ADJUSTMENT_PENDING', N'Có yêu cầu điều chỉnh công chờ duyệt', N'Phạm Minh An đề nghị điều chỉnh công', DATEADD(MINUTE, -13920, @T0), NULL, 'SENT', 1, DATEADD(MINUTE, -13920, @T0)),
            (@uMgr, 'DEVICE_PENDING', N'Có thiết bị chờ duyệt', N'Vũ Quốc Bình đăng ký thiết bị mới', DATEADD(MINUTE, -960, @T0), NULL, 'SENT', 1, DATEADD(MINUTE, -960, @T0)),
            (@uHr, 'ADJUSTMENT_PENDING', N'Có điều chỉnh công chờ HR duyệt', N'Phạm Minh An – điều chỉnh check-in', DATEADD(MINUTE, -11040, @T0), NULL, 'SENT', 1, DATEADD(MINUTE, -11040, @T0)),
            (@uDir, 'DECISION_PENDING', N'Có đề xuất thưởng/phạt chờ duyệt', N'Làm mất/hư hỏng tài sản - Hoàng Tiến Dũng', DATEADD(MINUTE, -3840, @T0), NULL, 'SENT', 1, DATEADD(MINUTE, -3840, @T0)),
            (@uDir, 'DECISION_PENDING', N'Có đề xuất thưởng/phạt chờ duyệt', N'Thành tích xuất sắc - Phạm Minh An', DATEADD(MINUTE, -960, @T0), NULL, 'SENT', 1, DATEADD(MINUTE, -960, @T0));


        -- 20. Audit log mẫu (API chỉ đọc/xuất; log mới sinh thêm khi bạn thao tác)
        INSERT INTO dbo.AuditLog (ActorUserId, ActionCode, EntityType, EntityId, BeforeJson, AfterJson, IpAddress, UserAgent, CreatedAt)
        VALUES
            (@uAdmin, 'USER_CREATE', 'AppUser', CAST(@uMgr AS NVARCHAR(20)), NULL, '{"email":"quanly@hrm.test","roles":["STORE_MANAGER"]}', '127.0.0.1', 'seed-data', DATEADD(MINUTE, -431460, @T0)),
            (@uAdmin, 'USER_CREATE', 'AppUser', CAST(@uHr AS NVARCHAR(20)), NULL, '{"email":"hr@hrm.test","roles":["EMPLOYEE"]}', '127.0.0.1', 'seed-data', DATEADD(MINUTE, -431460, @T0)),
            (@uAdmin, 'USER_PERMISSIONS_CHANGE', 'AppUser', CAST(@uHr AS NVARCHAR(20)), '{"permissions":[]}', N'{"permissionSets":["HR"],"note":"cấp tập quyền HR"}', '127.0.0.1', 'seed-data', DATEADD(MINUTE, -430020, @T0)),
            (@uMgr, 'DEVICE_APPROVE', 'AttendanceDevice', CAST(@dvAn AS NVARCHAR(20)), '{"status":"PENDING"}', '{"status":"APPROVED"}', '127.0.0.1', 'seed-data', DATEADD(MINUTE, -430020, @T0)),
            (@uMgr, 'ATTENDANCE_ADJUST_MANAGER_APPROVE', 'AttendanceAdjustmentRequest', NULL, '{"managerStatus":"PENDING"}', '{"managerStatus":"APPROVED"}', '127.0.0.1', 'seed-data', DATEADD(MINUTE, -10980, @T0)),
            (@uHr, 'PAYROLL_PERIOD_CREATE', 'PayrollPeriod', NULL, NULL, '{"status":"OPEN"}', '127.0.0.1', 'seed-data', DATEADD(MINUTE, -19620, @T0)),
            (@uMgr, 'ATTENDANCE_EXCEPTION_REJECT', 'AttendanceExceptionRequest', NULL, '{"status":"PENDING"}', '{"status":"REJECTED"}', '127.0.0.1', 'seed-data', DATEADD(MINUTE, -29700, @T0));


        COMMIT TRANSACTION;
        PRINT N'Đã nạp dữ liệu test.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

