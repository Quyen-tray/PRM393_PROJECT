# Kết quả kiểm thử — 04/11/2026

## Môi trường và cách đọc bằng chứng

- Backend Spring Boot chạy TCP tại `127.0.0.1:8081`, kết nối SQL Server local. Không dùng Docker.
- App Android chạy trên `emulator-5554` (AVD nvb); app web chạy tại `127.0.0.1:5000` trong Chrome với profile kiểm thử riêng.
- Database dùng cho thao tác app: `HRM_CoffeeShop_V3_Test_20261104160441`. Regression sau đó tạo các database riêng, giữ nguyên phiên/dữ liệu app. Database cửa hàng `HRM_CoffeeShop` không bị reset hoặc chạy migration trong phiên này.
- `lib/main.dart` là ứng dụng thật, Google OAuth và secure storage. `integration_test/live_app.dart` là entry point debug riêng cho đổi actor, dùng JWT kiểm thử với backend local; mỗi request vẫn được backend nạp role/permission/employee từ SQL Server.
- Unit/widget fixtures không được dùng để kết luận API live hoạt động. Integration backend dùng Spring thật + MockMvc + SQL Server, không mock bean nghiệp vụ. Các dòng “app” bên dưới là thao tác qua Flutter với backend TCP thật.

## Kiểm tra tự động đã chạy

| Kiểm tra | Kết quả | Bằng chứng local |
|---|---|---|
| `flutter analyze` | Không có issue | Output analyzer ở lượt cuối |
| `flutter test --no-pub` | 23 test đạt sau khi phân feature | `test/core/`, `test/features/`, `test/shared/` |
| Maven unit | 52 test đạt, 0 failure/error/skip | `hrm-coffeeshop-backend/target/v3-verification/unit/TEST-*.xml` |
| Maven integration với SQL Server | 42 test đạt, 0 failure/error/skip | `target/v3-verification/integration/TEST-*.xml`; `target/failsafe-reports/failsafe-summary.xml` trong backend |
| App web: screen/permission sweep | 59/59 kiểm tra đạt | `.dart_tool/live-screen-tour.json`, runner `tooling/Tour-LiveApp.cjs` |
| Build Android từ `lib/main.dart` | APK debug build thành công | `build/app/outputs/flutter-apk/app-debug.apk` |
| Import graph runtime | 100 file Dart reachable, 0 tham chiếu DemoData | `.dart_tool/runtime-import-audit.json`, `tooling/Audit-RuntimeImports.cjs` |
| OpenAPI đang chạy | 190 operation, gồm alias | `.dart_tool/openapi-current.json`; [API inventory](API_INVENTORY_IMPLEMENTED.md) |

59 kiểm tra màn hình gồm 16 trang Employee, 21 trang Manager, 20 trang Admin và 2 tình huống từ chối truy cập. Runner kiểm tra UI/HTTP thực tế khi điều hướng, không phải kiểm thử mọi tổ hợp CRUD trên mỗi trang. Các trang có dữ liệu cache có thể không phát sinh HTTP mới. Nhận định “59/59” không được thay bằng “toàn bộ API đã E2E”.

23 test Flutter kiểm tra refresh single-flight, giữ credentials khi lỗi mạng/server, thông điệp 403, capability nhiều role/quyền đơn lẻ, pagination/state/date mapping, entity identity trong thông báo, trang chấm công vẫn mở khi bị chặn, quay lại, thay đổi grant ngay trên URL đang mở, giữ form/chống submit trùng, form vẫn gửi được khi widget nguồn đã bị thay thế và quyền thu hồi thiết bị không bị nhầm với cấm tự duyệt. Bảy test Google kiểm tra tên biến tương thích, ưu tiên cấu hình, thiếu cấu hình, nhận token, thiếu token, hủy đăng nhập và backend từ chối; đây là unit test với platform/HTTP fixture.

Sau khi phân source theo feature V3, snapshot đối chiếu 41 module khớp toàn bộ thứ tự điều hướng, route, endpoint, cấu hình form và sáu tổ hợp role/permission. 19 route khai báo trong router và 18 khối thao tác nghiệp vụ cũng khớp bản trước khi di chuyển. Báo cáo local: `.dart_tool/feature-layout/validation.json`; snapshot trước/sau: `module_before.json`, `module_after.json` trong cùng thư mục. Các màn demo ban đầu được giữ ở `examples/ui_demo/`, ngoài import graph của `lib/main.dart`.

Backend integration bao gồm tranh chấp/check-in idempotency/khóa kỳ, ca qua đêm, xác minh và signed file/audit, giới hạn upload, refresh token, thiết bị và binding installation, quiz chấm tại server/snapshot, review non-quiz, hồ sơ/permission-only, giải trình vi phạm, adjustment hai bước và các luồng hiện có của bộ IT. V3WorkflowIT bổ sung regression cho danh sách thiết bị, `/rewards-penalties/me`, default sort danh sách vi phạm và metadata hàng đợi công.

## Các hành vi đã thực hiện trên app

| Chuỗi | Kết quả thực tế | Screenshot trong `.dart_tool/screenshots/` |
|---|---|---|
| Employee đăng ký thiết bị → Manager duyệt | Employee thấy PENDING; Manager thấy đúng đơn, duyệt thành ACTIVE; installation được giữ khi đổi actor/hot restart | `android-device-pending.png`, `web-device-approved-final.png` |
| Tìm lại thiết bị đã duyệt | Manager lọc ACTIVE, nhập tên nhân viên, chỉ còn đúng thiết bị Android đã được duyệt | `web-device-management-search-verified.png` |
| Admin lấy GPS → lưu → đổi Employee | Lưu khoảng 21.0283 / 105.8349983, khác tọa độ seed; Employee nhận tâm mới, khoảng cách 0 m, accuracy 5 m | `android-store-gps-saved.png` |
| Camera → xem lại → upload → check-in/out | Chụp bằng camera emulator; backend ghi attendance #59, giờ vào 17:06:46, ra 17:09:12; CHECKED_OUT | `android-camera-preview.png`, `android-attendance-record.png` |
| Xem verification sau công | Hai bộ GPS/DEVICE/PHOTO PASSED; hai ảnh có evidenceViewUrl; FACE_LIVENESS EXEMPTED đúng adapter hiện tại | `android-verifications.png`; `tooling/Check-LiveFlows.cjs` kiểm tra chỉ đọc |
| Admin tạo khóa/biên soạn câu hỏi → Employee đăng ký/nộp | Khóa #7, server chấm 1/1, 100 điểm so với passScore 70, PASSED | `web-quiz-bank-saved.png`, `web-quiz-result-ready.png` |
| Quiz chưa đạt → làm lại | Khóa #3: chọn B, server chấm 0/100 và FAILED; làm lại chọn A, attempt #2 đạt 100/100 và PASSED | `web-quiz-failed.png`, `web-quiz-retake-passed.png` |
| Non-quiz: Employee đăng ký → Manager xác nhận | Enrollment khóa #6 chuyển PASSED, không có điểm quiz giả | `web-training-review-approved.png`, `web-training-completed.png` |
| Employee nộp giấy tờ → Manager có DOCUMENT_REVIEW duyệt | File chọn từ app, upload thật, PENDING rồi APPROVED; owner xem lại lịch sử | `web-document-approved.png` |
| Manager giao checklist → Employee start/complete/submit | Checklist Bàn giao ca được giao đúng nhân viên, hoàn thành các mục, submit; tự APPROVED vì template không cần Manager | `web-checklist-completed.png` |
| Manager duyệt checklist cần phê duyệt | Checklist Mở cửa hàng đang SUBMITTED chuyển APPROVED | `web-manager-checklist-approved.png` |
| Employee đề nghị điều chỉnh → Manager → người có quyền bước cuối | Tạo hai request theo trường; request CHECK_IN chuyển PENDING_MANAGER → PENDING_HR → APPROVED và áp dụng | `web-adjustment-manager-approved.png`, `web-adjustment-final-approved.png` |
| Notification → đọc → đúng detail | Mở “Kết quả xác nhận đào tạo”; unread count giảm 6 → 5, vào đúng enrollment đã PASSED | `web-notification-deep-link.png` |
| Readiness → ca vắng → Manager confirm → finalize/reopen | Kỳ #1 có 3 nhân viên, blocker ca vắng 19/10 được tạo đơn và duyệt; Manager xác nhận, Admin có PAYROLL_FINALIZE chốt; PAYROLL_REOPEN mở lại kèm lý do, sau đó xác nhận/chốt lại | `web-payroll-readiness.png`, `web-payroll-manager-confirmed.png`, `web-payroll-finalized.png`, `web-payroll-reopened.png`, `web-payroll-finalized-again.png` |
| Truy cập không được cấp quyền | Employee mở tài khoản Admin và Manager mở store settings đều bị chặn 403 | `web-permission-denied.png`, sweep report |

Sau check-out, ca đó không cho check-in lần hai. Đây là trạng thái đúng của một bản ghi công/assignment; cần fixture/ca phù hợp mới khi lặp lại demo. Yêu cầu CHECK_OUT còn chờ duyệt trong database kiểm thử là dữ liệu tác vụ, không phải thao tác đã được tự coi hoàn tất.

Bốn khóa seed #1–4 ban đầu chưa có ngân hàng câu hỏi. Đã biên soạn câu hỏi mẫu qua màn Admin trong database kiểm thử bằng `tooling/Prepare-LiveTraining.cjs`; script chỉ chạy với database test, bỏ qua mọi bank đã có. Đây là nội dung fixture để thử luồng, không tự thêm vào database cửa hàng hoặc coi là giáo trình đã được phê duyệt.

## Lỗi tìm thấy trong quá trình chạy và đã sửa

1. SQL Server/Windows chuyển `LocalTime` qua `java.sql.Time` làm giờ ca bị lệch: ánh xạ JDBC LocalTime trực tiếp.
2. Entity mới có `@Version=0L` khiến JPA merge và DTO trả ID null: để version ban đầu null, giữ optimistic concurrency.
3. Giải trình tạo Attendance mới nhưng chưa flush trước verification FK: saveAndFlush trước evidence.
4. Device approval đồng thời có thể đọc trạng thái cũ: khóa employee trước khi nạp device; regression xác nhận một 200, một 409.
5. Guard không đánh giá lại nếu session thay đổi nhưng URL giữ nguyên: Consumer guard theo phiên hiện tại.
6. Form giữ WidgetRef của resource widget đã unmount: lấy repository/revision trước khi mở form, thêm regression.
7. API thưởng/phạt cá nhân thiếu mapping `/me`, bị route numeric detail nhận nhầm: thêm endpoint owner riêng.
8. Danh sách vi phạm mặc định sort theo `incidentAt` (DTO), entity dùng `occurredAt`: sửa sort và regression gọi endpoint thật trong Spring/SQL Server.
9. Thiết bị đã duyệt biến mất khỏi danh sách pending: thêm trang quản lý có query/filter/search và lịch sử owner, giữ pending alias.
10. Hàng đợi công thiếu tên/ngày khiến các dòng “Giờ vào/Giờ ra” khó phân biệt: bổ sung metadata DTO; giữ đơn vị một request mỗi trường.
11. Kỳ công UI chỉ nhìn `canFinalize` nhưng chưa xét stage/ngày: ghép đúng periodStatus, thời gian, permission; bỏ ô ghi chú ở action không có note contract.
12. Cấm tự duyệt thiết bị từng bị dùng chung cho cả nút thu hồi: tách hai hành vi theo service; người có DEVICE_APPROVE có thể thu hồi thiết bị ACTIVE của mình, vẫn không thể tự approve/reject yêu cầu đăng ký.

## Phần chưa được nghiệm thu hoặc ngoài phạm vi

- Google OAuth với tài khoản Google thật chưa được thao tác trong lượt acceptance; JWT test không thay thế bằng chứng này.
- Camera vật lý, webcam laptop, GPS trên điện thoại thật, permission bị từ chối vĩnh viễn và iOS chưa được nghiệm thu. AVD hiện dùng front `emulated`, back `virtualscene`; hình xanh là nguồn camera mô phỏng. Muốn thấy webcam cần đổi nguồn camera AVD và cold boot, hoặc dùng điện thoại thật.
- Đăng nhập Google native Windows/Linux không được plugin hiện tại hỗ trợ; ứng dụng báo rõ, không giả lập thành công. Native Windows còn cần symlink/Developer Mode cho build plugin.
- Face/liveness và quét mã độc đang dùng adapter chưa có dịch vụ thực. App chỉ khẳng định ảnh bằng chứng được lưu; không khẳng định đã nhận diện khuôn mặt. Push gateway chưa cấu hình: không đánh dấu như đã gửi. Inbox/read/deep link hoạt động độc lập với push.
- Chưa có công thức lương tiền, payslip, chuyển khoản, hoặc scope nhiều cửa hàng. Kỳ công/readiness/lock là phạm vi source hiện tại.
- Build Android còn cảnh báo phiên bản Gradle/AGP/Kotlin và SDK tooling sẽ cần nâng cấp theo một đợt riêng; build hiện tại đã thành công, không dùng cờ bỏ qua validation để che lỗi.

Những điểm này không được đánh dấu hoàn thành chỉ vì đã có màn hình, unit fixture hoặc một adapter trả về giá trị.


## 2026-11-05 — Xác minh đợt sửa UI theo phản hồi

- Flutter analyze --no-pub: không còn issue.
- Flutter test --no-pub: 30 test đạt. Bổ sung hồi quy status rỗng, Check-out khi thiết bị cần xử lý, chọn workspace, 401 tài khoản cũ, CRUD từng câu và Back giữa các phần hồ sơ nhân viên.
- Maven unit: 52 test đạt, không failure/error/skip.
- Maven verify trên database SQL Server test riêng, giữ nguyên marker/phiên live: 45 integration test đạt, không failure/error/skip. UiWorkflowRegressionIT kiểm tra CRUD câu hỏi qua JWT/controller/service/database, cấm pass thủ công, tự archive, giữ task sau archive, ảnh checklist ký URL, Tất cả có APPROVED, tìm tài khoản và reminder ID chuỗi.
- APK debug build/cài trên emulator nvb; app dùng integration_test/live_app.dart và backend thật ở 8081 qua ADB reverse. Đã mở trang ngân hàng câu hỏi và lịch tháng, chạy luồng Manager nhân viên → thiết bị → chi tiết → Back; xác nhận một nút Back/thanh tiêu đề sau khi quay lại.
- Một lượt nhập câu hỏi bằng ADB thoát form trước khi lưu: không coi là CRUD E2E thành công. CRUD đã được xác minh bằng widget flow và integration HTTP/SQL Server độc lập.
- Screenshot thực tế lưu trong .dart_tool/screenshots/ui-refresh-*.png. Runtime import audit: 106 Dart file reachable, 0 production DemoData reference. OpenAPI runtime: 203 operation kể cả alias.
- Các kết quả trên xác minh phạm vi sửa lần này; không khẳng định đã thực hiện đầy đủ E2E của mọi operation hay thử lại toàn bộ camera/GPS trong lần chạy này.
- Sau khi thu gọn mặc định panel bộ lọc, hai hồi quy Tất cả cho giải trình và tăng ca pass; `flutter analyze --no-pub` không có issue. Emulator xác nhận danh sách tài khoản hiện ngay cùng panel lọc thu gọn.
