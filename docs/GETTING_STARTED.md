# Bắt đầu: clone, cập nhật và chạy dự án

Tài liệu này hướng dẫn chạy bản development trên Windows bằng PowerShell. Ứng dụng gồm Flutter, Spring Boot và SQL Server; frontend và backend chạy ở hai terminal riêng.

Xem thêm [hướng dẫn Word: chạy và sử dụng đầy đủ](../HUONG_DAN_SU_DUNG.docx) cho demo bằng database kiểm thử, ba vai trò, GPS/camera, duyệt thiết bị và check-in/out.

## 1. Cài công cụ cần thiết

- Git
- Flutter SDK (Dart SDK từ 3.5 trở lên) và Android SDK nếu chạy Android
- Java JDK 17 và Maven
- Node.js (các script khởi động frontend dùng Node.js)
- SQL Server đang chạy, có thể kết nối từ máy phát triển

Kiểm tra môi trường Flutter và thiết bị bằng `flutter doctor` và `flutter devices`. Không cần Docker; script integration hiện tại cũng chạy bằng SQL Server local với database kiểm thử riêng.

## 2. Lấy mã nguồn

### Clone lần đầu

```powershell
git clone <URL-repository>
Set-Location PRM393_PROJECT
```

Thay `<URL-repository>` bằng địa chỉ repository của nhóm.

### Cập nhật bản đã clone

Mở PowerShell tại thư mục dự án, kiểm tra thay đổi đang có rồi lấy code mới:

```powershell
git status
git pull
```

Giữ lại các cấu hình local trong `hrm-coffeeshop-backend/.env`. File này bị Git bỏ qua và không được tải về khi clone. Nếu có thay đổi riêng trong `env.json`, đừng ghi đè chúng khi xử lý cập nhật.

## 3. Chuẩn bị SQL Server và database

Nếu chỉ cần xóa lượt chấm công vừa test và phân ca lại, xem [hướng dẫn reset một lượt chấm công](RESET_DATABASE.md).

Chọn đúng trường hợp của bạn:

- **Đã có database cần tiếp tục dùng:** cấu hình kết nối tới database đó trong `.env`. Không chạy lại `config.sql` hoặc `seeddata.sql` trên database đang có dữ liệu. Nếu schema chưa có cập nhật v3, dùng tùy chọn `-ApplyMigration` khi khởi động backend ở bước 6; migration bổ sung giữ dữ liệu hiện có.
- **Tạo database local mới:** dùng tài khoản SQL Server có quyền tạo database, mở và chạy toàn bộ `hrm-coffeeshop-backend/infra/sqlserver/config.sql` trong SSMS hoặc Azure Data Studio, sau đó chạy toàn bộ `hrm-coffeeshop-backend/infra/sqlserver/seeddata.sql`. `config.sql` tạo database `HRM_CoffeeShop` và chỉ dùng cho cài đặt mới. Trước khi chạy seed, thay email quản trị ban đầu bằng Gmail bạn kiểm soát.

`config.sql` đã tích hợp schema V3. Database mới chỉ cần chạy `config.sql` và `seeddata.sql`, sau đó khởi động backend bình thường. `-ApplyMigration` chỉ dành cho database cũ chưa có schema V3.

Không dùng `config.sql` để nâng cấp database đã tồn tại. Các bước này áp dụng cho database development local; với database dùng chung, xác nhận đúng database và migration cần chạy trước khi cập nhật.

## 4. Tạo cấu hình local cho backend và Google

Tạo `hrm-coffeeshop-backend/.env` (file không được commit) với thông tin phù hợp môi trường SQL Server của bạn:

```dotenv
DB_URL=jdbc:sqlserver://localhost:1433;databaseName=HRM_CoffeeShop;encrypt=true;trustServerCertificate=true
DB_USERNAME=sa
DB_PASSWORD=<mat-khau-SQL-Server>
JWT_SECRET=<chuoi-ngau-nhien-it-nhat-32-ky-tu>
GOOGLE_CLIENT_ID=<Web-OAuth-Client-ID>
```

Sửa máy chủ, cổng, tên database và tài khoản nếu SQL Server của bạn khác ví dụ. Script `Start-HrmBackend.ps1` và backend chạy trực tiếp từ IDE đều đọc `.env`. Biến môi trường đặt riêng trong cấu hình chạy của IDE được ưu tiên hơn giá trị trong file.

Đăng nhập của app cần Web OAuth Client ID giống nhau ở backend và `GOOGLE_SERVER_CLIENT_ID` trong file `env.json` tại thư mục gốc. Nếu file `env.json` chưa có, tạo từ mẫu:

```powershell
Copy-Item env.example.json env.json
```

Sau đó điền `GOOGLE_SERVER_CLIENT_ID` trong `env.json`. Hướng dẫn tạo Client ID, cấu hình Gmail test user và Android SHA-1 nằm trong [hướng dẫn đăng nhập Google](../hrm-coffeeshop-backend/docs/GOOGLE_LOGIN.md).

Khi dùng script khởi động bên dưới, cấu hình địa chỉ API được tạo tự động: Android emulator gọi `127.0.0.1:8080` qua `adb reverse`, còn web gọi `127.0.0.1:8080`. Khi chạy Flutter trực tiếp từ IDE với `env.json`, Android emulator gọi `10.0.2.2:8080`.

## 5. Tải dependencies lần đầu hoặc sau khi dependency thay đổi

Tại thư mục gốc dự án, chạy:

```powershell
flutter pub get
mvn -f hrm-coffeeshop-backend/pom.xml dependency:go-offline
```

Lệnh Maven tải dependencies trước vì script chạy backend dùng Maven ở chế độ offline. Chạy lại hai lệnh này khi `pubspec.yaml`, `pubspec.lock` hoặc `pom.xml` thay đổi sau một lần pull.

Nếu Flutter báo lỗi symlink trên Windows khi chỉ chạy Android hoặc web, đặt biến này trong terminal hiện tại rồi chạy lại `flutter pub get`:

```powershell
$env:FLUTTER_WINDOWS = 'false'
flutter pub get
```

## 6. Khởi động backend và ứng dụng

### Terminal 1: backend

Từ thư mục gốc dự án:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tooling/Start-HrmBackend.ps1
```

Backend chạy ở cổng `8080`; Swagger UI ở `http://localhost:8080/swagger-ui.html`.

Khi chạy `HrmApplication` trực tiếp từ IDE, backend cũng tự nạp `hrm-coffeeshop-backend/.env` từ thư mục gốc dự án hoặc `.env` từ thư mục backend. Kiểm tra các biến môi trường đặt riêng trong Run Configuration nếu giá trị khác file `.env`. Cách nạp file không có đuôi dùng [Spring Boot Config Data import](https://docs.spring.io/spring-boot/3.3/reference/features/external-config.html).

Nếu đang kết nối database cũ cần migration v3, dùng cờ dưới đây **một lần**:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tooling/Start-HrmBackend.ps1 -ApplyMigration
```

Giữ terminal backend mở khi dùng app. Các lần khởi động tiếp theo dùng lệnh không có `-ApplyMigration`.

### Terminal 2: Flutter app

**Android:** khởi động Android emulator có device ID `emulator-5554` (script hiện tại nhắm tới ID này), kiểm tra bằng `flutter devices`, rồi chạy:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tooling/Start-HrmFrontend.ps1 -Target android
```

**Web:**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tooling/Start-HrmFrontend.ps1 -Target web
```

Mở `http://127.0.0.1:5000` trong trình duyệt. Khi dừng một tiến trình, nhấn `Ctrl+C` trong terminal tương ứng.

## 7. Đăng nhập

Ứng dụng dùng đăng nhập Google, không có chức năng tự đăng ký hoặc đăng nhập bằng mật khẩu. Email cần đăng nhập phải được tạo sẵn trên backend và tài khoản phải ở trạng thái `ACTIVE`. Nếu Google OAuth đang ở chế độ Testing, Gmail cũng phải được thêm vào danh sách Test users. Xem [hướng dẫn đăng nhập Google](../hrm-coffeeshop-backend/docs/GOOGLE_LOGIN.md) nếu chưa cấu hình OAuth.

## 8. Lỗi thường gặp

| Hiện tượng | Kiểm tra |
|---|---|
| Backend không kết nối được SQL Server | Kiểm tra SQL Server đang chạy, `DB_URL`, cổng, tên database và thông tin đăng nhập trong `.env`. |
| Lỗi thiếu JWT secret | Đặt `JWT_SECRET` trong `.env`; giá trị cần ít nhất 32 ký tự. |
| Maven báo thiếu dependency khi chạy script | Chạy `mvn -f hrm-coffeeshop-backend/pom.xml dependency:go-offline` khi có kết nối mạng. |
| Flutter không tìm thấy `emulator-5554` | Khởi động emulator Android; kiểm tra tên thiết bị bằng `flutter devices`. |
| App mở ra màn hình đen trên máy ảo `nvb` | Dừng `flutter run` bằng `q`, tắt máy ảo, rồi chọn **Device Manager → nvb → Cold Boot Now** và chạy lại lệnh Flutter cũ. Đã xác nhận snapshot Fast Boot lỗi có thể làm màn hình đen dù Flutter đã dựng xong trang đăng nhập; Cold Boot giữ nguyên ứng dụng và dữ liệu. Không cần Wipe Data hoặc đổi cổng backend. |
| Đăng nhập Google thất bại | So khớp `GOOGLE_CLIENT_ID` và `GOOGLE_SERVER_CLIENT_ID`, kiểm tra Gmail đã được cấp tài khoản và nằm trong OAuth Test users nếu ứng dụng còn ở chế độ Testing. |
| `Could not decrypt key` khi mở app sau khi cài lại | Dừng hẳn Flutter bằng `q`, rồi chạy lại để nạp kho phiên `hrm_session_v2` và quy tắc backup mới. Đăng nhập Google lại một lần. Nếu tài khoản nhân viên cần chấm công, đăng ký và duyệt lại thiết bị khi app yêu cầu vì khóa bản cài đặt cũ không đọc được. |

## Sau mỗi lần `git pull`

1. Đọc ghi chú cập nhật hoặc migration mới trong repository.
2. Chạy lại `flutter pub get` và `mvn -f hrm-coffeeshop-backend/pom.xml dependency:go-offline` nếu các file dependency thay đổi.
3. Nếu thay đổi schema có migration mới, áp dụng migration cho đúng database theo hướng dẫn của repo; không chạy lại `config.sql` trên database đang dùng.
4. Khởi động lại backend và frontend theo bước 6.
