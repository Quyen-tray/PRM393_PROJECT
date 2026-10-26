# HRM Coffee Shop Flutter Frontend

Scaffold giao diện Flutter dựa trên SRS v2.0 (một cửa hàng). `lib/main.dart` có màn hình nhân viên chạy thử bằng dữ liệu mẫu. Các thư mục tính năng là khung trống để triển khai tiếp; chưa có Google OAuth, GPS, camera, backend, phân quyền hoặc chấm công thật.

## Chạy
1. Tạo platform files: `flutter create .`
2. Cài dependencies: `flutter pub get`
3. Chạy: `flutter run`

## Kiến trúc
- `core/`: router, theme, network, constants
- `data/`: models, repositories, services dùng chung
- `features/`: auth, home, attendance, schedule, checklist, training, profile, employees, approvals, reports, notifications, devices, documents, violations
- `shared/widgets/`: widget dùng chung

API contract trong SRS: `/api/v1`, JSON camelCase, Bearer JWT; backend chịu trách nhiệm xác thực và phân quyền.
