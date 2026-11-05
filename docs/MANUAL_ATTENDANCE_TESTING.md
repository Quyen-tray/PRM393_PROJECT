# Test thủ công chấm công

Backend giữ cổng `8080`. Chế độ test thủ công đã được bật trong `hrm-coffeeshop-backend/.env`:

```dotenv
ATTENDANCE_FLEXIBLE_TESTING_ENABLED=true
ATTENDANCE_PHOTO_SAMPLE_PERCENT=50
```

Chạy lại backend từ IDE và Stop/Run lại Flutter để nạp cấu hình và giao diện mới.

1. Quản lý tạo mẫu ca và giao ca cho tài khoản nhân viên cần test. Trong chế độ này, phân ca mới kéo dài từ 00:00 đến 00:00 ngày tiếp theo; cho phép giao các ca trùng giờ và bỏ kiểm tra điều kiện đào tạo, trạng thái làm việc của nhân viên, kỳ công đã chốt khi giao ca. Có thể đặt giờ bắt đầu/kết thúc mẫu ca giống nhau để biểu diễn ca 24 giờ.
2. Nhân viên mở trang chấm công, dùng **Chọn ca để chấm công** để chọn ca muốn thử. Mở trang chấm công từ chi tiết lịch làm cũng chọn đúng ca đó. Khung giờ của ca không chặn thao tác trong chế độ test.
3. Check-in và check-out. GPS và bản cài đặt thiết bị đã duyệt vẫn được kiểm tra. Máy chủ chọn yêu cầu ảnh theo tỷ lệ 50% cho từng lượt vào/ra; tải lại màn hình không đổi kết quả lấy mẫu.
4. Sau check-out, bấm **Chấm công lượt mới** để tiếp tục ngay trên cùng tài khoản. Lượt mới dùng cùng mẫu ca và ngày hiện tại, có bản ghi phân ca/chấm công riêng; lịch sử lượt trước được giữ lại.
5. Quản lý có thể xem công, biểu đồ hồ sơ/đào tạo/kỹ năng, checklist và thưởng/phạt trên dashboard. Checklist đầu/cuối ca hỗ trợ chụp/chọn ảnh, xem trước ảnh, yêu cầu làm lại và duyệt lại. Nhắc quá hạn có giới hạn số lần và chống gửi trùng.

Để trở lại các kiểm tra nghiệp vụ thông thường, đặt `ATTENDANCE_FLEXIBLE_TESTING_ENABLED=false` rồi khởi động lại backend. Giá trị mặc định trong mã nguồn là `false`.

Các kiểm thử tự động trước khi bật chế độ thủ công đã đạt: 55 unit backend, 64 integration SQL Server và 39 kiểm thử Flutter. Phần thay đổi chế độ thủ công được kiểm tra biên dịch/phân tích mã; kiểm thử tương tác trên máy ảo dừng theo yêu cầu để người dùng tự chạy. Push ra ngoài ứng dụng hiện chưa có nhà cung cấp được cấu hình; thông báo trong ứng dụng được lưu và đọc qua API.
