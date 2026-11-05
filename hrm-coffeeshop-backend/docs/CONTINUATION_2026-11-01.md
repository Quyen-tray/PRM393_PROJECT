# Backend continuation — 2026-11-01

- Đồng bộ lại trạng thái TC28, TC29, TC33 theo test class thực tế:
  `HrUploadAndAccessIT` và `UnauthenticatedAccessIT`.
- Bổ sung `docs/TEST_COVERAGE_STATUS.md` làm ma trận test hiện hành.
- Bổ sung `docs/NEXT_BACKEND_STEPS.md` ghi rõ thứ tự công việc và giới hạn kiểm chứng.
- Sửa `scripts/run-integration-tests.sh`: trước đây chỉ chọn 5 lớp IT cũ; hiện dùng `-Dit.test='*IT'` để chạy toàn bộ 17 lớp integration test.
- Không thay đổi business logic/API/DB schema trong lượt này vì môi trường không có Maven và Docker để xác nhận compile + SQL Server integration. Không tuyên bố test pass.


## Tiếp tục backend — audit và release readiness

- Thêm `CorrelationIdFilter`: nhận `X-Correlation-Id` an toàn hoặc sinh UUID, phản hồi lại header và đưa ID vào MDC trong vòng đời request.
- Lưu `CorrelationId` trong `AuditLog`; mở rộng Admin Audit response và CSV export. Cột được định nghĩa trong `config.sql` cho database dựng mới. Database cũ cần giữ dữ liệu không được chạy lại hai file cài đặt; hiện không cung cấp script nâng cấp.
- Signed URL local ký cả actor ID; sửa `/storage/view`: chỉ ghi `STORAGE_VIEW` khi file thực sự được đọc; URL hợp lệ nhưng file mất ghi `STORAGE_VIEW_NOT_FOUND`; chữ ký sai/hết hạn ghi `STORAGE_VIEW_DENIED`. Audit actual access có actor claim khi chữ ký hợp lệ.
- Bổ sung unit/integration tests: correlation ID, HTTP upload-size, signed-file audit và notification dispatcher claim/retry. Test đã viết, chưa chạy do thiếu Maven/Docker trong môi trường tạo gói.


## Quy ước database được chuẩn hóa

- Repository chỉ duy trì đúng hai file SQL: `config.sql` (DDL/schema) và `seeddata.sql` (roles, permissions, danh mục, admin bootstrap, demo/test data).
- Không có migration, không có `set_admin_google.sql` hoặc script SQL phụ.
- Thay đổi schema trong giai đoạn phát triển phải cập nhật `config.sql`; thay đổi seed phải cập nhật `seeddata.sql`. Kiểm chứng bằng database test mới tạo từ đầu.
- Tài liệu Google Login hướng dẫn đổi Gmail admin trên DB hiện hữu bằng câu lệnh DBA one-off trong SSMS; câu lệnh chỉ là nội dung tài liệu, không phải file SQL thứ ba.
