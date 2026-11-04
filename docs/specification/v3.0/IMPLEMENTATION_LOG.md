# Kết quả hoàn thiện source trong workspace case2

**Cập nhật 04/11/2026.** Thực hiện theo yêu cầu triển khai tiếp sau audit. Không chạy lệnh Git; không add, commit, checkout hoặc thay đổi lịch sử. Backend source được nạp từ `../hrm-coffeeshop-backend.zip` có sẵn tại máy, giữ cấu hình riêng tư và dữ liệu local.

## Đọc nhanh

- [Ma trận flow, screen, API, quyền và dữ liệu](IMPLEMENTED_FLOW_MATRIX.md).
- [Bằng chứng chạy app/test và giới hạn nghiệm thu](VERIFICATION.md).
- [190 operation từ OpenAPI + guard Controller](API_INVENTORY_IMPLEMENTED.md).
- [Cách chạy backend/frontend/SQL Server](../../../README.md).
- [Các quyết định nghiệp vụ còn cần chốt](BUSINESS_DECISION_REGISTER.md).

## Công việc đã triển khai

- [x] Khôi phục backend source local và đối chiếu Controller/DTO/Service/entity/permission/schema.
- [x] API client, secure tokens, refresh single-flight, lỗi nghiệp vụ/403, upload bytes và installation credential.
- [x] Ba workspace, capability theo quyền thật, router guard theo phiên hiện tại, route aliases, back stack và root form/camera/lookup.
- [x] Dashboard điều phối tác vụ dùng số liệu thật, work queues lọc theo grant, không số liệu demo.
- [x] Employee: profile, lịch, diagnostic check-in/out, GPS/camera, thiết bị, công/verifications, đơn công, checklist, đào tạo/quiz, giấy tờ, vi phạm, thưởng/phạt, thông báo.
- [x] Manager: nhân viên, ca/phân ca/eligibility, thiết bị có lịch sử và filter/search, duyệt từng loại đơn, checklist, training review, reports và kỳ công theo quyền.
- [x] Admin: tài khoản/role/direct permissions, chức vụ và requirements, khóa học/câu hỏi, checklist template, giấy tờ, kỹ năng, GPS cửa hàng/chính sách, reminders, audit/CSV và notification delivery.
- [x] Training quiz được chấm tại server theo passScore, giữ lịch sử/snapshot; non-quiz review từ enrollment. Training không chặn assignment/check-in.
- [x] Employee document catalog; reviewer dùng DOCUMENT_REVIEW không cần thêm quyền hồ sơ nhân viên ngoài tác vụ này; violation explanations giữ history và tách khỏi quyết định tiền.
- [x] Điều chỉnh công hai bước; permission bước cuối đọc được đúng queue/detail; bổ sung tên/ngày làm vào các đơn công.
- [x] Device approval ràng buộc bản cài đặt và khóa cạnh tranh; no-self-review; quản lý được PENDING/ACTIVE/LOCKED/REJECTED/REVOKED.
- [x] Ca qua đêm, thời gian SQL Server/Windows, FK của công mới và ID/version entity; giữ các business policy sẵn có.
- [x] Notification typed deep link và unread; payroll blockers mở đúng entity; read-after-write/refresh khi quay về màn hình.
- [x] Kiểm tra production import graph: 0 DemoData reachable. Các scaffold cũ không còn nằm trong đường chạy của router.
- [x] Unit/widget/integration và thao tác app với SQL Server; APK debug từ main entry build thành công.

## Thay đổi API/schema đáng chú ý

API bổ sung để khép khoảng trống source ZIP: quiz/questions/attempt history, enrollment/completion review, employee document catalog, violation explanation, device current/detail/list/per-employee, job positions/linkable accounts cho nghiệp vụ nhân viên, workboard/admin aggregates, một số detail phục vụ deep link và thưởng/phạt cá nhân. Giữ các endpoint cũ/alias hợp lệ; inventory là nguồn method/schema hiện tại.

`v3.sql` là migration SQL Server bổ sung: metadata completion review, snapshot attempt, question bank, violation explanations. Không xóa/reset database cửa hàng; chỉ áp dụng trên các database kiểm thử trong phiên. Cách áp dụng vào database có sẵn được ghi trong README. Không sửa `.env` để ghi bí mật vào source.

Các thay đổi không tự đặt giới hạn ca, quota quiz, role HR mới, công thức lương, cơ chế tự trừ phạt hoặc scope nhiều cửa hàng.

## Kiểm chứng

| Lớp kiểm chứng | Kết quả |
|---|---|
| Flutter analyzer | 0 issue |
| Flutter unit/widget | 16 đạt |
| Backend unit | 52 đạt, 0 skip |
| Backend SQL Server integration | 42 đạt, 0 skip |
| App web: màn hình/permission | 59/59 đạt |
| Android | Camera/GPS/đăng ký thiết bị/check-in/out thực hiện trên emulator, backend xác nhận và giữ lịch sử |
| APK main entry | `build/app/outputs/flutter-apk/app-debug.apk` build thành công |

Đã kiểm tra trên app: Admin đặt GPS, Employee đăng ký thiết bị, Manager duyệt, chụp/upload ảnh/check-in/out; Admin tạo câu hỏi, Employee nộp quiz; non-quiz review; nộp/duyệt giấy tờ; giao/thực hiện/submit checklist và Manager review; adjustment Manager → người có quyền bước cuối; đọc thông báo mở đúng hồ sơ; xử lý ca vắng từ blocker, xác nhận/chốt/mở lại/chốt lại kỳ công.

59 kiểm tra là screen/permission sweep, không phải tuyên bố mọi tổ hợp CRUD của 190 API đã E2E. Xem VERIFICATION để biết chính xác bằng chứng và phần chưa nghiệm thu.

## Trạng thái chạy local khi bàn giao

Backend dùng database kiểm thử, cổng `8081`; frontend web cổng `5000`; Android emulator đang chạy app acceptance. Các log/fixture/screenshot riêng tư nằm trong `.dart_tool/`. Server kiểm thử bind loopback. Phiên Google thật, webcam/thiết bị vật lý, iOS và các dịch vụ face/scanner/push vẫn cần nghiệm thu riêng.

Ca đã check-out không mở lại để check-in lần hai. Muốn lặp chuỗi từ đầu, dùng fixture/database kiểm thử mới và khởi động lại backend theo README; không sửa chính sách hay xóa công để ép demo chạy lại.

