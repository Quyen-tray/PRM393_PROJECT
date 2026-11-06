# Test thủ công chấm công

Backend giữ cổng `8080`. Chế độ test thủ công đã được bật trong `hrm-coffeeshop-backend/.env`:

```dotenv
ATTENDANCE_FLEXIBLE_TESTING_ENABLED=true
ATTENDANCE_PHOTO_SAMPLE_PERCENT=50
```

Chạy lại backend từ IDE và Stop/Run lại Flutter để nạp cấu hình và giao diện mới. Backend tự nạp `.env` khi thư mục làm việc là gốc dự án hoặc `hrm-coffeeshop-backend`; biến môi trường và tham số IDE được ưu tiên nếu đặt riêng.

1. Quản lý tạo mẫu ca và giao ca cho tài khoản nhân viên cần test. Trong chế độ này, phân ca mới kéo dài từ 00:00 đến 00:00 ngày tiếp theo; cho phép giao các ca trùng giờ và bỏ kiểm tra điều kiện đào tạo, trạng thái làm việc của nhân viên, kỳ công đã chốt khi giao ca. Có thể đặt giờ bắt đầu/kết thúc mẫu ca giống nhau để biểu diễn ca 24 giờ.
2. Nhân viên mở trang chấm công, dùng **Chọn ca làm** nếu có nhiều ca. Mở trang chấm công từ chi tiết lịch làm cũng chọn đúng ca đó. Khung giờ của ca không chặn thao tác trong chế độ test.
3. Check-in và check-out. GPS và bản cài đặt thiết bị đã duyệt vẫn được kiểm tra. Máy chủ chọn yêu cầu ảnh theo tỷ lệ 50% cho từng lượt vào/ra; tải lại màn hình không đổi kết quả lấy mẫu. Ảnh dùng cho check-in không được dùng lại cho check-out. Check-in có trạng thái thiết bị, nút đăng ký trực tiếp và tự cập nhật mỗi 20 giây hoặc khi quay lại app; tải lại điều kiện giữ ảnh của cùng lượt.
4. Mỗi ca được giao chỉ có một lượt check-in/check-out. Để test lại, làm theo [hướng dẫn reset riêng lượt chấm công](RESET_DATABASE.md); có thể giữ ca cũ để check-in lại hoặc hủy ca đó để phân ca mới cùng giờ.
5. Quản lý có thể xem công, biểu đồ hồ sơ/đào tạo/kỹ năng, checklist và thưởng/phạt trên dashboard. Checklist đầu/cuối ca chỉ nhận ảnh chụp trực tiếp, có xem trước ảnh, yêu cầu làm lại và duyệt lại. Nhắc quá hạn có giới hạn số lần và chống gửi trùng.

Để trở lại các kiểm tra nghiệp vụ thông thường, đặt `ATTENDANCE_FLEXIBLE_TESTING_ENABLED=false` rồi khởi động lại backend. Giá trị mặc định trong mã nguồn là `false`.

Kiểm thử tự động bao phủ controller/SQL cho cấu hình Admin, duyệt/từ chối/thay thiết bị, chọn ca, check-in/check-out, gửi lặp, ảnh, GPS, nhắc ca và OT. Đăng nhập Google trực tuyến và tương tác GPS/camera trên thiết bị do người dùng nghiệm thu thủ công. Thông báo trong ứng dụng được lưu và đọc qua API; push ra ngoài ứng dụng chưa có nhà cung cấp được cấu hình.

## Cấu hình và kiểm tra nghiệp vụ

- Admin mở **Cửa hàng và chính sách**, đặt tọa độ đúng vị trí đang test, bán kính 15–50 m, sai số GPS tối đa 5–200 m, ân hạn 3–5 phút và lưu ảnh 6–12 tháng. Mặc định giờ vào sớm/ân hạn áp dụng cho mẫu ca mới; quản lý có thể chỉnh riêng từng mẫu ca. Nhắc việc có cấu hình riêng cho ca và checklist.
- Trên máy ảo, đặt vị trí trong **Extended Controls → Location** trùng tọa độ cửa hàng. Chế độ test cho phép nguồn vị trí máy ảo nhưng vẫn kiểm tra bán kính, sai số và tuổi dữ liệu GPS. Vị trí mặc định của máy ảo có thể ở rất xa quán.
- Khi cài lại ứng dụng, đăng ký lại máy đang dùng nếu credential đã đổi. Yêu cầu PENDING cũ được thay thế; thiết bị ACTIVE cũ chỉ bị khóa sau khi người có quyền duyệt máy mới. Mỗi nhân viên vẫn chỉ có một thiết bị ACTIVE.
- Bản ghi công hiển thị riêng thời gian hiện diện, công trong ca, thời gian ngoài ca và OT đã duyệt. Check-out muộn không tự biến thành OT được duyệt.
- Ở chế độ thông thường, `ATTENDANCE_BLOCK_MOCK_LOCATIONS=true` chặn GPS bị nền tảng đánh dấu là giả lập. Tín hiệu này hỗ trợ phát hiện giả lập; không thay thế chứng thực thiết bị ở phía nhà cung cấp.
- `ATTENDANCE_FACE_VERIFICATION_REQUIRED=false` là mặc định vì chưa tích hợp nhà cung cấp face/liveness thật. Lịch sử ghi `EXEMPTED` khi chưa chạy. Nếu bật `true`, mọi lượt đều cần ảnh và kết quả face/liveness đạt; thiếu kết quả sẽ bị chặn, không báo nhận diện thành công giả.
