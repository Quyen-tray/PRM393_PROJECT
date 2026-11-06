# Reset một lượt chấm công để test lại

Thao tác này chỉ reset bản chấm công được chọn, giữ nguyên database `HRM_CoffeeShop`, tài khoản, thiết bị đã duyệt, GPS, mẫu ca và dữ liệu của các ca khác.

## 1. Tìm bản chấm công vừa test

Dừng backend trong IDE. Mở SSMS, chọn `HRM_CoffeeShop` và chạy:

```sql
SELECT TOP (20)
    a.AttendanceId, e.EmployeeCode, u.DisplayName,
    s.ShiftAssignmentId, s.WorkDate, s.ScheduleStatus,
    DATEADD(HOUR, 7, a.CheckInAt) AS CheckInVN,
    DATEADD(HOUR, 7, a.CheckOutAt) AS CheckOutVN
FROM dbo.Attendance a
JOIN dbo.Employee e ON e.EmployeeId = a.EmployeeId
JOIN dbo.AppUser u ON u.UserId = e.UserId
JOIN dbo.ShiftAssignment s ON s.ShiftAssignmentId = a.ShiftAssignmentId
WHERE a.CheckInAt IS NOT NULL
ORDER BY a.CheckInAt DESC, a.AttendanceId DESC;
```

Lấy `AttendanceId` và `EmployeeCode` đúng dòng bạn vừa chấm công.

## 2. Reset đúng dòng đó

Mở [reset-attendance.sql](../hrm-coffeeshop-backend/infra/sqlserver/reset-attendance.sql), thay ba dòng khai báo đầu phần biến bằng giá trị của bạn, ví dụ:

```sql
DECLARE @AttendanceId BIGINT = 123;
DECLARE @EmployeeCode VARCHAR(30) = 'NV001';
DECLARE @CancelAssignment BIT = 1;
```

Chạy toàn bộ file trong SSMS. Script xóa bản công, kết quả xác minh và vi phạm đi muộn tự động còn chờ xử lý của đúng lượt đó; giữ nhật ký audit.

- `@CancelAssignment = 1` (mặc định): đồng thời chuyển phân ca tương ứng sang `CANCELLED`. Quản lý có thể giao ca mới cùng giờ; phân ca cũ vẫn còn trong lịch sử.
- `@CancelAssignment = 0`: giữ phân ca cũ để check-in lại ngay trên chính ca đó.

Xóa bản công đơn thuần không giải phóng lịch phân ca. Nếu còn phân ca khác đang hoạt động trùng giờ, xử lý ca đó trong màn hình lịch phân ca.

Script dừng nếu công đã vào đối soát, có OT/đơn điều chỉnh/giải trình hoặc vi phạm đã được xử lý, để giữ nguyên các nghiệp vụ đó. Khi hủy ca, checklist đang thực hiện hoặc chờ duyệt cũng được giữ lại; có thể chọn `0` để tiếp tục dùng ca cũ. File ảnh đã upload vẫn nằm trong storage.

## 3. Test lại

Khởi động backend ở cổng **8080**, mở lại Flutter hoặc kéo tải lại trang chấm công. Tài khoản và thiết bị vẫn giữ nguyên, không cần xóa dữ liệu ứng dụng hay đăng ký thiết bị lại. Nếu đã chọn `1`, quản lý giao ca mới trước khi nhân viên chấm công.

## Tạo database mới

`config.sql` hiện đã chứa toàn bộ schema V3. Khi cài database mới, chạy `config.sql` rồi `seeddata.sql` là đủ; không cần migration riêng. `v3.sql` được giữ để nâng cấp các database cũ mà vẫn giữ dữ liệu. Reset một lượt chấm công chỉ cần file `reset-attendance.sql` ở bước 2.
