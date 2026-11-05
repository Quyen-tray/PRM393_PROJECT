# HRM Coffee Shop V3.0 — Source Audit

> Báo cáo audit lịch sử. Source trong workspace đã được triển khai tiếp sau báo cáo này; xem [IMPLEMENTATION_LOG.md](IMPLEMENTATION_LOG.md) và [VERIFICATION.md](VERIFICATION.md) cho trạng thái 04/11/2026. Không dùng các kết luận “chưa chạy/chưa có” bên dưới để đánh giá bản đang chạy.

## Kết luận và phạm vi

- Baseline đầy đủ đã mở rộng audit: Flutter và backend cùng Git ref **case1**, commit **c889df14360cb583d49c6364f2bdca5d610bf13c**.
- Working tree vẫn ở **case2/0af31cb547580157e57d04f6dec039a8a229c7cc**, là snapshot Flutter cũ. Đọc source case1 qua Git tree, không checkout/chuyển nhánh.
- Git xác nhận case2 là tổ tiên case1. So sánh lib/test/pubspec có 103 file thay đổi giữa hai snapshot. Audit ban đầu chỉ xét Flutter case2 đã bỏ sót Flutter tích hợp ở case1; báo cáo này sửa lại phạm vi đó.
- Không dùng thư mục backend chưa track làm bằng chứng; không đọc .env hoặc dữ liệu cá nhân.
- File docs/specification/v3.0/MASTER_SPECIFICATION.md chưa có. Nội dung Draft V3.0 trong hội thoại chưa được xác nhận là master chính thức. D:/Content/Downloads/API_REFERENCE.md là tài liệu ngoài checkout, không thay thế source.
- Đây là static source audit. Không sửa app/API/database, không chạy app/build/test, không kết nối SQL Server.

## Backend — kiến trúc và inventory

Backend tại case1 dùng Spring Boot 3.3.5, Java 17, Maven, Spring Web/Security/Data JPA, Microsoft SQL Server JDBC và springdoc. Cây backend có 259 file Java tổng cộng, gồm 42 file Java test; 46 controller, 45 domain entity, 45 repository và 44 service. Các package gồm admin, employee, manager, hr, shared, common, config, domain và repository.

| Lớp | Kết quả |
|---|---|
| Controller / DTO | HTTP mapping được chia theo module; request/response records dùng Bean Validation. Prefix /api/v1 được áp dụng theo package trong SecurityConfig. |
| Service / repository / entity | Transaction, validation nghiệp vụ, data scope và state transition nằm chủ yếu ở service; entity/repository ánh xạ tới schema dbo. |
| Security | Stateless JWT; method security; fail-closed với mọi endpoint không công khai. Mỗi request filter nạp lại user active, roles và permission hiệu lực từ DB. |
| Role / permission | Roles: SYSTEM_ADMIN, STORE_MANAGER, EMPLOYEE, OPERATIONS_DIRECTOR. HR là PermissionSets.HR, không phải role riêng. Một số service kiểm tra thêm quyền/phạm vi so với annotation. |
| Exception | GlobalExceptionHandler map validation 400, auth 401, permission 403, not found 404, conflict/state/optimistic lock 409, nhiều business rule 422, rate limit 429 và lỗi không xử lý 500. |
| Database | infra/sqlserver/config.sql, seeddata.sql và hai SQL migration ngày 2026-11-03. application.yml dùng SQL Server/JDBC, schema dbo và ddl-auto:none. Không thấy Flyway/Liquibase. |
| OpenAPI | Có springdoc dependency và SecurityConfig mở Swagger/OpenAPI; không chạy server hoặc đối chiếu /v3/api-docs. |
| Test | Có unit/service/security và integration test, gồm auth/refresh, permission, geo, attendance concurrency/idempotency, checklist, documents, training quiz/review, violation explanation, payroll và notification. Chỉ đọc inventory, không chạy test. |

### Security/configuration

- Public: POST /api/v1/auth/google, POST /api/v1/auth/refresh, GET /api/v1/storage/view khi chữ ký còn hạn, Swagger/OpenAPI và /error.
- CORS cho phép http://localhost:5000; headers có Authorization, Content-Type, Accept, Idempotency-Key và X-Correlation-Id.
- Port backend mặc định là 8080. DB/JWT/OAuth được cấu hình qua môi trường; JWT secret cần cấu hình trước khi chạy. Giá trị mặc định local không phải cấu hình triển khai.
- NoopUploadScanner không quét malware; NoopFaceVerificationClient trả NOT_RUN; LoggingPushGateway ghi rõ push không được gửi và trả false để dispatcher retry rồi đánh FAILED.

## Backend — hành vi xác minh tĩnh

| Nhóm | Kết quả source | Giới hạn |
|---|---|---|
| Chấm công | AttendanceService kiểm tra employee ACTIVE, assignment sở hữu bởi employee, ca PUBLISHED, thời gian, kỳ công chưa khóa, thiết bị ACTIVE, GPS mới/đủ chính xác/trong bán kính và storage key ảnh tồn tại. Ghi attendance, verification và audit. | Không chứng minh camera/GPS/upload hoạt động trên thiết bị; face adapter mặc định NOT_RUN. |
| Idempotency | Check-in/out nhận header hoặc body key, lưu key trên Attendance; retry cùng key trả kết quả cũ; key khác tạo conflict. Có CheckInRaceIT. | Key là tùy chọn; integration test chưa chạy. |
| Training quiz | GET quiz không trả đáp án đúng. Submit phải trả lời đủ câu, không trùng; service tính điểm và so với PassingScore, lưu attempt và cập nhật status. Fail có thể thi lại; pass còn hiệu lực không thể thi lại. | DTO yêu cầu lựa chọn chữ hoa A–D dù service chuẩn hóa chữ thường; client nên gửi chữ hoa. Không thấy giới hạn số lần thi. |
| Training không quiz | eligibility hiện trả eligible=true dù còn requirement; gọi từ phân ca/check-in không chặn ở trạng thái source này. | Chỉ xác nhận với code tại case1. |
| Duyệt hoàn thành training | Admin/Manager có pending, approve, not-complete cho course không quiz. | Queue gồm mọi enrollment non-quiz chưa có pass còn hiệu lực; không yêu cầu PENDING_REVIEW hoặc employee submit. Không thấy endpoint employee ghi CompletionSubmittedAt/CompletionRequestNote. Có thể approve ngay sau enroll. |
| Ca qua đêm | ShiftService diễn giải endTime nhỏ hơn startTime thành ngày hôm sau; assignment lưu planned timestamps dạng Instant và kiểm tra overlap theo thời gian thực. | Không thấy giới hạn độ dài ca; chưa chứng minh E2E qua đêm. |
| Thiết bị | Tối đa một thiết bị ACTIVE mỗi nhân viên; chặn nhiều yêu cầu PENDING. Approve máy mới khóa máy ACTIVE cũ; reject/revoke cần lý do; chặn tự duyệt. | Controller yêu cầu DEVICE_APPROVE; service review còn yêu cầu STAFF_REVIEW. |
| Điều chỉnh công | Employee submit → Manager approve/reject → nếu Manager approve thì HR review. HR approve sửa công, ghi AttendanceAdjustmentHistory và verification GPS EXEMPTED; chặn tự duyệt và kỳ khóa. | Flutter case1 có form/Manager/HR screens gọi API; mỗi field là một request, timeline/note DTO và refresh liên module cần hoàn thiện. |
| OT | Bắt đầu từ planned end trở đi, end sau start, giới hạn theo app.overtime.max-minutes, không trùng request pending/approved; chỉ OT duyệt mới được tính. | Chưa thấy rule max-duration ca. |
| Payroll | Readiness có blockers cho adjustment/OT/explanation pending, checkout thiếu và ca vắng thiếu/đang chờ/bị từ chối đơn ABSENCE. Manager confirm → HR_REVIEW; HR finalize khi hết kỳ và sẵn sàng; reopen cần PAYROLL_REOPEN. | Kiểm tra permission kết hợp class/method/service. Chưa chạy với SQL Server. |
| Documents / violation | Employee lấy catalog giấy tờ, nộp hồ sơ, gửi giải trình vi phạm; HR duyệt giấy tờ; Manager xử lý vi phạm. | Catalog và violation explanation endpoints bị thiếu trong API Reference. |
| Notification | Có list/unread/read/read-all; record giữ relatedEntityType/Id. | Không có target route cụ thể; Flutter cần map entity. Push adapter hiện không gửi. |
| Audit | AuditService ghi action/entity/before/after, actor, IP, user-agent/correlation; Admin list/detail/export, không có sửa/xóa. | AdminAuditLogPage case1 đã có query/detail/export; chưa nghiệm thu runtime và tính đầy đủ audit mọi nhánh. |

## Flutter — source đầy đủ case1

Inventory: **84 file Dart trong lib, 48 file page và 25 file Dart test**. Source có UI Employee, Manager, Admin và HR task workspace. Không tìm thấy call site DemoData. trong lib case1; một số enum Demo* còn được dùng làm model hiển thị. Không coi tên file/enum là bằng chứng API dùng dữ liệu giả.

| Khu vực | File/source chính | Kết quả audit |
|---|---|---|
| Auth/session | auth/data/auth_repository.dart, login_page.dart, ApiClient | Google ID-token login thật; restore current user/permission, secure storage, Bearer, refresh single-flight, logout có source. Chưa có SessionController/guard điều hướng trung tâm. |
| Workspace/router | app_router.dart, route_names.dart, role_selection_page.dart, User | Có Employee/Manager/Admin + HR workspace theo một nhóm permission. OPERATIONS_DIRECTOR đã map Manager. Router tĩnh không redirect/guard; / là Manager; role-selection phụ thuộc User trong state.extra. |
| API/data | EmployeeRepository khoảng 1.886 dòng, ChecklistRepository, NotificationRepository, AuthRepository | Phần lớn module đã có API wiring. EmployeeRepository bao nhiều domain; nhiều Map/dynamic, một số list method bỏ pagination metadata. |
| State/error | ConsumerStatefulWidget, FutureBuilder, Future.wait và CurrentAccess | Loading/action/error có ở nhiều màn nhưng state và refresh chủ yếu cục bộ; chưa có dependency graph. ApiException giữ HTTP/details nhưng bỏ error.code, mọi 403 bị thay thông báo chung. |
| Employee | dashboard, schedule, check-in/history, checklist, training/quiz, profile/documents, violations/rewards, notifications | Các màn và API call tồn tại. Check-in tải store/current/device, chụp ảnh qua CameraCapturePage, upload, gửi attendance và idempotency thật. Chưa nghiệm thu thiết bị/runtime. |
| Manager | dashboard, roster/detail/edit, shifts, approval hub, device/checklist/training/documents/violation/rewards/payroll/reports | API-backed source có. Manager nextActions chỉ filter documents thêm, HR adjustment target null; approval hub tải 14 API bằng Future.wait nên một nguồn 403 có thể làm lỗi toàn hub. |
| Admin | users/permission, positions/requirements, documents, training/questions, templates/editor, settings/GPS, skills, audit/deliveries | UI + API wiring có. Dashboard đếm bằng các list, account scan bị cap 100 trang x 50. Không có admin-overview backend riêng. |
| Camera/GPS/platform | camera_capture_page.dart; Android main manifest; iOS plist | Có fallback lens/resolution, lifecycle camera; Android main có INTERNET/CAMERA/location; iOS có usage descriptions. Đăng ký attendance device chỉ hỗ trợ Android/iOS theo client/backend contract. |
| Notifications | NotificationRepository, EmployeeNotificationsPage | Có pagination/read/read-all và normalize type; tap hiện chỉ mark-read, chưa resolve related entity. |
| Tests | 25 file test Dart, gồm auth/logout, repositories, employee dashboard/schedule/check-in/training/checklist/docs/notifications/rewards/violations và admin/device/review | Test source tồn tại; widget_test đã là login smoke test, không còn counter. Chưa chạy trong review này; mock tests không xác nhận live API. |

### Các gap Flutter đã xác định cụ thể

- Không có router/session/capability guard trung tâm; direct route có thể render screen rồi mới lỗi API.
- Workspace HR được tạo riêng khi có một số permission, chưa thống nhất yêu cầu ba workspace chính.
- Detail/forms dùng cả GoRouter và Navigator/modal, returnRoute qua state.extra; back/context có thể mất sau reload.
- Device ACTIVE được chọn từ danh sách của employee, không đối chiếu installation hiện tại; DeviceView không trả binding và check-in chỉ gửi deviceId. Đây là gap semantics/security của thiết bị được duyệt.
- formatters chưa map đầy đủ UNDER_REVIEW/EXPIRED profile, RESTRICTED eligibility, REVIEW_REQUIRED/ADJUSTMENT_PENDING/FINALIZED attendance; training unknown fallback thành “Chưa ghi danh”.
- Payroll blockers UI mới hiển thị label/count, chưa có drill-down tới đối tượng.
- Source check-in giữ retry key trong widget state, chưa duy trì qua app restart; cần quyết định mức đảm bảo retry.
- Global refresh liên nghiệp vụ, notification deep link và màn chi tiết tải độc lập cần hoàn thiện.

## Lệch giữa API Reference, backend và Flutter

| Nội dung | Backend case1 | API Reference / Flutter |
|---|---|---|
| Current user | GET /users/me | Flutter case1 đã dùng đúng /users/me; /auth/me là sai lệch của case2 cũ. |
| Port | application.yml mặc định 8080 | API Reference nêu local ví dụ 8081; Flutter emulator mặc định 10.0.2.2:8080. |
| Quiz | Employee GET /training/courses/{id}/quiz, POST /quiz-attempts; Admin GET/PUT /admin/training/courses/{id}/questions | API Reference chỉ có Manager POST /attempts với score. |
| Training review | GET pending, POST approve, POST not-complete | API Reference không liệt kê. |
| Document catalog | GET /employees/me/documents/catalog | API Reference không liệt kê. |
| Violation explanation | GET/POST /employees/me/violations/{id}/explanations | API Reference không liệt kê. |
| Device approval | DEVICE_APPROVE ở controller | Service còn kiểm tra STAFF_REVIEW và cấm tự duyệt. |
| Payroll | Permission bị áp ở class, method và service | API Reference chỉ nêu một quyền/role cho một số action, không mô tả toàn bộ guard kết hợp. |

## Giới hạn kết luận

Flutter và backend đã được audit ở ref case1; working tree case2 vẫn giữ nguyên và chỉ dùng so sánh lịch sử. Không chạy backend, frontend, test, OpenAPI hoặc SSMS; API/runtime chưa được nghiệm thu. Master V3.0 chính thức chưa có trong checkout. Xem API_SCREEN_PERMISSION_MATRIX.md cho ánh xạ API chi tiết, BUSINESS_GAP_ANALYSIS.md cho gap end-to-end, EXISTING_WORKFLOW_MAP.md cho flow source và IMPLEMENTATION_PROGRESS.md cho trạng thái Phase 0.

Thiết kế điều hướng/flow/trạng thái đích và các phát hiện liên kết sâu hơn nằm tại [ARCHITECTURE_WORKFLOW_REVIEW.md](ARCHITECTURE_WORKFLOW_REVIEW.md).
