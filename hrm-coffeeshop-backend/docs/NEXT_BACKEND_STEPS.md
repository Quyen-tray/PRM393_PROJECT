# Backend — trạng thái và bước tiếp theo

Ngày đối chiếu: 2026-11-01 (tiếp tục cập nhật)

## Đã có trong source v4

- Sprint 1: OT interval/concurrency, payroll readiness với ABSENCE, fail-closed security + 401/403, file ownership/existence, payroll lock cho schedule, duplicate check-in, last-admin guard.
- Sprint 2: concurrency tạo payroll period, break duration, integration tests cho các luồng concurrency chính.
- Sprint 3: failed verification persistence + retention, HR upload on behalf, PDF theo DEC-PDF, storage view audit, notification dispatcher gửi ngoài transaction, notification claim/idempotency.
- Sprint 4: SQL pagination cho Reward/Penalty, giảm N+1 ở ShiftService, transaction review.
- Bổ sung Release Readiness nền tảng: correlation ID cho mọi HTTP request, trả `X-Correlation-Id`, lưu correlation ID vào AuditLog và hiển thị trong Admin Audit API/export; sửa audit storage để chỉ ghi `STORAGE_VIEW` khi file đọc thực sự thành công.
- Bổ sung test cho HTTP upload-size, signed-file audit outcomes, notification claim/retry và correlation ID.

Chi tiết test truy vết: `docs/TEST_COVERAGE_STATUS.md`.
Chi tiết việc còn hoãn: `docs/DEFERRED.md`, `docs/DECISIONS_BASELINE.md`, `docs/TRANSACTION_REVIEW.md`.

## Việc backend cần làm tiếp theo (theo thứ tự)

1. Hoàn tất các hạng mục backend có thể triển khai độc lập với nhà cung cấp/hạ tầng; không chuyển sang Flutter ở giai đoạn này.
2. Hoàn tất kiểm chứng transaction boundary của notification ở mức integration; push exception/retry và signed URL hết hạn/path traversal đã có test source.
3. Chốt quyết định nghiệp vụ còn mở: OT tối đa hiện tạm 240 phút; chính sách lương ABSENCE; cơ chế tạo đơn ABSENCE.
4. Khi backend code và tài liệu đã hoàn tất, chạy nghiệm thu: `mvn test`, `scripts/run-integration-tests.sh` (17 lớp `*IT`), cuối cùng `mvn -B verify`; sửa mọi lỗi phát hiện trước khi bàn giao.
5. Chạy query plan trên SQL Server có dữ liệu thật rồi mới quyết định index.
6. Trước production: thay `NoopUploadScanner`, `NoopFaceVerificationClient`, `LoggingPushGateway`; cấu hình secret và private storage; diễn tập backup/restore.

## Giới hạn kiểm chứng của gói bàn giao này

Trong môi trường tạo gói hiện tại không có lệnh `mvn` và `docker`. Vì vậy không thể tuyên bố backend compile hoặc test pass. Source được giữ nguyên theo backend v4; tài liệu test coverage được đồng bộ lại với test class thực tế để tránh ghi nhầm TC28/TC29/TC33 là chưa có.
