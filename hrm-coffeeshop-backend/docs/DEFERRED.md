# Các hạng mục chưa làm và lý do

| Hạng mục | Sprint | Lý do chưa làm | Điều kiện để làm |
|---|---|---|---|
| Query plan và index | 4 | Cần SQL Server có dữ liệu thật để đọc execution plan. Không đoán index. | Chạy các truy vấn trên DB có dữ liệu và chụp plan. |
| Flutter: F-02 đến F-20 | 5 | Cần build Flutter (SDK không có trong môi trường). Phần lớn là công việc UI và dữ liệu, cần kiểm thử trên thiết bị. | Môi trường Flutter và backend đang chạy. Đã làm F-01. |
| OpenAPI 3.1 | 6 | Cần đối chiếu từng controller và DTO; nên sinh từ code khi backend đã chạy được. | Backend chạy được (Swagger UI đã có). |
| SRS docx (cập nhật endpoint, quy tắc) | 6 | Sửa file docx, cần duyệt nghiệp vụ. | Chốt nội dung với chủ dự án. |
| Metrics, alert và dashboard vận hành | 6 | Correlation ID đã có ở HTTP/audit; metrics và alert phụ thuộc hạ tầng triển khai. | Chọn nền tảng log/metrics và ngưỡng cảnh báo. |
| Backup và restore | 6 | Phụ thuộc hạ tầng và chính sách lưu trữ. | Có môi trường và chính sách. |
| Object storage (S3/Azure/GCS) | 6 | Phụ thuộc nhà cung cấp. Interface `StorageGateway` đã sẵn. | Chọn nhà cung cấp. |
| Quét mã độc cho upload | 3 | `UploadScanner` đã có, mặc định no-op. | Chọn bộ quét (ví dụ ClamAV); phải thay trước production. |
| Nhận diện khuôn mặt thật | 3/6 | `NoopFaceVerificationClient` là placeholder. | Chọn nhà cung cấp và hợp đồng dữ liệu. |
| Push FCM thật | 3/6 | `LoggingPushGateway` là placeholder; hiện chỉ log và trả thất bại để không đánh dấu SENT giả. | Cấu hình Firebase. |
| Redis rate limit, ShedLock | 6 | Chỉ cần khi nhiều instance. | Triển khai nhiều instance. |
| Phân quyền tải ảnh khác quyền xem ảnh | 3 | Chưa được yêu cầu trong roadmap; cần chủ dự án xác nhận chính sách xem/tải riêng biệt. | Chủ dự án xác nhận quy tắc. |
| Lương cho vắng mặt đã duyệt | 3 | Quyết định nghiệp vụ còn mở (DEC-ABS). | Chốt chính sách lương. |
| Giới hạn thời lượng OT | 1 | Đang tạm 240 phút (DEC-OT). | Chủ dự án xác nhận. |
| Tạo đơn ABSENCE tự động | 3 | Quyết định ghi "hệ thống xác định", nhưng tạo bản ghi khi đọc readiness là tác dụng phụ không nên có. Hiện là thao tác của quản lý. | Chốt cơ chế (job theo lịch hoặc thao tác khi chốt). |
| Test TC34 (single-flight refresh) | 5 | Thuộc Flutter. | Làm cùng F-06. |
| Kiểm chứng transaction boundary của notification | 3 | Push exception/retry đã có unit test; cần kiểm chứng ở mức transaction manager khi gửi mạng. | Bổ sung trước release. |
| Test 403 cho từng endpoint đặc thù và load test | 2/4 | Mở rộng bộ test, không chặn tính năng. | Sau khi bộ test hiện có chạy được; xem `docs/TEST_COVERAGE_STATUS.md`. |


## Kiểm chứng test hiện tại

Các test TC28, TC29 và TC33 đã có trong `HrUploadAndAccessIT` và `UnauthenticatedAccessIT`; trạng thái là đã viết nhưng chưa chạy. Xem `docs/TEST_COVERAGE_STATUS.md` để tránh dùng bảng coverage cũ.
