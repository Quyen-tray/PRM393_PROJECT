# Backend handoff — 2026-11-01

## Phạm vi đã hoàn thiện trong source

- Giữ Spring Boot modular monolith, SQL Server, JWT/refresh và các module hiện hữu.
- Các sửa đổi nghiệp vụ/security/concurrency từ Sprint 1–4 theo `NEXT_BACKEND_STEPS.md`.
- Upload hồ sơ PDF/ảnh, upload hộ theo quyền, kiểm tra storage key tồn tại và quyền sở hữu.
- Quy trình ABSENCE có xác nhận quản lý và readiness blocker.
- Notification dispatcher tách claim / push / update; retry tối đa 5 lần.
- Reward/Penalty pagination ở repository và giảm N+1 ở ShiftService.
- Correlation ID cho HTTP: nhận ID an toàn hoặc sinh UUID, trả `X-Correlation-Id`, đưa vào MDC và ghi trong `AuditLog`.
- Admin Audit API và CSV export trả thêm `correlationId`.
- Signed URL local mang actor claim trong HMAC; storage access audit phân biệt `STORAGE_VIEW`, `STORAGE_VIEW_DENIED`, `STORAGE_VIEW_NOT_FOUND` theo kết quả đọc file thật và ghi actor khi claim hợp lệ.
- Bổ sung test source cho upload size, signed URL/audit, notification retry/claim, correlation ID.

## Database

- DDL và dữ liệu nền vẫn lấy từ `config.sql` và `seeddata.sql`.
- Cài mới: thay Gmail admin trong `seeddata.sql` nếu cần, chạy `config.sql` rồi `seeddata.sql`.
- Với database demo cô lập đã có dữ liệu, dùng migration one-off `infra/sqlserver/migrations/2026-11-03-training-quiz-and-nonblocking.sql` để thêm ngân hàng câu hỏi và bỏ đào tạo khỏi điều kiện nhận ca.
- Đây không phải hệ thống migration tổng quát hay quy trình nâng cấp production; không chạy lại `config.sql` hoặc `seeddata.sql` trên database đang có dữ liệu.
- Đổi Gmail admin trên DB hiện hữu được hướng dẫn bằng thao tác DBA one-off trong `docs/GOOGLE_LOGIN.md`, không tạo file SQL mới.

## Chưa thể xác nhận

- Chưa chạy `mvn test`, `mvn verify` hoặc Testcontainers SQL Server: môi trường tạo gói không có Maven và Docker.
- Chưa có query plan/index tuning trên dữ liệu thực.
- `NoopUploadScanner`, `NoopFaceVerificationClient`, `LoggingPushGateway` vẫn là adapter mặc định. LoggingPushGateway hiện không còn báo SENT giả: trả false để dispatcher retry rồi đánh FAILED. Không thể thay bằng ClamAV/face provider/FCM nếu chưa chọn nhà cung cấp, cấu hình và secrets.
- Chính sách payroll cho ABSENCE và giới hạn OT 240 phút vẫn là quyết định tạm/chưa chốt trong `DECISIONS_BASELINE.md`.
- Metrics/alert, backup/restore, production object storage và multi-instance job locking phụ thuộc hạ tầng triển khai.

## Lệnh kiểm thử khi môi trường sẵn sàng

```bash
mvn test
./scripts/run-integration-tests.sh
mvn -B verify
```

`run-integration-tests.sh` chạy toàn bộ 17 lớp `*IT`. Test source không được coi là PASS trước khi các lệnh trên chạy thành công trên môi trường có Docker + SQL Server Testcontainers.
