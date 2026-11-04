# HRM Coffee Shop

Flutter + Spring Boot + SQL Server, dành cho một cửa hàng. Ba workspace chính là `EMPLOYEE`, `STORE_MANAGER`, `SYSTEM_ADMIN`; các tác vụ nhân sự được cấp bằng permission. Backend quyết định quyền và trạng thái nghiệp vụ.

Đọc [kết quả triển khai](docs/specification/v3.0/IMPLEMENTATION_LOG.md), [ma trận flow đang chạy](docs/specification/v3.0/IMPLEMENTED_FLOW_MATRIX.md) và [bằng chứng kiểm thử](docs/specification/v3.0/VERIFICATION.md). Các báo cáo Phase 0 được giữ làm lịch sử đánh giá.

## Chạy với database của cửa hàng

1. Cấu hình `hrm-coffeeshop-backend/.env` trên máy, không đưa mật khẩu/token vào tài liệu. Dùng SQL Server đang có; không cần Docker.
2. Với schema cũ, chạy migration bổ sung `hrm-coffeeshop-backend/src/main/resources/db/migration/v3.sql` trên đúng database. Khi dùng SSMS, thay dòng phân cách `@@` bằng `GO`. Migration giữ dữ liệu hiện có. `infra/sqlserver/config.sql` chỉ dành cho database mới, không chạy để cập nhật database đang dùng.
3. Tạo `env.json` theo `env.example.json`; điền Google OAuth server client ID. `API_BASE_URL` là origin backend, không kèm `/api/v1`.
4. Cài dependencies bằng `flutter pub get`. Nếu chỉ chạy Android/web trên Windows chưa bật Developer Mode: đặt `$env:FLUTTER_WINDOWS='false'` trong terminal hiện tại trước lệnh này. Chạy native Windows với plugin vẫn cần Developer Mode.
5. Mở hai terminal tại workspace:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tooling/Start-HrmBackend.ps1 -ApplyMigration
powershell -NoProfile -ExecutionPolicy Bypass -File tooling/Start-HrmFrontend.ps1 -Target android
```

`-ApplyMigration` áp dụng migration bổ sung khi khởi động; bỏ cờ này sau khi schema đã cập nhật. Chọn `-Target web` để chạy ở `http://127.0.0.1:5000`. Backend mặc định cổng `8081`. Android emulator dùng `10.0.2.2:8081`. Điện thoại thật cần URL máy chủ mà điện thoại truy cập được và cấu hình listen/network tương ứng.

Đăng nhập bằng Google thật trong `lib/main.dart`. Tài khoản phải tồn tại và đang hoạt động trên backend; ứng dụng không có đăng ký hoặc đăng nhập mật khẩu giả. Xem cấu hình OAuth trong [GOOGLE_LOGIN.md](hrm-coffeeshop-backend/docs/GOOGLE_LOGIN.md).

## Kiểm thử độc lập với dữ liệu cửa hàng

```powershell
flutter analyze
flutter test --no-pub
powershell -NoProfile -ExecutionPolicy Bypass -File tooling/Test-HrmBackend.ps1 -Integration
powershell -NoProfile -ExecutionPolicy Bypass -File tooling/Start-HrmBackend.ps1 -TestDatabase -ApplyMigration
powershell -NoProfile -ExecutionPolicy Bypass -File tooling/Start-HrmFrontend.ps1 -Target android -TestSession
```

Lệnh integration tạo database SQL Server riêng tên `HRM_CoffeeShop_V3_Test_<timestamp>`, không DROP/reset database cửa hàng. Dừng backend kiểm thử cũ trước khi khởi động server trỏ sang database mới. Dùng `-PreserveLiveSession` khi chạy regression mà muốn giữ phiên app đang kiểm thử.

`-TestSession` sử dụng entry point debug riêng `integration_test/live_app.dart`, có thanh đổi actor. Nó dùng JWT kiểm thử, quyền được nạp từ SQL Server; mọi dữ liệu và thao tác nghiệp vụ đều qua backend thật. Đây không phải bằng chứng kiểm thử đăng nhập Google. Cấu hình/phiên kiểm thử riêng tư nằm trong `.dart_tool/`, không đưa vào bản phát hành.

Các khóa seed chưa có câu hỏi cần được biên soạn trước khi làm quiz. Với app web acceptance đang mở trong Chrome CDP `9222`, có thể chạy `node tooling/Prepare-LiveTraining.cjs` để nhập câu hỏi mẫu qua màn Admin cho bốn khóa test; script không ghi vào database cửa hàng và giữ nguyên bank đã có. Giáo trình vận hành thật do Admin biên soạn/duyệt theo nội dung của cửa hàng.

## Kiến trúc runtime

- `core/network`, `core/storage`: JWT/refresh, error envelope, secure storage, installation credential, upload bytes.
- `features/auth`: profile, permissions, workspace và phiên Google.
- `app/router`: route guard theo phiên hiện tại, deep link, back stack và route alias.
- `features/workspace`: shell mobile/desktop, dashboard và hàng đợi tác vụ theo quyền.
- `features/operations`: registry chức năng/contract, repository, state, danh sách, detail, form và lookup phân trang.
- `features/attendance`: GPS, camera, upload ảnh và check-in/out có idempotency.
- `hrm-coffeeshop-backend`: Controller/DTO/Service/JPA, permission, audit, storage ký URL, SQL và tests.

Các màn scaffold cũ trong `lib/features/` và `lib/data/mock/` không được router runtime gọi. Có thể kiểm tra import graph bằng `node tooling/Audit-RuntimeImports.cjs`.

## Phạm vi đã kiểm tra

Android emulator và Flutter web đã chạy với backend/SQL Server thật. Xem [VERIFICATION.md](docs/specification/v3.0/VERIFICATION.md) để phân biệt thao tác app, integration test và phần chưa nghiệm thu trên thiết bị thật. Phạm vi payroll hiện tại là kỳ công/đối soát/khóa công; chưa có công thức lương tiền, phiếu lương hoặc chuyển khoản.
