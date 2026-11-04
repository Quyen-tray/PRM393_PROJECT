# HRM Coffee Shop – Backend (Java 17 · Spring Boot 3.3 · SQL Server)

Backend REST cho **SRS HRM Coffee Shop v2.1**, bám theo **DDL duy nhất** (`config.sql`). Một cửa hàng, base path `/api/v1`.

## Chạy
1. Làm theo `docs/INSTALL.md`: trên database mới, chạy toàn bộ `config.sql` trong một query window, sau đó chạy `seeddata.sql`. Hai script nền là `config.sql` (schema) và `seeddata.sql` (seed/demo); migration có ngày trong `infra/sqlserver/migrations/` chỉ dùng một lần cho database demo đã có dữ liệu.
2. Đặt biến môi trường (xem `.env.example`): `DB_URL, DB_USERNAME, DB_PASSWORD, JWT_SECRET (≥32 ký tự), GOOGLE_CLIENT_ID` (cách lấy và cấu hình đăng nhập Google: `docs/GOOGLE_LOGIN.md`).
3. Muốn test API khi chưa làm Google login: xem **[docs/README.md](docs/README.md)** (bật `DEV_PASSWORD_LOGIN_ENABLED` + `BOOTSTRAP_ADMIN_PASSWORD`).
4. `mvn spring-boot:run` (Swagger UI: `/swagger-ui.html`). Test: `mvn test`.

Đăng nhập: app gửi Google **ID token** → `POST /auth/google` → nhận access JWT (15 phút) + refresh token (xoay vòng, lưu hash,
phát hiện dùng lại). Admin phải cấp tài khoản trước (`POST /admin/users`); không tự tạo tài khoản từ Google.

### Đăng nhập thử khi chưa có Google (ngoài SRS, mặc định TẮT)
`POST /auth/login` `{email, password}` chỉ hoạt động khi `DEV_PASSWORD_LOGIN_ENABLED=true`; nếu tắt thì trả 404. Production phải để tắt.
Hướng dẫn chi tiết từng bước: **[docs/README.md](docs/README.md)**. Không có đăng ký, đổi mật khẩu hay endpoint admin cho mật khẩu.

## Cấu trúc
```
config/      bảo mật (JWT filter, rate limit), properties
common/      ApiResponse, ErrorCode, BusinessException, handler lỗi, tiện ích thời gian/GPS
domain/ repository/   SINH TỪ DDL: python3 tools/gen_entities.py  (truy vấn tùy biến ở tools/repo_extras.py)
service/     nghiệp vụ     controller/ dto/ job/ (nhắc ca & checklist, đẩy thông báo, dọn hồ sơ/ảnh hết hạn)
```
Đổi schema → sửa SQL → chạy lại `gen_entities.py`.

## Phần đã làm (theo module SRS)
Auth/RBAC · cấu hình cửa hàng & chính sách chấm công · nhân viên · hồ sơ giấy tờ · thiết bị (chuyển máy nguyên tử) ·
đào tạo & trắc nghiệm tự chấm (không chặn nhận ca) · mẫu ca & phân ca · **chấm công** (GPS geofence, ảnh, face-hook, ân hạn/tháng, idempotency,
OT chỉ tính khi được duyệt) · giải trình · điều chỉnh công (Quản lý → HR) · checklist · vi phạm · thưởng/phạt (phân quyền theo mức độ) ·
chốt công (readiness, chặn khi còn đơn treo, mở lại có lý do) · dashboard/báo cáo · thông báo · audit (append-only, export CSV an toàn, correlation ID).

Nguyên tắc: `employeeId` luôn lấy từ token + DB; thời gian dùng giờ **server (UTC)**, hiển thị +07:00; người đề xuất ≠ người duyệt ≠ đối tượng;
mọi duyệt/từ chối/chốt/mở lại ghi audit trước–sau; ảnh chỉ qua URL ký hạn ngắn.

## Khác biệt so với SRS (vì DDL không có)
| SRS | Thực hiện |
|---|---|
| JobPosition, `positionId` | Có bảng `JobPosition`, `Employee.PositionId`. `JobTitle` là nhãn đồng bộ với tên chức vụ |
| Bộ hồ sơ / đào tạo theo chức vụ | `PositionDocumentRequirement`, `PositionTrainingRequirement` (có hiệu lực từ–đến). PUT thay toàn bộ bộ yêu cầu; lịch sử bộ cũ nằm trong audit |
| Trạng thái vi phạm OPEN/CONFIRMED… | ánh xạ PENDING→OPEN, APPROVED→CONFIRMED, REJECTED→DISMISSED |
| Thưởng & phạt chung 1 id | 2 bảng → id dạng `REWARD-12` / `PENALTY-7` |
| Checklist task/evidence/review | cấp **run**: `taskId` = ChecklistTaskId; duyệt ở cấp run. Mẫu có `Version`: sửa mẫu đã có lượt tạo version mới (dòng cùng mã), lượt cũ giữ nguyên |
| Điều chỉnh công 1 yêu cầu | mỗi trường (CHECK_IN/CHECK_OUT) là 1 dòng → API trả danh sách |
| Lịch sử lần thi | bảng `TrainingAttempt` (điểm, đạt/không, nguồn). **Điểm do Quản lý/HR nhập, nhân viên không tự gửi** |
| Role OPERATIONS_DIRECTOR; bảng Permission/RolePermission/UserPermission | được tạo trong `config.sql` và nạp dữ liệu trong `seeddata.sql`. **HR không phải role** mà là tập quyền (xem "Phân quyền") |
| Refresh token, idempotency key, DedupKey, GraceApplied, thiết bị check-in | được tạo trong `config.sql` và nạp dữ liệu trong `seeddata.sql` |

## Giả định cần chốt (đã đánh dấu trong code)
- **Ân hạn**: trong ân hạn & còn lượt → không muộn, dùng 1 lượt; quá ân hạn → muộn tính từ phút đầu sau ân hạn; hết lượt → tính từ giờ vào ca.
- Khóa theo chức vụ được dùng để theo dõi tiến độ; đào tạo không chặn nhận ca hoặc check-in.
- Nhân viên làm trắc nghiệm tại `GET /api/v1/training/courses/{courseId}/quiz` và nộp đáp án tới `POST /api/v1/training/courses/{courseId}/quiz-attempts`; backend chấm theo `PassingScore`.
- Quản trị câu hỏi qua `GET/PUT /api/v1/admin/training/courses/{courseId}/questions` với quyền `SYSTEM_ADMIN`.
- Sai số GPS tối đa 50 m (cấu hình `ATTENDANCE_GPS_MAX_ACCURACY_METERS`); QR/WiFi fallback chưa làm (chỉ qua giải trình).
- Nghỉ giữa ca luôn trừ khỏi công tính; OT chỉ tính sau giờ kết thúc ca.
- Số tiền thưởng/phạt chỉ vào bảng lương khi `APPROVED`; vi phạm tự động chỉ **ghi nhận**, không tự khấu trừ.
- Cấu hình thay đổi chỉ áp cho ca tạo mới.

## API trắc nghiệm đào tạo

- Nhân viên đã ghi danh khóa học lấy câu hỏi bằng `GET /api/v1/training/courses/{courseId}/quiz`. Response chỉ có `questionId`, `questionText` và các lựa chọn `options[{key,text}]`; đáp án đúng không lộ trước khi nộp bài.
- Nộp `POST /api/v1/training/courses/{courseId}/quiz-attempts` với `{"answers":[{"questionId":1,"selectedOption":"A"}]}`. Backend đối chiếu đủ câu hỏi, tính điểm phần trăm, lưu lượt thi và đánh dấu `PASSED` khi `score >= passScore`.
- Quản trị viên xem/sửa ngân hàng câu hỏi qua `GET/PUT /api/v1/admin/training/courses/{courseId}/questions`. Body PUT có `questions[]` với `questionText`, `optionA`–`optionD`, `correctOption` (`A`–`D`) và `sortOrder`.
- Các API dùng envelope `ApiResponse`; tiến độ đào tạo được lưu để theo dõi nhưng không chặn phân ca hoặc check-in.

## Điểm cần thay khi lên production
- `UploadScanner` (mặc định no-op, phải thay bằng malware scanner), `FaceVerificationClient` (mặc định NOT_RUN), `PushGateway` (mặc định chỉ log và không đánh dấu SENT), `StorageGateway` (local filesystem; production nhiều instance nên dùng private object storage).
- Job nhắc/dọn chạy đơn node; nhiều instance cần ShedLock. Rate limit trong bộ nhớ; nhiều instance dùng gateway/Redis.
- `AuditLog` lưu `CorrelationId`; mọi HTTP response trả `X-Correlation-Id`. Cột `CorrelationId` đã có sẵn trong `config.sql`. Với database cũ cần giữ dữ liệu, không chạy lại file cài mới; cần xử lý dữ liệu riêng trước khi nâng phiên bản backend.
- `DENY UPDATE, DELETE ON dbo.AuditLog` cho tài khoản ứng dụng.
- Danh sách `GET /rewards-penalties` gộp 2 bảng trong bộ nhớ (đủ cho một cửa hàng).

## Kiểm chứng đã thực hiện / chưa
Môi trường tạo mã **không có Maven & không tải được thư viện**, nên **chưa chạy `mvn package`, chưa chạy test, chưa chạy với SQL Server thật**.
Đã làm: biên dịch toàn bộ `src/main/java` bằng `javac` (`java -m jdk.compiler/com.sun.tools.javac.Main`) với lỗi thư viện ngoài được bỏ qua; đối chiếu getter/setter và số tham số record; sinh lại entity/repository bằng `tools/gen_entities.py` trên bản sao và đồng bộ về repo; kiểm tra cú pháp T-SQL bằng `sqlglot`.
Chưa kiểm: `mvn package`, truy vấn JPQL lúc khởi động, cài mới và chạy seed trên SQL Server, hành vi runtime, lớp `config/`.
Nếu `mvn spring-boot:run` báo lỗi, gửi log để chỉnh.


## Bổ sung cho app Flutter (chưa chạy `mvn`)
- `POST /storage/uploads?purpose=ATTENDANCE|CHECKLIST|DOCUMENT`: body là bytes thô; ATTENDANCE/CHECKLIST nhận JPEG/PNG/WebP tối đa 8 MB, DOCUMENT nhận PDF/JPEG/PNG/WebP tối đa 10 MB. Server nhận dạng chữ ký file và tự sinh `storageKey`. Lưu trên đĩa tại `STORAGE_LOCAL_DIR` (mặc định `./data/storage`); `GET /storage/view` phục vụ URL ký HMAC 120 giây. Dùng S3/Azure/GCS: viết bean `StorageGateway` và đặt `app.storage.provider` khác `local`.
- `GET /documents/pending` (Quản lý/HR), `GET /attendance/explanation-requests/me`, `GET /attendance/overtime-requests/me`.
- `UserView` thêm `status`; `DocumentView` thêm `employeeName`.
- `POST /attendance/devices/register`: nếu thiết bị đã được duyệt cho chính nhân viên đó thì trả lại thiết bị (không tạo yêu cầu mới) — phục vụ cài lại app.

## Phân quyền (role + permission)

- **Role** (`SYSTEM_ADMIN`, `STORE_MANAGER`, `EMPLOYEE`, `OPERATIONS_DIRECTOR`) mang một bộ quyền mặc định (`dbo.RolePermission`).
- **HR là tập quyền** (SRS 1.2), gán trực tiếp cho người dùng (`dbo.UserPermission`), thường cho một Quản lý hoặc Nhân viên: `PUT /api/v1/admin/users/{id}/permissions` với `{"permissionSets":["HR"]}`.
  `GET /admin/users/permission-catalog` liệt kê quyền và tập quyền; `GET /admin/users/{id}/permissions` xem quyền gán trực tiếp và quyền hiệu lực.
- Quyền hiệu lực = quyền của role ∪ quyền gán trực tiếp, **nạp lại từ DB mỗi request** (`JwtAuthFilter`) nên đổi quyền có hiệu lực ngay, không cần đăng nhập lại.
- Endpoint dùng `@PreAuthorize("hasAuthority('PAYROLL_FINALIZE')")`; service dùng `SecurityUtils.requirePermission(Permissions.X)`. Hằng số ở `common/Permissions.java`, tập quyền dựng sẵn ở `common/PermissionSets.java`.
- Quyền nhạy cảm **không nằm trong tập HR**, cấp riêng khi cần: `EVIDENCE_DOWNLOAD` (tải ảnh xác minh), `PAYROLL_REOPEN` (mở lại kỳ công). Mọi lần đổi quyền được audit (`USER_PERMISSIONS_CHANGE`).
- Các luồng chỉ dành riêng Quản lý (duyệt giải trình, OT, duyệt điều chỉnh bước 1, phân ca...) vẫn kiểm bằng `hasRole('STORE_MANAGER')`.
- Database mới được dựng hoàn chỉnh từ `config.sql` + `seeddata.sql`. Không chạy lại hai file này trên database đang có dữ liệu để nâng cấp; dự án hiện không cung cấp migration. Thay đổi schema trong giai đoạn phát triển được thực hiện trực tiếp trong `config.sql`, rồi kiểm tra trên database test mới.
- Sau khi sửa DDL/`tools/repo_extras.py`, sinh lại entity bằng `python tools/gen_entities.py`.

## Bổ sung: kỹ năng, endpoint nhân viên, checklist chờ duyệt
- **Kỹ năng (FR-012)**: bảng `Skill`, `EmployeeSkill` (`config.sql`). `GET /skills`, `POST /admin/skills` (Admin), `POST /employees/{id}/skills/assessments` (quyền `TRAINING_MANAGE`: Quản lý/HR; mức 1–5, không tự đánh giá mình, mỗi lần là một dòng lịch sử), `GET /employees/{id}/skills` (bản thân hoặc `EMPLOYEE_VIEW`).
- `GET /employees/{id}/training`, `GET /employees/{id}/attendance-summary?from=&to=` (mặc định tháng hiện tại, tối đa 366 ngày) — cùng quy tắc xem như `/overview`.
- `GET /checklists/reviews/pending` — checklist đã nộp, chờ Quản lý duyệt.
- Đã có `/admin/job-positions*` (danh sách, tạo, sửa, bộ hồ sơ, bộ đào tạo theo chức vụ). Chức vụ không còn là chuỗi tự do.

## Tài liệu dự án

- [Cài đặt database](docs/INSTALL.md) — quy trình fresh install bằng đúng hai file `config.sql` và `seeddata.sql`.
- [Hướng dẫn chạy và test API](docs/README.md) — cấu hình local, tài khoản test và gọi API.
- [Đăng nhập Google](docs/GOOGLE_LOGIN.md) — Google Client ID, bootstrap Gmail admin và xử lý khôi phục tài khoản.
- [Kiểm thử tích hợp](docs/INTEGRATION_TESTS.md) — Testcontainers, seed và các luồng concurrency/security.
- [Đối chiếu SRS](docs/SRS_ALIGNMENT.md) — khác biệt giữa SRS và implementation.
- [Backend handoff](docs/BACKEND_HANDOFF.md) — trạng thái, giới hạn kiểm chứng và các việc còn phụ thuộc hạ tầng.

**Quy ước SQL:** chỉ duy trì `config.sql` và `seeddata.sql`. Nội dung SQL one-off nếu cần vận hành database hiện hữu chỉ được mô tả trong tài liệu để DBA thực hiện có kiểm soát; không tạo thêm file `.sql` riêng.
