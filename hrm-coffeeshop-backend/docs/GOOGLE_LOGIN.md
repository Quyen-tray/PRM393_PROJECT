# Hướng dẫn hoàn thiện đăng nhập Google (chi tiết)

SRS mục 3.1: người dùng đăng nhập bằng Google; backend xác minh ID token (chữ ký, issuer, audience, expiry) và trạng thái tài khoản.
Tài liệu chia rõ **phần code đã làm** và **phần bạn phải tự thao tác** (vì cần tài khoản Google Cloud của bạn).
Làm lần lượt từ mục 1 đến mục 6; mục 7 trở đi để tra cứu.

## 0. Tóm tắt

| Việc | Ai làm | Trạng thái |
|---|---|---|
| `POST /auth/google`: xác minh ID token, khớp tài khoản theo `GoogleSubject` rồi theo email, **không tự tạo tài khoản** | Code | Xong |
| `GOOGLE_CLIENT_ID` nhận nhiều Client ID (ngăn cách dấu phẩy) | Code | Xong |
| Lỗi rõ ràng: token sai (401), thiếu cấu hình (500, ghi rõ thiếu `GOOGLE_CLIENT_ID`), không gọi được Google (500) | Code | Xong |
| Cảnh báo trong log khi khởi động nếu thiếu `GOOGLE_CLIENT_ID` | Code | Xong |
| Test `GoogleLoginServiceTest`, `GoogleTokenVerifierTest` | Code | Xong, **bạn chạy `mvn test`** |
| Cấu hình Gmail admin trong `seeddata.sql` khi cài mới; với DB đã có dữ liệu, DBA cập nhật trực tiếp theo hướng dẫn bên dưới (không tạo file SQL thứ ba) | Hướng dẫn | Có |
| Tạo Client ID trên Google Cloud | **Bạn** | Mục 1 |
| Đặt `GOOGLE_CLIENT_ID` | **Bạn** | Mục 2 |
| Thay email bootstrap trong `seeddata.sql` bằng Gmail thật | **Bạn** | Mục 3 |
| Thử bằng ID token thật | **Bạn** | Mục 4 |
| Tạo tài khoản cho nhân viên | **Bạn** (Admin/Quản lý) | Mục 5 |
| Nút "Đăng nhập Google" trong app Flutter | App đã có sẵn; **bạn** cấu hình theo `docs/GOOGLE_LOGIN_APP.md` của app | Mục 6 |
| Lên production | **Bạn** | Mục 9 |

Backend đã có sẵn: `/auth/google`, `/auth/refresh`, `/auth/logout`, `/users/me`, `/users/me/permissions`.

---

## 1. Tạo Client ID trên Google Cloud

Giao diện Google hay đổi tên menu; nếu không thấy đúng tên, tìm mục tương đương.

### 1.1. Tạo project
1. Vào https://console.cloud.google.com, đăng nhập bằng Gmail của bạn.
2. Bấm ô chọn project ở thanh trên cùng → **New Project**.
3. Project name: `hrm-coffeeshop` → **Create**. Đợi vài giây rồi chọn project vừa tạo.

### 1.2. Cấu hình màn hình đồng ý OAuth (consent screen)
1. Menu bên trái: **APIs & Services → OAuth consent screen** (hoặc **Google Auth Platform**) → **Get started**.
2. **App information**: App name `HRM Coffee Shop`; User support email chọn Gmail của bạn → Next.
3. **Audience**: chọn **External** → Next.
4. **Contact information**: nhập Gmail của bạn → Next → tick đồng ý chính sách → **Create**.
5. Vào mục **Audience** (menu trái) → phần **Test users** → **Add users** → nhập **từng Gmail sẽ đăng nhập thử** (Gmail admin, Gmail nhân viên test) → **Save**.
   - Khi app còn ở trạng thái **Testing**, chỉ các Gmail này đăng nhập được; Gmail khác sẽ bị Google báo `access_denied`.
   - Tối đa 100 test user.
6. Chỉ dùng phạm vi mặc định `openid`, `email`, `profile`; không cần thêm phạm vi nào.

### 1.3. Tạo Web Client ID (bắt buộc, đây là giá trị đưa vào backend)
1. **APIs & Services → Credentials → Create credentials → OAuth client ID** (hoặc **Clients → Create client**).
2. Application type: **Web application**. Name: `hrm-backend-web`.
3. Mục **Authorized redirect URIs** → **Add URI** → `https://developers.google.com/oauthplayground` (để thử ở mục 4).
4. **Create**. Hộp thoại hiện:
   - **Client ID** dạng `1234567890-abcdefg.apps.googleusercontent.com` → copy, lưu lại.
   - **Client secret** → copy, lưu lại. Chỉ dùng ở mục 4; **không** đưa vào code hay Git.

### 1.4. Tạo Android Client ID (nếu app chạy Android)
1. Lấy SHA-1 của khóa debug. Windows (cmd):
   ```
   keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
   ```
   Hoặc trong thư mục `android` của app Flutter chạy `gradlew signingReport` và lấy dòng `SHA1` của biến thể `debug`.
2. Lấy package name: file `android/app/build.gradle(.kts)`, dòng `applicationId`.
3. **Credentials → Create credentials → OAuth client ID → Android**: nhập package name và SHA-1 → **Create**.
4. Mỗi khóa ký khác nhau (máy bạn, máy bạn cùng nhóm, khóa release) cần thêm SHA-1 riêng. Có thể tạo thêm Android Client ID hoặc thêm vào cùng project theo hướng dẫn của Google.
5. Backend **không** cần Android Client ID. Nó chỉ để Google cho phép app Android của bạn đăng nhập.

### 1.5. Tạo iOS Client ID (chỉ nếu chạy iOS)
**Credentials → Create credentials → OAuth client ID → iOS**, nhập Bundle ID. Nếu app dùng iOS Client ID làm audience của token (không truyền `serverClientId`), thêm ID này vào `GOOGLE_CLIENT_ID` (dùng dấu phẩy). Cách chuẩn vẫn là truyền `serverClientId` = Web Client ID (mục 6).

---

## 2. Đặt `GOOGLE_CLIENT_ID` cho backend

IntelliJ: **Run → Edit Configurations → chọn cấu hình của app Spring Boot → Environment variables**, thêm (giữ các biến cũ):
```
GOOGLE_CLIENT_ID=1234567890-abcdefg.apps.googleusercontent.com
```
- Nhiều Client ID: ngăn cách bằng dấu phẩy, không cần khoảng trắng: `id-web.apps.googleusercontent.com,id-ios.apps.googleusercontent.com`.
- Chạy lại app, xem log:
  - Thấy `Đăng nhập Google: chấp nhận 1 Client ID` → đã nhận.
  - Thấy cảnh báo `GOOGLE_CLIENT_ID chưa được cấu hình` → chưa nhận. Nhớ rằng file `.env` có thể không được Spring tự đọc; hãy đặt trong Run Configuration hoặc biến môi trường hệ thống.

---

## 3. Đổi admin thành Gmail thật

Seed hiện khai báo email quản trị bootstrap là `baonvhe181955@fpt.edu.vn`. Bạn phải thay giá trị này bằng Gmail quản trị thực tế nếu email đó không thuộc quyền kiểm soát của bạn.

**Database mới:** sửa email tại khối `Tài khoản quản trị đầu tiên` trong `seeddata.sql` trước khi chạy seed. Không cần và không được tạo `set_admin_google.sql`; dự án chỉ duy trì `config.sql` và `seeddata.sql`.

**Database đã có dữ liệu:** không chạy lại `config.sql`/`seeddata.sql`. Nếu cần chuyển email admin hoặc gỡ liên kết Google cũ, DBA phải xác minh đúng tài khoản `SYSTEM_ADMIN`, backup database trước, rồi chạy câu lệnh one-off trực tiếp trong SSMS/Azure Data Studio (không lưu thành file `.sql` riêng). Thay hai giá trị bên dưới; câu lệnh sẽ dừng nếu email mới đã được tài khoản khác sử dụng hoặc email cũ không phải tài khoản `SYSTEM_ADMIN` đang ACTIVE:

```sql
DECLARE @CurrentEmail NVARCHAR(320) = N'admin-cu@example.com';
DECLARE @NewEmail NVARCHAR(320) = N'gmail-quan-tri-moi@gmail.com';

IF EXISTS (SELECT 1 FROM dbo.AppUser WHERE Email = @NewEmail AND Email <> @CurrentEmail)
    THROW 51001, 'Email moi da duoc su dung boi tai khoan khac.', 1;

IF (SELECT COUNT(*)
    FROM dbo.AppUser u
    JOIN dbo.UserRole ur ON ur.UserId = u.UserId
    JOIN dbo.Role r ON r.RoleId = ur.RoleId
    WHERE u.Email = @CurrentEmail
      AND u.UserStatus = 'ACTIVE'
      AND r.RoleCode = 'SYSTEM_ADMIN') <> 1
    THROW 51002, 'Khong tim thay dung mot tai khoan SYSTEM_ADMIN ACTIVE.', 1;

BEGIN TRANSACTION;
UPDATE dbo.AppUser
SET Email = @NewEmail, GoogleSubject = NULL
WHERE Email = @CurrentEmail AND UserStatus = 'ACTIVE';
IF @@ROWCOUNT <> 1
BEGIN
    ROLLBACK TRANSACTION;
    THROW 51003, 'Cap nhat admin khong thanh cong.', 1;
END;
COMMIT TRANSACTION;

SELECT u.UserId, u.Email, u.UserStatus, r.RoleCode, u.GoogleSubject
FROM dbo.AppUser u
JOIN dbo.UserRole ur ON ur.UserId = u.UserId
JOIN dbo.Role r ON r.RoleId = ur.RoleId
WHERE u.Email = @NewEmail AND r.RoleCode = 'SYSTEM_ADMIN';
```

Sau khi đổi, thêm Gmail mới vào Google OAuth Test users (nếu đang ở chế độ Testing), kiểm tra kết quả chỉ có một tài khoản `SYSTEM_ADMIN` / `ACTIVE`, `GoogleSubject` là `NULL`, rồi đăng nhập Google để backend liên kết subject mới. Thao tác này cần DBA có quyền UPDATE; không thực hiện khi chưa backup.

---

## 4. Thử backend bằng ID token thật (chưa cần app Flutter)

1. Mở https://developers.google.com/oauthplayground.
2. Bấm biểu tượng bánh răng (góc phải trên) → tick **Use your own OAuth credentials** → dán **Client ID** và **Client secret** của Web Client (mục 1.3) → đóng.
3. Ô nhập scope bên trái (ô "Input your own scopes"), gõ: `openid email profile` → **Authorize APIs** → chọn đúng Gmail admin → **Continue / Allow**.
   - Nếu Google cảnh báo "Google hasn't verified this app", bấm **Advanced → Go to ... (unsafe)**. Đây là app của bạn nên an toàn.
4. Bước 2 trên Playground: **Exchange authorization code for tokens**. Trong khung phản hồi bên phải, copy giá trị `id_token` (chuỗi rất dài, có 2 dấu chấm).
5. Gọi API bằng Swagger (`http://localhost:8080/swagger-ui.html`) hoặc curl:
   ```
   curl -X POST http://localhost:8080/api/v1/auth/google \
        -H "Content-Type: application/json" \
        -d "{\"idToken\":\"<dán id_token>\"}"
   ```
6. Thành công, kết quả dạng:
   ```json
   {
     "message": "Login successful",
     "data": {
       "accessToken": "eyJ...",
       "refreshToken": "....",
       "tokenType": "Bearer",
       "expiresIn": 900,
       "user": { "userId": 1, "email": "gmail-cua-ban@gmail.com", "roles": ["SYSTEM_ADMIN"], "status": "ACTIVE" }
     }
   }
   ```
7. Dán `data.accessToken` vào nút **Authorize** của Swagger để gọi các API khác.
8. ID token hết hạn sau khoảng 1 giờ; hết hạn thì làm lại bước 4. Dùng Client ID khác với `GOOGLE_CLIENT_ID` của backend sẽ bị báo token không hợp lệ (sai audience).

---

## 5. Tạo tài khoản cho nhân viên (bắt buộc trước khi họ đăng nhập)

Đăng nhập Google chỉ cho vào khi email đã có trong hệ thống. Người chưa được tạo sẽ nhận `ACCOUNT_NOT_ACTIVE` và **không có dòng nào được tạo trong DB**.

Dùng Swagger sau khi đăng nhập admin (mục 4):

### 5.1. Tạo tài khoản đăng nhập: `POST /admin/users`
```json
{
  "email": "nv.an@gmail.com",
  "displayName": "Nguyễn Văn An",
  "phoneNumber": "0900000000",
  "roles": ["EMPLOYEE"]
}
```
- Nhập **đúng** Gmail của người đó (gõ nhầm sẽ cấp quyền cho người khác). Email được lưu chữ thường.
- Vai trò hợp lệ: `EMPLOYEE`, `STORE_MANAGER`, `OPERATIONS_DIRECTOR`, `SYSTEM_ADMIN`. Bỏ trống `roles` thì mặc định `EMPLOYEE`.
- Ghi lại `userId` trong kết quả.

### 5.2. Tạo hồ sơ nhân viên: `POST /employees` (Admin hoặc Quản lý)
```json
{
  "userId": 25,
  "employeeCode": "EMP025",
  "jobTitle": "Pha chế",
  "employmentType": "FULL_TIME",
  "hireDate": "2026-10-17"
}
```
`employmentType`: `FULL_TIME`, `PART_TIME`, `TEMPORARY`, `PROBATION`. Có hồ sơ này, người dùng mới có `employeeId` để chấm công, xem lịch, nộp hồ sơ.

### 5.3. Cấp quyền HR cho một người: `PUT /admin/users/{userId}/permissions`
HR là tập quyền, không phải vai trò (SRS mục 2):
```json
{ "permissions": [], "permissionSets": ["HR"] }
```
Xem danh mục quyền: `GET /admin/users/permission-catalog`.

### 5.4. Đổi vai trò: `PUT /admin/users/{userId}/roles`
```json
{ "roles": ["EMPLOYEE", "STORE_MANAGER"] }
```
Không tự gỡ quyền `SYSTEM_ADMIN` của chính mình được (hệ thống chặn để tránh tự khóa).

### 5.5. Khóa / mở tài khoản: `PATCH /admin/users/{userId}/status`
```json
{ "status": "LOCKED" }
```
Trạng thái: `ACTIVE`, `LOCKED`, `INACTIVE`, `PENDING`. Chỉ `ACTIVE` mới đăng nhập được; refresh token của người bị khóa cũng không dùng được. Nhân viên nghỉ việc: dùng thêm `PATCH /employees/{id}/status` với `RESIGNED`.

### 5.6. Nhân viên đăng nhập lần đầu
Nhân viên mở app → "Đăng nhập Google" → chọn đúng Gmail đã nhập ở bước 5.1. Backend khớp theo email, lưu `GoogleSubject`. Từ lần sau, khớp theo `GoogleSubject`.

---

## 6. App Flutter

App (`hrm_coffeeshop_app`) **đã có sẵn** đăng nhập Google (`google_sign_in` 6.x), lưu token bằng `flutter_secure_storage`, tự refresh token và đăng xuất. Màn **Quản trị → Tài khoản** trong app cho Admin tạo tài khoản, sửa vai trò, khóa/mở và tạo hồ sơ nhân viên (tương đương mục 5 ở trên, làm bằng giao diện thay vì Swagger).

Phần còn lại là cấu hình, nằm trong file **`docs/GOOGLE_LOGIN_APP.md` của app** (đi kèm `hrm_coffeeshop_app.zip`):
1. Tạo thư mục `android/` và `ios/` bằng `flutter create .` (zip app không có).
2. Thêm quyền INTERNET / vị trí / camera vào `AndroidManifest.xml`; `usesCleartextTraffic` khi dev.
3. Tạo Android Client ID (package name `com.hrm.hrm_coffeeshop_app` + SHA-1 debug), ở mục 1.4 của file này.
4. Chạy app với `--dart-define=GOOGLE_CLIENT_ID=<Web Client ID>`, **trùng** `GOOGLE_CLIENT_ID` của backend.

## 7. Lỗi thường gặp

| Hiện tượng | Nguyên nhân / cách xử lý |
|---|---|
| `INVALID_TOKEN` "Google ID token không hợp lệ" | Token hết hạn; audience không khớp `GOOGLE_CLIENT_ID` (Playground/app dùng Client ID khác); hoặc gửi nhầm `accessToken` thay vì `idToken` |
| 500 "chưa cấu hình đăng nhập Google (thiếu GOOGLE_CLIENT_ID)" | Chưa đặt biến, hoặc đặt sai chỗ; xem log khởi động |
| 500 "Không kết nối được Google để xác minh" | Máy chạy backend không ra được internet / bị chặn tới Google; thử lại |
| `ACCOUNT_NOT_ACTIVE` "Tài khoản chưa được cấp quyền" | Email Google chưa có trong `AppUser`. Admin tạo tài khoản trước (mục 5.1) |
| `ACCOUNT_NOT_ACTIVE` "Tài khoản Google không khớp..." | Email đã gắn với một Google subject khác. Chỉ DBA sau khi xác minh danh tính và backup mới được reset `GoogleSubject`; với admin, dùng quy trình cập nhật one-off ở mục 3. Không xóa subject tùy tiện của nhân viên |
| `ACCOUNT_NOT_ACTIVE` "bị khóa hoặc chưa kích hoạt" / "chưa được gán quyền" | `UserStatus` không phải `ACTIVE`, hoặc chưa có vai trò |
| Google báo `access_denied` / "app chưa được xác minh" | Gmail chưa nằm trong **Test users** (mục 1.2) |
| App Android `ApiException: 10` (DEVELOPER_ERROR) | Sai package name hoặc SHA-1 trong Android Client ID (mục 1.4) |
| App Android `ApiException: 12500` | Thiếu User support email ở consent screen, hoặc chưa cấu hình consent screen |
| `idToken` là `null` trong app | Chạy app thiếu `--dart-define=GOOGLE_CLIENT_ID=...` |
| App gọi API báo lỗi kết nối trên emulator | Dùng `10.0.2.2` thay `localhost`; bật `usesCleartextTraffic` khi dev (xem `docs/GOOGLE_LOGIN_APP.md` của app) |
| Bị đăng xuất mọi thiết bị bất ngờ | Dùng lại refresh token cũ (đã bị xoay vòng) → hệ thống thu hồi mọi phiên. App đã xử lý đúng (lưu đè refresh token mới, refresh một lần) |

---

## 8. Kiểm tra xong chưa (checklist)

- [ ] `mvn test` chạy xanh (có `GoogleLoginServiceTest`, `GoogleTokenVerifierTest`).
- [ ] Log khởi động có `Đăng nhập Google: chấp nhận ... Client ID`.
- [ ] Với DB mới, đã đặt Gmail thật trong `seeddata.sql` trước khi seed; với DB hiện hữu, nếu phải đổi email đã thực hiện quy trình DBA ở mục 3. Truy vấn xác nhận đúng 1 dòng `SYSTEM_ADMIN` / `ACTIVE`.
- [ ] Đăng nhập bằng ID token thật ở Playground thành công, `roles` có `SYSTEM_ADMIN`.
- [ ] Gmail **chưa** được tạo trong hệ thống đăng nhập thì nhận `ACCOUNT_NOT_ACTIVE` (kiểm tra an toàn).
- [ ] Tạo 1 nhân viên (mục 5.1 + 5.2), nhân viên đó đăng nhập được và `GET /users/me` trả đúng `employeeId`.
- [ ] Khóa nhân viên đó (mục 5.5): đăng nhập lại và `POST /auth/refresh` đều bị từ chối.
- [ ] App Flutter đăng nhập được (làm theo `docs/GOOGLE_LOGIN_APP.md` của app), refresh và đăng xuất chạy đúng.

---

## 9. Khi lên production

1. `DEV_PASSWORD_LOGIN_ENABLED=false` (hoặc xóa biến); xóa `BOOTSTRAP_ADMIN_PASSWORD` và `TEST_ACCOUNTS_PASSWORD`. Khi đó `/auth/login` trả 404.
2. Rà soát và xóa khối dữ liệu test trong `seeddata.sql`; admin dùng Gmail thật và có **ít nhất 2 admin** (2 người khác nhau).
3. Consent screen: chuyển Audience từ **Testing** sang **In production** để mọi Gmail đăng nhập được (với `openid/email/profile` thường không cần Google duyệt). Backend vẫn chỉ cho vào những email Admin đã cấp.
4. Thêm SHA-1 của khóa **release** (và SHA-1 của Play App Signing nếu đưa lên Google Play) vào Android Client ID.
5. Backend chạy sau HTTPS; gỡ `usesCleartextTraffic` khỏi app.
6. Đặt `JWT_SECRET`, `STORAGE_SIGNING_SECRET`, `DB_PASSWORD` thành giá trị mạnh, không dùng giá trị mặc định.
7. Bật xác minh 2 bước và email khôi phục cho Gmail của admin.
8. Lưu quy trình DBA one-off ở mục 3 vào tài liệu vận hành; không tạo thêm file SQL ngoài `config.sql` và `seeddata.sql`.

---

## 10. Những phần SRS còn thiếu hoặc chưa nối dịch vụ thật (kết quả rà soát)

Mình so sánh danh sách endpoint trong SRS mục 9 với code (so theo method + đường dẫn; chưa so từng trường request/response hay luật nghiệp vụ).

| Hạng mục | Tình trạng |
|---|---|
| Đường dẫn payroll | SRS dùng `/payroll-periods`. Code cũ dùng `/payroll/periods`. Đã sửa theo SRS, **vẫn giữ đường dẫn cũ làm alias**. App hiện vẫn gọi `/payroll/periods` và `/checklists/tasks/me` nên **chưa được bỏ alias**; chỉ bỏ sau khi sửa app sang đường dẫn mới |
| `GET /checklists/me`, `GET /checklists/instances` | Đã thêm (alias của `/checklists/tasks/me`, `/checklists/tasks`) |
| `POST /checklists/tasks/{taskId}/evidence` | Đã thêm (body: `runItemId`, `evidenceStorageKey` bắt đầu bằng `checklist-evidence/`) |
| `POST /admin/checklist-templates/{templateId}/activate` | Đã thêm |
| Nhóm `/admin/job-positions` | Đã triển khai; bảng `JobPosition`, `PositionDocumentRequirement` và `PositionTrainingRequirement` nằm trong `config.sql`. |
| Xác minh khuôn mặt (`NoopFaceVerificationClient`) | Bản giả, luôn trả `NOT_RUN`. Cần nối dịch vụ thật |
| Push thông báo (`LoggingPushGateway`) | Bản giả, chỉ ghi log. Cần nối FCM |
| Lưu ảnh | Đang lưu trên đĩa (`provider: local`). Production nên chuyển S3/Azure/GCS |
| Ngoài SRS đang giữ | `POST /auth/login` (dev, mặc định tắt), `/admin/users*` (cần để Admin cấp tài khoản), `POST /admin/skills`, `GET /employees/{id}/skills` |
