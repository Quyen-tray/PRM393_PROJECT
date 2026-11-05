# HRM Coffee Shop V3.0 — Existing Workflow Map

> Workflow map này thuộc snapshot trước triển khai. Luồng hiện đã tích hợp được mô tả tại [IMPLEMENTED_FLOW_MATRIX.md](IMPLEMENTED_FLOW_MATRIX.md), với bằng chứng chạy app tại [VERIFICATION.md](VERIFICATION.md).

## Baseline

Luồng hiện hữu dưới đây đọc từ **Flutter và backend case1/c889df1**. Working tree vẫn ở case2/0af31cb, là phiên bản Flutter cũ còn demo. Không dùng flow demo case2 để kết luận flow case1 thiếu.

Chỉ xác minh source, không chạy app/API/test/SQL Server. Một flow có wiring source vẫn cần nghiệm thu runtime. Flow đích/trạng thái chi tiết ở [END_TO_END_WORKFLOWS_AND_STATES.md](END_TO_END_WORKFLOWS_AND_STATES.md).

## 1. Authentication và workspace source hiện tại

1. GoRouter initialLocation là /login.
2. LoginPage đọc access token từ secure storage; nếu có, gọi current user và permissions.
3. Google login lấy ID token, POST /auth/google, lưu access/refresh token.
4. ApiClient thêm Bearer và refresh single-flight khi nhận 401; có PUT/PATCH/DELETE/raw upload.
5. workspaceOptionsFor dựng Admin, Manager, Employee theo roles và HR workspace theo một nhóm permission. Employee option disabled nếu chưa có employee link.
6. Một option hợp lệ thì đi thẳng; nhiều option thì /select-workspace với User truyền qua state.extra.
7. Logout gọi API, xóa token và sign out Google.

Source chưa có guard/redirect tập trung trong app_router; / vẫn build ManagerDashboardPage. Reload/direct route có thể bỏ qua bootstrap ở Login; route /select-workspace thiếu extra sẽ build Login. Refresh thất bại xóa token nhưng không có session stream điều phối toàn router.

User.primaryRole đã map OPERATIONS_DIRECTOR thành Manager. HR là permission set ở backend nhưng UI hiện là workspace riêng; thiết kế ba workspace chính cần điều chỉnh nhóm này.

## 2. Route/module hiện có

| Module | Route source case1 / cách mở |
|---|---|
| Employee tổng quan/lịch | /employee; /employee/schedule |
| Employee công/checklist | /attendance/check-in; /employee/attendance-history; /employee/checklist |
| Employee học/hồ sơ | /employee/training; /employee/profile; /employee/documents |
| Employee vi phạm/thưởng/thông báo | /employee/violations; /employee/rewards; /employee/notifications |
| Manager tổng quan/nhân viên | /; /manager/employees; /manager/employees/:employeeCode; /edit |
| Manager lịch | /manager/schedule; /manager/schedule/work-shifts |
| Manager duyệt | /manager/approvals; /manager/devices; /manager/attendance-requests; /manager/checklists/approvals; /manager/training/completions; /manager/documents |
| Manager vi phạm/kỳ công/báo cáo | /manager/violations; /manager/rewards; /manager/payroll; /manager/reports/attendance; /manager/reports/operations |
| Admin | /admin; /admin/accounts; user permissions/employee create; /admin/positions; /admin/document-types; /admin/training; question editor/completions; checklist templates; settings; skills; audit logs; notification deliveries |
| HR task UI | /hr; /hr/attendance-adjustments; các module Manager được dùng lại |
| Auth/profile | /login; /register; /select-workspace; /profile |
| Detail/editor phụ | Một số mở bằng Navigator/MaterialPageRoute hoặc modal sheet/dialog, không có route độc lập trong GoRouter |

Parameter employeeCode của route detail/edit thực tế nhận employeeId dạng chuỗi từ roster. Cần chuẩn hóa tên/type; không kết luận UI đang gọi API bằng mã nghiệp vụ.

## 3. Check-in source thật

Employee dashboard → EmployeeCheckInPage → Future.wait current shift/devices/store → GPS → CameraCapturePage → raw-byte upload → storageKey → check-in/out API → success message → Employee home.

Có kiểm tra GPS/accuracy/radius từ store API, active/pending devices, đăng ký Android/iOS, polling 20 giây và resume refresh. Camera có lifecycle và thử lens/resolution; không có fake delayed success trong flow case1 đã đọc. Retry key giữ trong widget state khi network/5xx, chưa giữ qua restart.

Gap quan trọng: _activeDevice chọn ACTIVE record đầu tiên của employee; DeviceView không có binding installation. CheckInRequest chỉ gửi deviceId và backend kiểm owner/status. Source hiện chưa chứng minh request đến từ đúng máy vật lý được duyệt.

## 4. Luồng Manager/Admin đã nối API

- Manager dashboard đọc overview/attendance/current user/access, dùng pending/nextActions.
- Roster/detail/edit, schedule create/patch/cancel, work shifts, reports đều gọi EmployeeRepository.
- Approval hub gom explanation/adjustment/OT/checklist/device bằng 14 request Future.wait. Action gọi endpoint đúng loại rồi reload.
- Device pending có approve/reject, sheet lịch sử theo employee và revoke; có polling/resume.
- Checklist/Document/Training completion/Violation/Reward/Payroll có page riêng, request thật và loading/action/error state.
- Admin accounts/roles/permissions, positions/requirements, courses/questions, checklist version/editor, settings/GPS/reminder, skills, audit/delivery có UI và repository API calls.
- Admin dashboard tổng hợp accounts/store/courses/templates; account count bị giới hạn scan 100 trang x 50.

Các hạn chế: capability chưa thống nhất giữa route/menu/action; một nguồn 403 có thể làm lỗi cả Future.wait; Manager dashboard HR queue route null; page state/refresh/back chủ yếu cục bộ.

## 5. Công việc Employee đã nối API

- Schedule tải assignment/detail/eligibility.
- Checklist tải task/item/evidence, start/complete/submit và reload.
- Training catalog/enroll/requirements/skills, quiz page và result gọi API; quiz mở qua Navigator, Admin có question editor.
- Documents trong AccountProfile có catalog/upload/submit/history; reviewer có pending/detail/view/approve/reject.
- Violations/explanations và rewards history có page/API.
- Attendance history có explanation/adjustment/OT forms và request lists.
- Notifications có list/pagination/read/read-all; NotificationRepository normalize type thành notificationType.

Không tìm thấy call site DemoData. trong lib case1. Một số enum Demo* được dùng như model hiển thị; điều đó không chứng minh dữ liệu mẫu đang thay API.

## 6. Các điểm đứt end-to-end đã xác định

| Điểm | Hành vi source / tác động |
|---|---|
| Explanation thiếu công | Form chỉ mở từ attendance row; createExplanation không có requestedCheckInAt/out. Backend approve cần giờ đề xuất khi tạo/hoàn thiện công. Thiếu entry từ ca chưa có attendance và thiếu input thời gian. |
| OT qua đêm | Backend nhận OffsetDateTime đủ ngày, UI dùng cùng một date cho start/end; không thể biểu diễn khoảng qua nửa đêm đúng ý. |
| Adjustment | Backend tạo một row mỗi field; UI form gửi hai field nhưng timeline/note từng reviewer không có đầy đủ DTO; form dùng ISO text. |
| Training manual queue | Tất cả enrollment non-quiz chưa pass còn hiệu lực có thể review; không employee submit signal. Đây là flow đơn giản đang có, không phải nhân viên đã báo hoàn thành. |
| Dashboard → queue | Một số quyền không được lọc, HR adjustment không có route đích, training chưa có trong summary. |
| Notification → entity | onTap chỉ markRead; chưa dùng relatedEntityType/Id mở hồ sơ. Một số entity thiếu GET-by-id/canonical decision ID. |
| Payroll blocker → hồ sơ | UI mới label/count; không drill-down theo type/sample IDs. |
| Violation → penalty | DecisionRequest/create chưa lưu violationEventId; penalty approval chưa phải APPLIED vào lương. |
| Correction → hậu quả | Attendance recompute không tự rà soát violation/decision; cần policy và liên kết review. |
| Status labels | Formatter chưa map các giá trị API đã có như UNDER_REVIEW/EXPIRED/RESTRICTED và một số public attendance states. |
| Scope chốt công | Có periods/readiness/lock; chưa thấy payslip/calculation/line items hoặc producer APPLIED. |
| Push/face/scan | Adapter source là Logging/Noop; in-app record không chứng minh push/face verification/malware scanning thực tế. |

## 7. Backend state flow và tests

Controller/DTO/Service xác minh các chuỗi: device registration/review → attendance; explanation/OT; adjustment Manager → HR; checklist rework; quiz pass/manual completion; documents review; violation review; periods/readiness/confirm/finalize/reopen. Xem [API_SCREEN_PERMISSION_MATRIX.md](API_SCREEN_PERMISSION_MATRIX.md) và catalog state để tránh nhầm DB/API enums.

Có 25 test Dart và 42 test Java source. Flutter widget_test là login smoke test, không còn counter test. Các test chưa chạy trong lượt audit; mocks không được dùng để kết luận endpoint live hoạt động.

Bản thiết kế role/navigation/dashboard và thứ tự hoàn thiện ở [ARCHITECTURE_WORKFLOW_REVIEW.md](ARCHITECTURE_WORKFLOW_REVIEW.md).
