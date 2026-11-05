# Truy vết test cho Sprint 1 (TC21–TC36)

Trạng thái: **đã viết, chưa chạy**. Cần Docker (Testcontainers SQL Server) và Maven để chạy `scripts/run-integration-tests.sh`.

| TC | Nội dung | Test | Trạng thái |
|---|---|---|---|
| TC21 | Hai check-in đồng thời cùng ca | `CheckInRaceIT` | Đã viết |
| TC22 | Hai OT chồng lấn đồng thời | `OvertimeRulesIT` | Đã viết |
| TC23 | OT giao ca / khoảng không hợp lệ | `OvertimeRulesIT`, `OvertimeIntervalTest` (unit) | Đã viết |
| TC24 | Ca kết thúc không chấm công chặn chốt đến khi có ABSENCE đã duyệt | `AbsenceWorkflowIT` | Đã viết |
| TC25 | Sửa / hủy / tạo / chuyển ca vào kỳ đã khóa bị từ chối | `ScheduleLockIT`, `PayrollLockIT` | Đã viết |
| TC26 | Evidence của nhân viên khác | `ChecklistEvidenceKeysTest` (unit), `EvidenceKeysTest` | Đã viết (unit) |
| TC27 | Nộp hồ sơ với khóa không tồn tại | `DocumentSubmitIT` | Đã viết |
| TC28 | HR upload hồ sơ thay nhân viên | — | **Chưa làm** (B-19, Sprint 3) |
| TC29 | Nhân viên xem hồ sơ của người khác → 403 | — | **Chưa viết** |
| TC30 | Hai kỳ công trùng ngày đồng thời | `PayrollPeriodCreateConcurrencyIT` | Đã viết |
| TC31 | Upload vượt dung lượng | `FileSignatureTest`, `UploadSizeLimitIT` | Đã viết, chưa chạy |
| TC32 | Không có token → 401 | `UnauthenticatedAccessIT` | Đã viết |
| TC33 | Có token nhưng thiếu quyền → 403 | — | **Chưa viết** (cần tạo token cho tài khoản thiếu quyền) |
| TC34 | Nhiều 401 đồng thời chỉ refresh một lần | — | Thuộc Flutter (F-06) |
| TC35 | Checklist evidence sai employeeId | `ChecklistEvidenceKeysTest` | Đã viết (unit) |
| TC36 | Khóa / gỡ System Admin cuối cùng | `LastAdminGuardIT` | Đã viết |

## Ghi chú về các test đã viết

- `AbsenceWorkflowIT` là kịch bản tuần tự một method để không phụ thuộc thứ tự chạy.
- `LastAdminGuardIT` và `DocumentSubmitIT` có thao tác ghi DB; `LastAdminGuardIT` khôi phục trạng thái admin trong `finally`.
- `PayrollLockIT` đã được sửa: trước đây `hrFinalize` không cần đơn vắng mặt, nay ca D2 phải có ABSENCE đã duyệt.
- Các test dùng ngày cố định (2031–2034) để tránh chồng lấn. Nếu DB dùng chung giữa các class, cần kiểm tra lại.
- Có thể có lỗi do giả định về dữ liệu seed (ví dụ NV001 đủ điều kiện ca, thiết bị ACTIVE). Lần chạy đầu cần đọc kỹ thông báo lỗi.
