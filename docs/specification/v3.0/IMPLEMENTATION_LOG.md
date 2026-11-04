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
| Flutter unit/widget | 23 đạt; phân theo `test/core`, `test/features`, `test/shared` |
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

## Sắp xếp source Flutter theo feature V3 trên case2

- Phân 41 module về 18 file định nghĩa trong các feature nghiệp vụ. `app/router/module_registry.dart` chỉ ghép module và giữ thứ tự menu/route.
- Đưa màn hình, form chuyên biệt và 18 khối thao tác về feature sở hữu: accounts, positions, training, checklist, documents, devices, attendance, attendance_requests, employees, payroll, rewards, violations và các nhóm cấu hình/giám sát.
- Tách login về auth; dashboard về dashboard; hồ sơ cá nhân về profile; trung tâm duyệt về approvals; shell/menu/chi tiết ghép theo workspace giữ trong workspace.
- Chuyển repository/state, field spec, form, lookup và widget dùng lại sang `shared/resources`. Đổi tên `OperationsRepository` thành `ResourceRepository`; CSV audit dùng `features/audit/data/audit_repository.dart`.
- Đặt model user/session trong auth/domain, model workspace trong workspace/domain, GPS dùng chung trong core/location.
- Giữ 14 file UI demo ở `examples/ui_demo`, cùng các import tham khảo đã cập nhật. Các package tạm admin/operations/home không còn trong `lib/features`.
- Phân test theo feature/core/shared và giữ fixtures ở test/support. Analyzer sạch; 23 test đạt. Snapshot xác nhận route, API, form, permission và nội dung các khối xử lý giữ nguyên; `pubspec.lock` không đổi.
- Build lại APK debug từ `lib/main.dart` với cấu trúc mới thành công; artifact ở `build/app/outputs/flutter-apk/app-debug.apk`.

Sơ đồ thư mục và trách nhiệm từng nhóm được cập nhật trong README gốc. Backend, schema và quy tắc nghiệp vụ giữ nguyên trong đợt sắp xếp này.



## 2026-11-05 — UI và workflow theo phản hồi ba role

- Đọc/giải nén mobile-app-ui-design-main.zip vào .dart_tool/ui-reference. ZIP chứa hướng dẫn mobile UI, không chứa app mẫu. Áp dụng nội dung gọn, thao tác từng mục, khoảng cách nhất quán và trạng thái rõ.
- Admin: tài khoản tìm kiếm server theo tên/email; lọc ACTIVE/LOCKED/INACTIVE và role; sắp xếp, số dòng/trang. DELETE tài khoản chuyển INACTIVE và thu hồi refresh token, cấm tự ngừng tài khoản và bảo vệ Admin hoạt động cuối cùng.
- DELETE khóa học, mẫu checklist, ca, kỹ năng và reminder chuyển isActive=false. Đây là xóa khỏi danh mục sử dụng, giữ lịch sử và quan hệ SQL Server. Quy tắc nhắc dùng mã chuỗi; tắt nhắc không bỏ xử lý trạng thái quá hạn/vi phạm.
- Chức vụ giải thích giấy tờ và đào tạo áp dụng. Kích hoạt checklist chỉ hiện khi inactive, mô tả rõ chọn version cho checklist mới; task cũ giữ nguyên nội dung.
- Trang quản lý câu hỏi riêng mở ngay đầu khóa học, có tìm kiếm/phân trang và CRUD từng câu. Sửa câu sinh ID mới, bảo toàn snapshot và ngăn chấm bài theo nội dung câu đã đổi.
- Gỡ ghi điểm thủ công khỏi UI; endpoint cũ trả 409, không tạo enrollment/attempt. Học viên cần ghi danh và làm quiz hoặc theo quy trình review hoàn thành hiện có.
- Profile bỏ tải lại quyền và đăng xuất; logout vẫn ở menu tài khoản/sidebar.
- Manager: công hôm nay thu gọn; nhân viên chỉ đọc trong workspace Manager. Các mục đào tạo/thiết bị/giấy tờ/kỹ năng có route riêng /employee-records/:employeeId/:section, Back từ chi tiết về đúng mục, không lặp thanh tiêu đề. Chi tiết nhân viên dùng GET theo ID có sẵn.
- Lịch phân ca nhóm ngày, chọn tuần, lọc nhân viên qua lookup tìm kiếm/phân trang. Chấm công/checklist/thiết bị có sort, page size và tổng kết quả.
- Bộ lọc Tất cả gửi status rỗng rõ ràng; client bỏ status vẫn giữ mặc định cũ. Checklist APPROVED xuất hiện trong Tất cả. Attendance tách trạng thái vòng đời và chỉ số muộn/về sớm.
- Checklist và yêu cầu công có API ảnh ký ngắn hạn, scope/quyền và màn xem phóng to. OT lấy ảnh attendance liên quan; không tạo ảnh thay thế.
- Kỳ công giải thích hai bước và blocker; chỉ tạo đơn vắng khi còn thiếu/bị từ chối, báo số đơn thực tạo và mở danh sách duyệt. Backend giữ khóa kỳ/chống trùng.
- Employee: lịch công tháng kết hợp assignment và attendance; có biểu tượng, màu, chi tiết ngày. Không coi ngày không phân ca là vắng mặt đã duyệt. Ca đã vào chưa ra được ưu tiên trước ca mới; dashboard vẫn là Check-out khi còn điều kiện cần xử lý.
- Login chọn workspace đã lưu của đúng user hoặc mặc định Admin, Manager, Employee rồi mở tổng quan. 401 của tài khoản cũ không xóa phiên mới. Actor selector test cũng về tổng quan khi đổi actor.
- Helper Android dùng ADB reverse 8081 + localhost. Không đổi schema, không chạy iOS, không thao tác Git.
- Các bộ lọc phụ trên danh sách được thu gọn mặc định; bộ lọc tài khoản vẫn hiện trạng thái đang chọn và số dòng/trang để danh sách chiếm phần lớn màn hình.
- Kiểm chứng: analyzer sạch; 30 Flutter test; 52 unit và 45 integration test SQL Server không failure/error/skip. Build/cài debug Android; mở trang câu hỏi, lịch tháng, kiểm tra nhân viên → thiết bị → chi tiết → Back trên emulator. Không coi các lượt mở màn hình là E2E đầy đủ mọi endpoint. OpenAPI runtime có 203 operation, gồm alias.
