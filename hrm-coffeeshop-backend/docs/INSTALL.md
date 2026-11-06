# Cài đặt database HRM Coffee Shop

Chỉ cần hai file database: `config.sql` tạo schema và `seeddata.sql` nạp dữ liệu nền cùng tài khoản demo. Không có script nâng cấp database hiện hữu; không chạy lại hai file trên database có dữ liệu.

## Cài mới

1. Đảm bảo SQL Server đang chạy và tài khoản có quyền `CREATE DATABASE`.
2. Mở toàn bộ `config.sql` trong một query window/connection duy nhất rồi chạy hết file. File tạo database `HRM_CoffeeShop`, toàn bộ bảng, khóa, constraints và index. Nếu database đã tồn tại, script sẽ dừng và không xóa dữ liệu. Không chạy chọn từng đoạn vì script dùng session guard qua các lệnh `GO`.
3. Trước khi chạy seed lần đầu, mở `seeddata.sql` và thay email trong khối **Tài khoản quản trị đầu tiên** bằng Gmail quản trị thật (Gmail này phải được thêm vào Google OAuth Test users nếu ứng dụng còn ở chế độ Testing). Sau đó chạy `seeddata.sql` để nạp role, permission, danh mục, tài khoản quản trị ban đầu và dữ liệu demo/test.
4. Cấu hình kết nối trong `src/main/resources/application.yml` hoặc biến môi trường.

## Quy tắc quan trọng

- Chỉ dùng `config.sql` cho database mới/trống.
- Không chạy lại `config.sql` trên database đang có dữ liệu. Script chủ động từ chối nếu DB đã tồn tại.
- `seeddata.sql` có kiểm tra dữ liệu đã tồn tại để hạn chế insert trùng. Dữ liệu demo cửa hàng `CF-HN01` chỉ được tạo một lần. Nếu seed dừng do lỗi constraint, xử lý nguyên nhân trong `seeddata.sql` rồi chạy lại; không tắt hoặc xóa CHECK/FK/UNIQUE để né lỗi.
- Khi thay đổi schema, cập nhật `config.sql`. Với database hiện hữu, sao lưu và nhờ DBA chuẩn bị kế hoạch nâng cấp riêng trước khi triển khai mã mới.
- Trước production, rà soát phần demo/test trong `seeddata.sql`; không dùng tài khoản và dữ liệu demo trên production.
- Nếu đã có database cần giữ dữ liệu, tuyệt đối không chạy lại hai file này để “nâng cấp”. Sao lưu trước mọi thay đổi schema.

## Kiểm thử tích hợp

Các integration test dùng SQL Server Testcontainers, nạp `config.sql` rồi `seeddata.sql`. Cần Docker, JDK và Maven. Chạy `scripts/run-integration-tests.sh`.
