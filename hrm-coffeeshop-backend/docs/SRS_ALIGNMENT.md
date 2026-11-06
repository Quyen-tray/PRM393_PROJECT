# Đối chiếu backend với SRS HRM Coffee Shop v2.1 — tài liệu bàn giao

## 1. Kết luận

Backend đã khớp với SRS v2.1 ở các mức: **ERD** (tên bảng và các cột chính), **API** (đủ endpoint trong mục 9), **mã lỗi và trạng thái** (mục 8.5, 12.x), **quy tắc chốt công và xác minh**.

Vẫn còn một số khác biệt **có chủ đích** (mục 3). Các khác biệt này được chọn để giữ tính toàn vẹn dữ liệu hoặc tránh phá API đang dùng, và cần leader chấp nhận hoặc chỉnh lại.

Chưa kiểm chứng trên môi trường thật (xem mục 5). Đây là điều kiện trước khi đưa vào vận hành.

## 2. Quyết định chuyên môn đã chốt

| # | Vấn đề | Quyết định | Lý do |
|---|---|---|---|
| Q1 | Đăng nhập | Chỉ Google (`POST /auth/google`). Bỏ mật khẩu, `PasswordPolicy`, bootstrap tài khoản | SRS 9.1 chỉ có Google. Mật khẩu là đường vào ngoài SRS |
| Q2 | Tổng hợp công theo nhân viên | Bỏ `PayrollSummary` và `/summaries` | Không có trong SRS. Kỳ công giữ readiness, xác nhận và chốt (9.13) |
| Q3 | Cấu hình hệ thống | Bỏ `AppSetting`. Cấu hình chung ở `Store`; nhắc việc ở `ReminderRule` | SRS 7.4 có `Store` (cấu hình chung) và `ReminderRule` |
| Q4 | Xác minh chấm công | `AttendanceVerification` lưu **một dòng cho mỗi lần kiểm tra** (GPS, DEVICE, PHOTO, FACE_LIVENESS), có `VerificationStatus`, `FailureReason` | SRS 7.4. Trước đây kết quả được suy ra khi xem |
| Q5 | Duyệt thủ công | Ghi thêm dòng GPS `EXEMPTED` khi giải trình hoặc điều chỉnh được duyệt | Kết quả xác minh phải phản ánh đúng cách công được duyệt |
| Q6 | Tệp đính kèm giải trình | Lưu trên `AttendanceExceptionRequest` (`EvidenceStorageKey`, `RetainUntil`), không lưu trong bảng xác minh | Bảng xác minh chỉ chứa kết quả kiểm tra |
| Q7 | Thời hạn lưu ảnh | Dọn tệp hết hạn cho cả ảnh xác minh và tệp giải trình; giữ bản ghi và audit | BR-PHOTO, SRS 4.x |
| Q8 | Thưởng/phạt | Một bảng `EmployeeRewardPenalty` với `DecisionType`. Đổi tên cột theo SRS (`DecisionStatus`, `ProposedBy`, `ApprovedBy`, `ApprovedAt`, `EffectiveDate`) | SRS 7.4 |
| Q9 | Vi phạm | `ViolationEvent` không còn số tiền. Phạt là quyết định riêng; `SourceType`/`SourceId` cho biết nguồn | SRS 9.9, FR-015: không khấu trừ từ sự kiện chưa xác minh |
| Q10 | Checklist | `ChecklistInstance` (nhóm theo mẫu, ngày, ca), `ChecklistEvidence` (mỗi minh chứng một dòng), `ChecklistReview` (mỗi lần duyệt một dòng). Cờ duyệt ở cấp mục `RequiresManagerApproval` | SRS 7.4 |
| Q11 | Thiết bị | Một cột `Status` (PENDING/ACTIVE/LOCKED/REJECTED/REVOKED); `DeviceFingerprint` lưu bản băm | SRS 7.4 |
| Q12 | Trạng thái chấm công | Bỏ `ABSENT`. Vắng mặt được tính trong thống kê | SRS 8.5 không có trạng thái này |
| Q13 | Giải trình chấm công | Giữ `AttendanceExceptionRequest` và các endpoint giải trình (SRS 9.6) | SRS có endpoint nhưng thiếu bảng trong ERD. Bổ sung bảng này vào ERD |

## 3. Khác biệt còn lại có chủ đích

1. **`StoreId` là INT** (SRS dùng BIGINT ở một số bảng). Cửa hàng đơn, không cần khóa lớn hơn. Leader quyết định có đổi hay không.
2. **`ChecklistTask.EmployeeId`** thay cho `AssignedEmployeeId`. Hai tên có cùng nghĩa (nhân viên được giao lượt này). Đổi tên ảnh hưởng ~20 chỗ dùng chung.
3. **`EmployeeRewardPenalty.EffectiveDate` là DATETIME2** (SRS: date). Giữ kiểu thời điểm để không đổi logic lọc kỳ lương.
4. **`RuleId` (khóa thay thế) thay cho `RuleCode`/`ReasonCode`** trong `ViolationEvent` và `EmployeeRewardPenalty`. `RuleCatalog.RuleCode` là duy nhất, nên thông tin tương đương. API trả về mã lý do.
5. **Trạng thái chấm công trong DB** chi tiết hơn SRS (`IN_PROGRESS`, `PRESENT`, `LATE`, `EARLY_LEAVE`, `EXPLANATION_PENDING`, `APPROVED_EXCEPTION`). API ánh xạ về năm trạng thái SRS (`CHECKED_IN`, `CHECKED_OUT`, `REVIEW_REQUIRED`, `ADJUSTMENT_PENDING`, `FINALIZED`).
6. **Kết quả xác minh thất bại**: đã bổ sung bảng `AttendanceVerificationAttempt` riêng để lưu lần xác minh không đạt, không tạo bản ghi Attendance giả. Có `VerificationAttemptRecorder`, retention job và integration test `VerificationAttemptIT`. Bảng đã được tích hợp trực tiếp trong schema `config.sql`.
7. **Mã quyết định thưởng/phạt giữ dạng `REWARD-{id}` / `PENALTY-{id}`** để không phá client. ERD dùng id số.
8. **Endpoint ngoài SRS v2.0** (đã đưa vào SRS v2.1, mục 9): `GET /attendance/overtime-requests` và `.../reject` (SRS chỉ có tạo và duyệt OT), `GET /documents/pending` (hàng chờ duyệt hồ sơ), `POST /checklists/tasks/{id}/items/{itemId}/complete` (hoàn thành từng mục), `GET /employees/me`, `/admin/users/*` (vai trò, quyền, khóa tài khoản), `POST /admin/skills`, `/storage/uploads` và `/storage/view`.
9. **Bảng ngoài ERD**: `AttendanceExceptionRequest`, `RuleCatalog`, `RefreshToken` (cho `/auth/refresh`), `ChecklistEvidence`, `ChecklistReview`, `ChecklistInstance`, `EmployeeSkill`, `ContentHash`/`AiProvider`/`AiResultJson`/`RetainUntil` trên `AttendanceVerification`.
10. **Số lần thi không có giới hạn.** SRS nhắc "số lần thi" nhưng không có giá trị.
11. **Quyết định D-01 đến D-12** (mục 14 SRS) vẫn mở. Đặc biệt: D-03 (QR/Wi-Fi dự phòng), D-04 (lưu ảnh), D-05 (ngưỡng GPS), D-06 (ân hạn).

## 4. Tổ chức database scripts

`config.sql` (schema) và `seeddata.sql` (dữ liệu nền/demo) là hai script database duy nhất. Chúng dùng để tạo database mới; không chạy lại trên database đang có dữ liệu. Nâng cấp database hiện hữu cần sao lưu và kế hoạch DBA riêng.

## 5. Kiểm chứng

**Đã làm**
- Biên dịch `src/main/java` bằng `javac` (module `jdk.compiler`). Không còn lỗi nội bộ; lỗi còn lại là symbol thư viện Spring/JPA/Jakarta không có trong môi trường.
- Sinh lại entity và repository bằng `tools/gen_entities.py` trên bản sao, đồng bộ về repo. Truy vấn tùy biến nằm trong `tools/repo_extras.py`.
- Phân tích cú pháp T-SQL bằng `sqlglot` cho `config.sql` và `seeddata.sql`. Cảnh báo còn lại thuộc dạng `IF ... THROW/EXEC/PRINT` mà sqlglot không mô hình hóa.

**Chưa làm — bắt buộc trước khi go-live**
- `mvn package` và chạy test. Test trong `src/test` đã cập nhật theo thay đổi nhưng chưa biên dịch.
- Chạy `config.sql` rồi `seeddata.sql` trên SQL Server thật trong database test mới.
- Spring kiểm tra tên phương thức derived và JPQL khi khởi động. javac không kiểm được phần này.
- `config.sql` là nguồn DDL duy nhất; toàn bộ bảng/cột cần thiết đều được định nghĩa trong file này.
- Kiểm thử nghiệp vụ theo luồng: check-in/out với GPS, thiết bị, ảnh, khuôn mặt; duyệt và từ chối giải trình, OT, điều chỉnh; checklist có minh chứng và duyệt; thưởng/phạt và chốt kỳ công.

## 6. Việc leader cần quyết định

1. Chấp nhận các khác biệt ở mục 3 (đặc biệt mục 1, 2, 3, 6).
2. Rà soát chính sách retention và các loại `FailureReason` của `AttendanceVerificationAttempt` khi chốt vận hành.
3. Xác nhận các endpoint ngoài SRS ở mục 3.8 được giữ.
4. Chốt D-03 đến D-06 trước khi bật QR/Wi-Fi dự phòng hoặc đổi ngưỡng.

## 7. Rà soát quy tắc nghiệp vụ (BR) so với code

| BR | Quy tắc | Trạng thái | Ghi chú |
|---|---|---|---|
| BR-GPS-01 | Bán kính 15–50 m | Đạt | Ràng buộc CHECK trên `Store`; mặc định 30 m |
| BR-GPS-02 | Ngưỡng accuracy tối đa | Đạt (chờ chốt giá trị) | `Store.GpsMaxAccuracyMeters`, mặc định 50 m; chốt sau khi test thiết bị thật |
| BR-TIME-01 | Check-in sớm 15–30 phút | Đạt | `WorkShift.EarlyCheckInMinutes` lấy từ cấu hình `Store` khi tạo ca |
| BR-TIME-02 | Ân hạn 3–5 phút | Đạt | CHECK trên `WorkShift` và `Store` |
| BR-TIME-03 | 3–5 lần/tháng, reset theo tháng | Đạt | `AttendanceMetricsService.computeLate` đếm theo tháng của ca; không tính lượt của chính bản ghi đang sửa |
| BR-TIME-04 | Đi muộn tính từ phút đầu sau ân hạn | Đạt | Nếu hết hạn mức, tính muộn từ giờ bắt đầu ca |
| BR-OT-01 | Chỉ tính OT đã duyệt | Đạt | `approvedOTMinutes` tách khỏi thời gian thực tế |
| BR-DEV-01 | Một thiết bị ACTIVE | Đạt | Unique index `UX_AttendanceDevice_OneActive` |
| BR-DEV-02 | Đổi thiết bị: chờ duyệt, khóa thiết bị cũ | Đạt | `DeviceService.approve` khóa thiết bị cũ trong cùng transaction |
| BR-PHOTO-01 | Ảnh bắt buộc | Đạt | `requirePhoto` |
| BR-PHOTO-02 | Chụp ngẫu nhiên | Ngoài phạm vi | Chỉ áp dụng cho nhóm đi thị trường, chưa có trong phạm vi |
| BR-CAM-01 | Không cấp quyền camera: từ chối | **Đạt (lượt này)** | Client gửi `photoEvidence.cameraPermissionGranted=false`, backend trả `CAMERA_PERMISSION_DENIED` |
| BR-CAM-02 | Hỏng camera: QR/Wi-Fi ngoại lệ | **Chưa có** | Phụ thuộc quyết định D-03 (điều kiện kích hoạt, người duyệt, hạn ngoại lệ) |
| BR-RET-01 | Lưu ảnh 6–12 tháng | Đạt | `Store.PhotoRetentionMonths`, tác vụ dọn tệp hết hạn; chốt thời hạn theo pháp lý (D-04) |
| BR-CHK-01 | Template có version | Đạt | Sửa mẫu đã có lượt tạo version mới |
| BR-CHK-02 | Duyệt theo loại task | Đạt | Cờ cấp mẫu và cấp mục (`RequiresManagerApproval`) |
| BR-REM-01 | Nhắc trước 15 phút | Đạt | `ReminderRule.SHIFT_REMINDER` |
| BR-REM-02 | Nhắc sau hạn mỗi 5 phút, tối đa 3 lần, sau đó tạo vi phạm | Đạt | `ReminderRule.CHECKLIST_OVERDUE`; hết lượt thì `ViolationService.recordChecklistMissed` |
| BR-REM-03 | Không gửi trùng | Đạt | `NotificationService.notify` kiểm tra `dedupKey` |

**Hai mục còn mở**: BR-CAM-02 (QR/Wi-Fi dự phòng) và giá trị chốt của BR-GPS-02, BR-RET-01 (theo D-03, D-04, D-05).

Các quy tắc đã đạt vẫn cần kiểm thử thật trên thiết bị và dữ liệu (mục 5).

## 8. Đối chiếu endpoint với mục 9 của SRS

- Mục 9 của SRS liệt kê **131 endpoint** (sau khi loại trùng). Đã kiểm tra từng dòng với các controller trong code: **đủ 131/131**.
- Ngoài SRS, code còn các endpoint sau. Chúng là bổ sung để luồng nghiệp vụ chạy được, không nằm trong SRS:
  - Quản trị người dùng và quyền: `GET/POST /admin/users`, `PATCH /admin/users/{id}/status`, `GET/PUT /admin/users/{id}/roles|permissions`, `GET /admin/users/permission-catalog`.
  - Lưu trữ tệp: `POST /storage/uploads`, `GET /storage/view`. Cần cho ảnh xác minh và tệp giải trình, SRS chỉ nhắc đến khóa lưu trữ.
  - Giải trình và OT: `POST /attendance/explanation-requests`, `GET /attendance/explanation-requests/me`, `GET /attendance/overtime-requests` (và `/me`), `POST /attendance/overtime-requests/{id}/reject`.
  - Hồ sơ: `GET /documents/pending`, `GET /employees/me`, `PUT /admin/document-types/{id}`.
  - Checklist: `POST /checklists/tasks/{taskId}/items/{itemId}/complete`.
  - Kỹ năng và đào tạo: `POST /admin/skills`, `GET /employees/{id}/skills`, `GET /admin/job-positions/{id}/training-requirements`.
- **Đã đưa vào SRS v2.1** (`SRS_HRM_Coffee_Shop_v2_1.docx`): toàn bộ các endpoint trên được ghi vào mục 9 của SRS (9.1, 9.3, 9.4, 9.6, 9.7, 9.8, và mục 9.14 mới cho lưu trữ tệp). Bảng UserPermission, AttendanceExceptionRequest, RuleCatalog, RefreshToken được bổ sung vào 7.3.
