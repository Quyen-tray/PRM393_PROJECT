# HRM Coffee Shop

Flutter + Spring Boot + SQL Server, dành cho một cửa hàng. Ba workspace chính là `EMPLOYEE`, `STORE_MANAGER`, `SYSTEM_ADMIN`; các tác vụ nhân sự được cấp bằng permission. Backend quyết định quyền và trạng thái nghiệp vụ.

Mới clone dự án hoặc vừa pull code? Bắt đầu với [hướng dẫn cài đặt, cập nhật và chạy dự án](docs/GETTING_STARTED.md).

Xem [hướng dẫn Word: chạy và sử dụng ứng dụng](HUONG_DAN_SU_DUNG.docx) để cấu hình SQL Server, chạy Android/web, dùng ba vai trò và thử GPS, duyệt thiết bị, check-in/out.

Đọc [kết quả triển khai](docs/specification/v3.0/IMPLEMENTATION_LOG.md), [ma trận flow đang chạy](docs/specification/v3.0/IMPLEMENTED_FLOW_MATRIX.md) và [bằng chứng kiểm thử](docs/specification/v3.0/VERIFICATION.md). Các báo cáo Phase 0 được giữ làm lịch sử đánh giá.

## Chạy với database của cửa hàng

1. Cấu hình `hrm-coffeeshop-backend/.env` trên máy, không đưa mật khẩu/token vào Git. Dùng SQL Server đang có; không cần Docker. Xem [hướng dẫn bắt đầu](docs/GETTING_STARTED.md) để biết các biến cần đặt.
2. Với database mới, chạy `hrm-coffeeshop-backend/infra/sqlserver/config.sql` rồi `seeddata.sql`. Với database hiện có, không chạy lại hai file này; nếu cần nâng schema v3, khởi động backend với `-ApplyMigration` một lần để áp dụng migration bổ sung.
3. Đảm bảo `env.json` có Google OAuth server client ID theo `env.example.json`. Script frontend tự tạo API URL phù hợp cho Android emulator hoặc web.
4. Cài dependencies bằng `flutter pub get`. Nếu chỉ chạy Android/web trên Windows chưa bật Developer Mode: đặt `$env:FLUTTER_WINDOWS='false'` trong terminal hiện tại trước lệnh này. Chạy native Windows với plugin vẫn cần Developer Mode.
5. Mở hai terminal tại workspace:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tooling/Start-HrmBackend.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tooling/Start-HrmFrontend.ps1 -Target android
```

Chỉ thêm `-ApplyMigration` khi database hiện có cần migration v3; chạy một lần rồi bỏ cờ ở các lần sau. Chọn `-Target web` để chạy ở `http://127.0.0.1:5000`. Backend mặc định cổng `8081`. Android emulator dùng `10.0.2.2:8081`. Điện thoại thật cần URL máy chủ mà điện thoại truy cập được và cấu hình listen/network tương ứng.

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

## Tổ chức file theo feature V3

Source được phân theo nghiệp vụ trong tài liệu V3. `EMPLOYEE`, `STORE_MANAGER`, `SYSTEM_ADMIN` chọn workspace; các chức năng quản trị nằm trong feature sở hữu nghiệp vụ đó.

| Thư mục trong `lib/features/` | Trách nhiệm |
|---|---|
| `auth` | Google OAuth, phiên đăng nhập, current user và trạng thái phiên |
| `workspace` | Chọn workspace, app shell, menu, ghép màn danh sách/chi tiết theo module |
| `dashboard` | Dashboard và truy cập nhanh theo workspace |
| `accounts` | Tài khoản, vai trò, permission và trạng thái tài khoản |
| `employees`, `positions`, `profile` | Hồ sơ nhân viên, chức vụ/điều kiện và hồ sơ cá nhân |
| `schedule`, `attendance`, `devices` | Danh mục/phân ca, chấm công/camera và thiết bị |
| `attendance_requests` | Giải trình, tăng ca, điều chỉnh công và các bước duyệt |
| `approvals` | Trung tâm công việc và hàng đợi tác vụ theo quyền |
| `training` | Khóa học, tiến độ, quiz, ngân hàng câu hỏi và xác nhận hoàn thành |
| `checklist`, `documents`, `skills` | Checklist/mẫu, giấy tờ/catalog/review và đánh giá kỹ năng |
| `violations`, `rewards` | Vi phạm/giải trình và quyết định thưởng/phạt |
| `payroll`, `reports` | Kỳ công/readiness và báo cáo |
| `store` | Cửa hàng, vị trí GPS và chính sách chấm công |
| `notifications`, `audit` | Thông báo/deep link/delivery/nhắc việc và audit/CSV |

Mỗi feature đặt cấu hình module/form trong `domain/`, repository riêng khi cần trong `data/`, màn hình/widget/thao tác trong `presentation/`. Ví dụ: [tài khoản](lib/features/accounts), [đào tạo](lib/features/training), [cửa hàng](lib/features/store).

- `app/router/module_registry.dart` ghép 41 module từ các feature và giữ thứ tự điều hướng.
- `shared/resources/` chứa `ResourceRepository`, state tải/ghi, mô tả field, form, lookup và widget tái sử dụng.
- `core/network`, `core/storage`, `core/location`, `core/presentation` chứa API/JWT, secure storage/upload, GPS và thành phần giao diện dùng chung.
- `test/features/`, `test/core/`, `test/shared/` đặt kiểm thử theo cùng ranh giới; fixtures dùng chung ở `test/support/`.
- `examples/ui_demo/` giữ 14 file scaffold/demo ban đầu để tham khảo. Entry point phát hành `lib/main.dart` chỉ dùng source nghiệp vụ trong `lib/`.
- `hrm-coffeeshop-backend` giữ các Controller/DTO/Service/JPA và contract hiện có.

Kiểm tra import graph bằng `node tooling/Audit-RuntimeImports.cjs`.

## Phạm vi đã kiểm tra

Android emulator và Flutter web đã chạy với backend/SQL Server thật. Xem [VERIFICATION.md](docs/specification/v3.0/VERIFICATION.md) để phân biệt thao tác app, integration test và phần chưa nghiệm thu trên thiết bị thật. Phạm vi payroll hiện tại là kỳ công/đối soát/khóa công; chưa có công thức lương tiền, phiếu lương hoặc chuyển khoản.
