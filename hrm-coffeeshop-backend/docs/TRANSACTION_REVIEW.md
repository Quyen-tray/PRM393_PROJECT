# Rà soát transaction và khóa (Sprint 4)

M��c tiêu: xác định điểm khóa, thứ tự khóa, và chỗ có nguy cơ deadlock hoặc giữ transaction quá lâu.

## Điểm khóa hiện có

| Luồng | Khóa | Phạm vi | Ghi chú |
|---|---|---|---|
| Tạo kỳ công | Dòng `Store` (PESSIMISTIC_WRITE) | Đến hết transaction | Tuần tự hóa việc kiểm tra trùng kỳ (B-14). |
| Chốt / mở lại kỳ, HR chốt | Dòng `PayrollPeriod` (UPDLOCK) | Đến hết transaction | Đọc readiness và ghi LOCKED sau khi có khóa. |
| Mọi thao tác đổi công / ca thuộc ngày trong kỳ | `PayrollLockGuard`: khóa kỳ chứa ngày, rồi đọc trạng thái | Đến hết transaction | Gọi trước khi nạp bản ghi công. |
| Tạo OT | Dòng `ShiftAssignment` (PESSIMISTIC_WRITE) | Đến hết transaction | Tuần tự hóa kiểm tra trùng khoảng OT trên cùng ca (B-02). |
| Tạo / sửa phân ca | Dòng `Employee` (PESSIMISTIC_WRITE) | Đến hết transaction | Tuần tự hóa phân ca cho cùng nhân viên. |
| Check-in | Ràng buộc unique theo ca | Tại thời điểm insert | Request thua nhận `ATTENDANCE_ALREADY_CHECKED_IN` (B-10). |
| Duyệt OT, điều chỉnh, giải trình, thưởng/phạt | RowVersion (khóa lạc quan) | Tại thời điểm commit | Người commit sau nhận 409. |
| Refresh token | Rotation với kiểm tra token đã dùng | Tại thời điểm xử lý | Đã có test (RefreshTokenIT). |
| Dispatch thông báo | `claimForDispatch`: UPDATE có điều kiện trên AttemptCount | Transaction ngắn | Gửi mạng nằm NGOÀI transaction (B-22/23). |
| Ghi lần xác minh thất bại | Transaction riêng (REQUIRES_NEW) | Ngắn | Không bị rollback cùng nghiệp vụ thất bại. |

## Thứ tự khóa (quy tắc đang tuân theo)

1. `Store` (tạo kỳ) → không lồng với khóa khác.
2. `PayrollPeriod` (qua guard) trước, rồi mới `Attendance` / `ShiftAssignment` / `OvertimeRequest`.
3. `Employee` khi phân ca; không khóa `PayrollPeriod` trong khi giữ `Employee`.

Luồng tạo OT khóa `ShiftAssignment` trước khi gọi guard (guard khóa `PayrollPeriod`). Nếu một luồng khác khóa `PayrollPeriod` rồi mới khóa `ShiftAssignment`, có nguy cơ deadlock. Hiện chưa có luồng nào như vậy trong mã, nhưng đây là điểm cần giữ khi thêm chức năng.

## Điểm cần lưu ý (chưa xử lý)

- Hai luồng chốt kỳ và tạo OT cùng lúc có thể chờ nhau trên khóa kỳ. Thời gian chờ mặc định của SQL Server được áp dụng; chưa đặt lock timeout.
- `hrFinalize` đọc readiness (quét nhiều ca) trong transaction giữ khóa kỳ. Với dữ liệu lớn có thể giữ khóa lâu; cần đo khi có dữ liệu thật.
- Job dispatch gọi `repo.findTop100...` ngoài transaction, sau đó mới claim. Đây là chủ đích; instance khác claim thất bại thì bỏ qua.
- Chưa có test tải (load test). Các IT concurrency mới kiểm tra đúng/sai, chưa đo độ trễ khi tranh chấp.
- Chưa có tài liệu deadlock monitoring. Cần bật `SET DEADLOCK_PRIORITY` hoặc extended events khi vận hành.
