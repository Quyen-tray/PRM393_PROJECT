# Hướng dẫn chạy và test API

## 1. Chuẩn bị database

Backend chỉ có hai file SQL:

1. `config.sql`: tạo database `HRM_CoffeeShop`, bảng, khóa, constraints và index.
2. `seeddata.sql`: nạp role, permission, danh mục, tài khoản quản trị ban đầu và dữ liệu demo/test.

Chạy theo đúng thứ tự trên một database mới. Trước khi chạy `seeddata.sql`, thay email quản trị mẫu bằng Gmail thật nếu cần đăng nhập Google. `config.sql` sẽ dừng nếu database đã tồn tại, không tự xóa dữ liệu. `config.sql` và `seeddata.sql` là hai script nền; không chạy lại chúng để nâng cấp database đang có dữ liệu. Bản demo hiện có một migration one-off cho ngân hàng câu hỏi đào tạo và điều kiện nhận ca tại `infra/sqlserver/migrations/2026-11-03-training-quiz-and-nonblocking.sql`; đây không phải hệ thống migration tổng quát. Xem [INSTALL.md](INSTALL.md) và [GOOGLE_LOGIN.md](GOOGLE_LOGIN.md).

## 2. Đăng nhập thử khi chưa dùng Google

SRS sử dụng Google Sign-In (`POST /auth/google`). Backend có thêm `POST /auth/login` chỉ phục vụ development/test, mặc định tắt. Bật bằng biến môi trường `DEV_PASSWORD_LOGIN_ENABLED=true`; production phải để tắt.

| Biến | Ý nghĩa |
|---|---|
| `DB_URL`, `DB_USERNAME`, `DB_PASSWORD` | Kết nối SQL Server |
| `JWT_SECRET` | Chuỗi bí mật tối thiểu 32 ký tự |
| `DEV_PASSWORD_LOGIN_ENABLED` | Bật endpoint đăng nhập test |
| `BOOTSTRAP_ADMIN_PASSWORD` | Mật khẩu test cho tài khoản quản trị ban đầu |
| `TEST_ACCOUNTS_PASSWORD` | Mật khẩu chung cho tài khoản `*@hrm.test` |

Ví dụ IntelliJ Run Configuration:

```text
DEV_PASSWORD_LOGIN_ENABLED=true;BOOTSTRAP_ADMIN_PASSWORD=Admin2026ok;TEST_ACCOUNTS_PASSWORD=Test2026ok
```

## 3. Đăng nhập và gọi API

```http
POST http://localhost:8080/api/v1/auth/login
Content-Type: application/json

{"email":"baonvhe181955@fpt.edu.vn","password":"Admin2026ok"}
```

Lấy `data.accessToken` rồi gửi `Authorization: Bearer <accessToken>` ở các request tiếp theo. Swagger UI: `http://localhost:8080/swagger-ui.html`.

## 4. Tài khoản test

Các tài khoản dưới đây được tạo bởi `seeddata.sql`; mật khẩu được bootstrap khi bật chế độ đăng nhập test.

| Email | Vai trò |
|---|---|
| `baonvhe181955@fpt.edu.vn` | SYSTEM_ADMIN |
| `giamdoc@hrm.test` | OPERATIONS_DIRECTOR |
| `quanly@hrm.test` | STORE_MANAGER |
| `hr@hrm.test` | EMPLOYEE + tập quyền HR |
| `nv.an@hrm.test` | EMPLOYEE |
| `nv.binh@hrm.test` | EMPLOYEE |
| `nv.chi@hrm.test` | EMPLOYEE |
| `nv.dung@hrm.test` | EMPLOYEE |
| `nv.khoa@hrm.test` | Tài khoản LOCKED |

Dữ liệu cửa hàng và nhân viên trong seed là dữ liệu demo. Không sử dụng chúng trên production.

## 5. Khi triển khai production

- Đặt `DEV_PASSWORD_LOGIN_ENABLED=false` hoặc xóa biến này.
- Không đưa tài khoản và dữ liệu demo/test trong `seeddata.sql` lên production.
- Thay email quản trị ban đầu bằng email Google thực tế trước khi chạy seed.
- Thiết lập secrets mạnh và cấu hình HTTPS.
