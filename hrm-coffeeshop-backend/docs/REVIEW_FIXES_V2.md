# Backend Review Fixes v2 — Đợt 1

Phạm vi: các mục P0 và bảo mật bắt buộc trước khi tích hợp Flutter. Flutter, Đợt 2 và Đợt 3 chưa làm.

## 1. Thay đổi hành vi (cần biết trước khi tích hợp Flutter)

| Khu vực | Trước | Sau |
|---|---|---|
| Endpoint không khai báo public | `anyRequest().permitAll()` (fail-open) | `anyRequest().authenticated()` (fail-closed) |
| Chưa có token / token sai | Controller tự xử lý, thường thành lỗi khác | **401** `UNAUTHENTICATED` (entry point mới) |
| Thiếu quyền | 403 `PERMISSION_DENIED` | Không đổi |
| OT | Chỉ chặn khoảng nằm hoàn toàn trong ca | **OT chỉ hợp lệ khi bắt đầu sau giờ kết thúc ca** |
| Readiness chốt công | Ca đã kết thúc không có chấm công chỉ được đếm | Chặn bằng blocker `MISSING_ABSENCE_REQUEST`, `PENDING_ABSENCE`, `REJECTED_ABSENCE` (xem DECISIONS_BASELINE.md) |
| Sửa / hủy / phân ca trong kỳ đã chốt | Được phép (chỉ check-in/OT/giải trình bị chặn) | **409 `PAYROLL_PERIOD_LOCKED`** |
| Check-in trùng đồng thời | Lỗi DB chung 409 | **409 `ATTENDANCE_ALREADY_CHECKED_IN`** cho request thua |
| Checklist evidence | Chỉ kiểm tra tiền tố | Phải đúng `checklist-evidence/{employeeId của mình}/{uuid}.ext` và file phải tồn tại |
| Nộp hồ sơ / giải trình / điều chỉnh có ảnh | Không kiểm tra file tồn tại | **422/400** nếu file chưa upload hoặc đã mất |
| Vô hiệu hóa / gỡ quyền System Admin cuối | Cho phép | **422** `BUSINESS_RULE_VIOLATION` |

## 2. API mới (đã thay bằng quy trình ABSENCE — xem DECISIONS_BASELINE.md)

`POST /api/v1/payroll-periods/{periodId}/absence-requests` (STORE_MANAGER): tạo đơn `ABSENCE` ở trạng thái PENDING cho mỗi ca đã kết thúc không có chấm công. Idempotent.

Duyệt đơn vắng mặt dùng endpoint giải trình sẵn có: `POST /attendance/explanation-requests/{id}/approve` hoặc `/reject`. Đơn ABSENCE khi duyệt không ghi bản ghi công.

Blocker trong readiness (`ids` là ShiftAssignmentId): `MISSING_ABSENCE_REQUEST`, `PENDING_ABSENCE`, `REJECTED_ABSENCE`.

## 3. Database

- `config.sql`: CHECK `CK_Exception_Type` cho phép `ABSENCE`; thay đổi áp dụng khi dựng database mới từ đầu.
- Không có script nâng cấp cho database đã tồn tại; không chạy lại `config.sql` trên database có dữ liệu.
- Không có bảng mới. Không đổi cột nào khác.

## 4. Chống trùng đồng thời

- OT: `ShiftAssignmentRepository.findByIdForUpdate` (PESSIMISTIC_WRITE) được gọi trước khi kiểm tra trùng khoảng, nên hai yêu cầu OT cùng ca phải xếp hàng.
- Check-in: `saveAndFlush` để vi phạm unique theo ca lộ ra ngay, rồi ánh xạ sang `ATTENDANCE_ALREADY_CHECKED_IN`. Retry tuần tự với cùng `idempotencyKey` vẫn nhận lại kết quả cũ (nhánh idempotent đầu hàm).

## 5. Tệp đã sửa

Main: `SecurityConfig`, `OvertimeService`, `ShiftService`, `PayrollService`, `AttendanceExceptionService`, `AttendanceAdjustmentService`, `AttendanceService`, `ChecklistService`, `DocumentService`, `UserService`, `EvidenceKeys`, `ShiftAssignmentRepository`, `AttendanceExceptionRequestRepository`, `ManagerAttendanceController`.
Test mới: `ChecklistEvidenceKeysTest` (TC35).
SQL: `config.sql` (nguồn schema duy nhất); `seeddata.sql` chỉ chứa dữ liệu khởi tạo/demo.

## 6. Trạng thái xác minh

- Đã kiểm tra cú pháp các file Java đã sửa bằng `javac` (không có lỗi parse, số ngoặc cân bằng).
- **Chưa biên dịch đầy đủ và chưa chạy test.** Môi trường không có Maven và không tải được dependency Spring. Cần chạy `mvn test` và `scripts/run-integration-tests.sh` trên SQL Server thật.
- Cần bổ sung test tích hợp chưa viết (theo danh sách TC trong báo cáo rà soát): TC21 (check-in đồng thời), TC22 (OT đồng thời), TC23 (OT bắt đầu trước khi ca kết thúc → 422), TC24 (vắng mặt chưa xác nhận chặn chốt), TC25 (sửa lịch trong kỳ khóa → 409), TC26/TC35 (evidence người khác → 403), TC27 (storage key không tồn tại), TC32/TC33 (401/403), TC36 (admin cuối cùng).

## 7. Chưa làm (Đợt 2, 3)

Upload hồ sơ thay nhân viên; hỗ trợ PDF; ghi audit từng lần truy cập file (`/storage/view`); lưu xác minh GPS/face thất bại; database pagination cho `RewardPenaltyService`; N+1 trong `ShiftService.toView`; index theo execution plan; `NotificationDispatcherJob` gửi ngoài transaction; đồng bộ README/SRS/database scripts; toàn bộ Flutter.

Ghi chú SRS cần cập nhật: endpoint tạo đơn ABSENCE, các blocker vắng mặt, quy tắc OT và PDF. Xem DECISIONS_BASELINE.md.
