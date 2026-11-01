# Kiểm thử tích hợp — các luồng rủi ro cao

## Trạng thái
Các test này được viết theo đúng API và schema của backend, nhưng **chưa được chạy**: môi trường
viết chúng không có Docker, Maven và SQL Server. Cần chạy trên máy có Docker trước khi merge.
Kết quả chạy đầu tiên có thể lộ ra lỗi biên dịch hoặc giả định về dữ liệu seed cần sửa.

## Cách chạy
```
scripts/run-integration-tests.sh
```
Yêu cầu: Docker đang chạy, Maven 3.9+, JDK 17 (the version declared in `pom.xml`). Test tự khởi động `mcr.microsoft.com/mssql/server:2022-latest`,
nạp `config.sql` rồi `seeddata.sql`, và tự đặt JWT/storage secret cho từng lần chạy. Maven Failsafe được cấu hình để thực sự chạy các lớp `*IT` ở phase `integration-test` và kiểm tra kết quả ở phase `verify`.

## Các luồng

Hiện có 17 lớp `*IT`; script chạy toàn bộ bằng Failsafe `-Dit.test='*IT'`. Bảng dưới đây mô tả các nhóm rủi ro chính; xem tên lớp trong `src/test/java/com/hrm/coffeeshop/it` để có danh sách đầy đủ.

| Test | Kiểm tra |
|---|---|
| `PayrollLockIT` | Kỳ đã LOCKED: check-in ca chưa có bản ghi công, check-out, OT, điều chỉnh, giải trình đều bị từ chối. Ca ngoài kỳ vẫn chấm công được (đối chứng). Kiểm tra không tạo bản ghi công khi check-in bị từ chối. |
| `ShiftConcurrencyIT` | Hai quản lý phân cùng ca cho một nhân viên đồng thời: đúng một thành công, thua nhận CONFLICT, DB chỉ có một bản ghi. Đối chứng: ca không trùng vẫn phân được. |
| `OvertimeApprovalConcurrencyIT` | Hai quản lý duyệt cùng OT đồng thời: đúng một quyết định được ghi, người thua nhận INVALID_STATE hoặc CONFLICT, `RowVersion = 1`, người ghi nhận là người thắng. |
| `RefreshTokenIT` | Xoay vòng; tái sử dụng thu hồi mọi phiên và việc thu hồi được COMMIT (regression cho lỗi rollback); race condition chỉ một request thắng; đăng xuất đúng thiết bị; đăng xuất tất cả khi không gửi token; không đăng xuất phiên người khác; token hết hạn không gây tác dụng phụ. |

## Giả định về dữ liệu seed (cần kiểm chứng khi chạy)
- Nhân viên `NV001` (Pha chế) là ACTIVE, có thiết bị ACTIVE và đủ điều kiện đào tạo để phân ca. Nếu không đủ,
  `ShiftService.create` sẽ trả `EMPLOYEE_NOT_ELIGIBLE_FOR_SHIFT` và test sẽ báo rõ lý do.
- Tọa độ cửa hàng `CF-HN01` (21.0278, 105.8342) và bán kính 30 m là các giá trị seed.
- Tài khoản `quanly@hrm.test` tồn tại (seed).

## Thiết kế test
- Đồng hồ `TestClock` được inject làm `Clock` chính; test đặt thời điểm cụ thể (giờ Việt Nam), không phụ thuộc giờ thật.
- Test đăng nhập bằng `SecurityContextHolder` với `AuthUser` đầy đủ quyền (lấy từ `Permissions`); không dùng JWT.
- Mỗi test dùng ngày và mã kỳ riêng (năm 2031–2034) để không va chạm với nhau trong cùng một database.
- Test đồng thời dùng `CyclicBarrier` để hai thread xuất phát cùng lúc. Đây là cách kiểm chứng thực tế nhất,
  nhưng không đảm bảo luôn tái hiện đúng thứ tự xen kẽ; nên chạy lặp lại vài lần khi nghi ngờ.

## Lưu ý
- Các `@Scheduled` job (nhắc việc, gửi thông báo, dọn dẹp) vẫn chạy trong context test. Chúng không được
  thiết kế để can thiệp vào các fixture này, nhưng nếu thấy test flaky hãy tắt job khi chạy test.
- `PayrollLockIT` đôi khi cần đưa bản ghi về trạng thái không nhất quán (`CheckOutAt = NULL`) để kiểm tra nhánh chặn
  của guard, vì luồng bình thường không thể đạt tới trạng thái đó. Đây là mô phỏng có chủ đích, được ghi chú trong test.
