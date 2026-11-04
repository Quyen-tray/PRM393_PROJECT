# Luồng và ma trận tích hợp đang triển khai

**Ngày đối chiếu: 04/11/2026.** Tài liệu này mô tả source trong workspace đã hoàn thiện ở phiên hiện tại. Backend được khôi phục từ ZIP local rồi chỉnh sửa bằng filesystem; không checkout, add, commit hay chạy lệnh Git. Các báo cáo Phase 0 ở cùng thư mục là snapshot lịch sử, không thay cho tài liệu này.

## 1. Kiến trúc và điều hướng

Entry point phát hành là `lib/main.dart` → `BeanHubApp` → router → `AppShell`. `SessionController` nạp `/users/me` và `/users/me/permissions`; role chọn các workspace được phép, permission quyết định module/action. Quyền không được suy ra từ màu giao diện hoặc một role khác.

| Workspace | Điều hướng mobile | Nhóm chức năng |
|---|---|---|
| EMPLOYEE | Tổng quan, Lịch làm, Công việc, Cá nhân | Ca/check-in, công cá nhân, checklist, đào tạo, giấy tờ, thiết bị, yêu cầu, vi phạm, thưởng/phạt, thông báo |
| STORE_MANAGER | Tổng quan, Nhân viên, Lịch ca, Duyệt, Khác | Nhân sự, phân ca, công, thiết bị, các hàng đợi duyệt, báo cáo, kỳ công theo quyền |
| SYSTEM_ADMIN | Tổng quan, Tài khoản, Tác vụ, Quản trị | Tài khoản/quyền, danh mục, yêu cầu theo chức vụ, cửa hàng/chính sách, audit/delivery; tác vụ nghiệp vụ cần grant tương ứng |

Desktop dùng sidebar cuộn được. Người có nhiều role đổi workspace; không tạo role HR. Một Employee được cấp `DOCUMENT_REVIEW`, `ATTENDANCE_ADJUST_HR` hoặc `DEVICE_APPROVE` thấy các tác vụ tương ứng mà không được cấp ngầm `STORE_MANAGER`. Các route cũ được giữ dưới dạng alias khi có chức năng tương đương. Route bị cấm giữ URL và hiển thị 403. Quyền thay đổi trên cùng URL được đánh giá lại.

Form, lookup, camera nằm trên root navigator, có quay lại. Dashboard/check-in tải lại khi quay về; các thao tác thành công tăng revision để các màn liên quan lấy lại dữ liệu. Form giữ nội dung khi API từ chối; không báo thành công trước response backend.

## 2. Ma trận màn hình – API – quyền – dữ liệu

Prefix API trong bảng là `/api/v1`. Các màn dùng `OperationsRepository`/`resourceProvider`/`operationProvider`; chấm công có `AttendanceController`, phiên có `SessionController` và `AuthenticatedApi`. Form và các nút ghi không gọi HTTP trực tiếp rải rác trong widget.

| Nhóm | Route/màn hình | API chính | Guard và phạm vi | Backend/dữ liệu |
|---|---|---|---|---|
| Phiên | `/login`, `/workspaces`, `/profile` | POST auth/google, refresh, logout; GET users/me, users/me/permissions; PATCH users/me | Public login/refresh; các API khác cần JWT; cập nhật profile của chính mình | SharedAuthController/UserService/AuthService; AppUser, UserRole, UserPermission, RefreshToken |
| Dashboard | `/`, `/tasks` | GET dashboard/employee/overview, attendance/me/current, dashboard/manager/overview, dashboard/admin/overview, dashboard/tasks | Employee liên kết; DASHBOARD_MANAGER; SYSTEM_ADMIN; work queue lọc theo grant | DashboardService, WorkboardController; dữ liệu thật, không KPI giả |
| Lịch | `/module/my-schedule`, `/module/assignments`, `/module/shifts`, `/record/.../:id` | GET work-shifts, shift-assignments/me, assignment detail/eligibility; POST/PUT work-shifts; POST/PATCH/cancel assignments | Lịch cá nhân theo owner; phân ca STORE_MANAGER; danh mục ca Manager/Admin | ShiftService; WorkShift, ShiftAssignment; eligibility giữ yêu cầu hồ sơ/chính sách hiện có |
| Chấm công | `/attendance/check-in`, `/module/my-attendance`, detail/verifications | GET attendance/me/current, stores/current, devices/current; POST storage/uploads; POST check-in/check-out; GET attendance/me/detail/verifications | Owner; ACTIVE installation, thời gian, GPS, ảnh và kỳ công theo service | AttendanceService/DeviceService; Attendance, AttendanceVerification, AttendanceDevice, PayrollPeriod |
| Thiết bị | `/module/my-devices`, `/module/devices`, detail | POST register; GET me/current; GET devices với status/q/employeeId; GET per-employee/detail; POST approve/reject/revoke | Cá nhân; quản lý cần DEVICE_APPROVE, không yêu cầu thêm role Manager cho cùng capability | DeviceService; AttendanceDevice. Chỉ trả metadata, không trả hash/credential |
| Giải trình công | `/module/my-explanations`, `/module/explanations`; form từ ca/công | POST attendance[/id]/explanation-requests; GET mine/list/detail; POST approve/reject | Employee owner; reviewer STORE_MANAGER; no-self-review và validation giờ | AttendanceExceptionService; AttendanceExceptionRequest, Attendance, verifications |
| Điều chỉnh | `/module/my-adjustments`, `/module/adjustments`; detail từ thông báo/blocker | POST adjustment-requests; GET mine/list/detail; POST manager-approve/reject, hr-approve/reject | Bước Manager đúng role; bước cuối ATTENDANCE_ADJUST_HR. Quyền bước cuối đọc được queue/detail/công liên quan | AttendanceAdjustmentService; request theo từng CHECK_IN/CHECK_OUT, history; áp dụng cuối cùng mới đổi công |
| Tăng ca | `/module/my-overtime`, `/module/overtime`; form từ công | POST attendance/:id/overtime-requests; GET mine/list/detail; POST approve/reject | Owner và STORE_MANAGER; giữ policy OT đang có | OvertimeService; OvertimeRequest, ShiftAssignment, Attendance |
| Checklist | `/module/my-checklists`, `/module/checklists`, `/module/checklist-reviews`, `/module/templates` | GET mine/tasks/detail; POST generate/start/item complete/evidence/submit/reassign/approve/reject; template GET/POST/PUT/activate | Owner thực hiện; CHECKLIST_VIEW/REVIEW đọc; STORE_MANAGER duyệt/giao; SYSTEM_ADMIN sửa mẫu | ChecklistService; template/item/task/run item/evidence, snapshot của task |
| Đào tạo | `/module/training`, `/quiz/:courseId`, `/record/enrollments/:id`, `/module/training-reviews`, `/module/courses` | GET courses/me/requirements/quiz/attempt history/enrollment; POST enroll/quiz-attempts; GET/PUT questions admin; review pending/detail/approve/not-complete | Owner học/nộp bài; SYSTEM_ADMIN quản trị; TRAINING_MANAGE hoặc Admin xác nhận non-quiz; manual score riêng cần TRAINING_MANAGE | TrainingService/TrainingQuizService; TrainingCourse, EmployeeTraining, TrainingQuestion, TrainingAttempt |
| Giấy tờ | `/module/my-documents`, `/module/documents`, document detail, hồ sơ nhân viên | GET employee catalog/history; raw upload DOCUMENT; POST submit; GET detail; POST approve/reject | Owner nộp; DOCUMENT_REVIEW xem/duyệt/nộp thay; danh mục admin SYSTEM_ADMIN | DocumentService/JobPositionService; EmployeeDocument, DocumentType, requirements theo chức vụ |
| Vi phạm | `/module/my-violations`, `/module/violations`, detail | GET mine/list/detail/explanations; POST explanation/confirm/dismiss | Owner giải trình; VIOLATION_REVIEW xử lý; critical giữ kiểm tra authority riêng | ViolationService/ViolationExplanationService; ViolationEvent, ViolationExplanation; không tự khấu trừ tiền |
| Thưởng/phạt | `/module/my-rewards`, `/module/decisions`, detail | GET mine/list/detail/rule-catalog; POST proposal/approve/reject/cancel | REWARD_PROPOSE, REWARD_VIEW, REWARD_APPROVE; severity/amount/no-self-review trong service | RewardPenaltyService; EmployeeRewardPenalty, RuleCatalog, liên kết violationEventId khi có |
| Nhân viên/kỹ năng | `/module/employees`, employee detail/form, `/module/skills` | GET employees/detail/overview/training/skills/documents/devices; POST/PATCH employee/status; GET linkable-users/job-positions; POST skill assessments | EMPLOYEE_VIEW/MANAGE, TRAINING_MANAGE, DOCUMENT_REVIEW/DEVICE_APPROVE cho từng phần; không dùng danh mục Admin khi grant nghiệp vụ đã đủ | EmployeeService/SkillService/JobPositionService; Employee, AppUser, SkillAssessment, JobPosition |
| Kỳ công | `/module/payroll`, period detail/readiness/blocker | GET periods/readiness; POST create/manager-confirm/absence-requests/hr-finalize/reopen | PAYROLL_VIEW đọc; PAYROLL_PERIOD_MANAGE tạo; STORE_MANAGER xác nhận; PAYROLL_FINALIZE chốt; PAYROLL_REOPEN mở lại; stage/ngày/blocker do backend kiểm tra | PayrollService/PayrollLockGuard; PayrollPeriod, công và các đơn liên quan |
| Báo cáo | `/module/reports-attendance`, `/module/reports-operations`; payroll detail | GET reports/attendance, reports/operations, readiness | DASHBOARD_MANAGER cho báo cáo; PAYROLL_VIEW cho readiness | DashboardService/PayrollService; dữ liệu API, không biểu đồ giả |
| Tài khoản/quyền | `/module/accounts`, account detail | GET/POST admin/users; PUT roles/permissions; GET permission-catalog/current grants; PATCH status | SYSTEM_ADMIN; service giữ giới hạn và danh mục quyền | UserService; AppUser, UserRole, UserPermission |
| Cấu hình | `/module/positions`, `/module/document-types`, `/module/store-settings`, `/module/reminder-rules`, `/module/skills` | CRUD job positions, document/training requirements, document types, store settings/policies, reminder rules, skills | SYSTEM_ADMIN theo Controller; skill reads có thể được dùng bởi người đăng nhập | StoreService/JobPositionService/DocumentService/SkillService; bảng danh mục và policy |
| Thông báo/audit | `/module/notifications`, `/module/audit`, `/module/deliveries` | GET notification list/unread; POST read/read-all; GET audit/detail/CSV, deliveries | Thông báo của chính user; SYSTEM_ADMIN audit/deliveries | NotificationService/AuditService; typed entity identity, signed file access audit |

Inventory từng method/endpoint/DTO/Controller/service/annotation: [API_INVENTORY_IMPLEMENTED.md](API_INVENTORY_IMPLEMENTED.md). Alias `/payroll/periods`, checklist aliases và các endpoint tổng hợp không cần màn hình trùng lặp chỉ để gọi một API khác.

## 3. Các chuỗi nghiệp vụ

### Cửa hàng → thiết bị → chấm công

Admin mở Cửa hàng và chính sách → lấy GPS tại quán → xem lại tọa độ/bán kính → lưu. Employee mở chấm công dù còn blocker → đăng ký đúng installation → thấy PENDING. Người có DEVICE_APPROVE mở quản lý thiết bị → duyệt → Employee tải lại → GPS → camera → xem lại ảnh → upload → GPS mới ngay trước POST → server xác nhận → lịch sử công/verifications. Check-out đi qua cùng các bước với attendanceId.

Idempotency key và body của thao tác đang chờ được lưu theo user. Retry khi chưa rõ kết quả dùng cùng key; không tạo thao tác mới chỉ vì timeout. Một deviceId đã duyệt không đủ để chứng minh bản cài đặt; mỗi request còn gửi `X-Device-Credential` từ secure storage.

### Đào tạo

Admin tạo khóa/nội dung, nếu có quiz thì cấu hình câu hỏi và đáp án. Employee đăng ký. Quiz lấy câu hỏi không kèm đáp án đúng → gửi đáp án → backend tính điểm so với passScore → lưu attempt/snapshot → trả PASSED/FAILED. Non-quiz vào hàng đợi xác nhận; Manager có TRAINING_MANAGE hoặc Admin xác nhận hoàn thành/chưa hoàn thành. Enroll không phải PASSED. Đào tạo chưa hoàn thành không chặn phân ca/check-in.

### Yêu cầu công → đối soát

Giải trình và OT có endpoint/transition riêng. Điều chỉnh công tách từng trường: PENDING_MANAGER → Manager approve → PENDING_HR → người có ATTENDANCE_ADJUST_HR approve → APPROVED và áp dụng vào công. Reject kết thúc trường yêu cầu tương ứng. UI có nhân viên/ngày làm, giờ cũ/đề nghị, trạng thái hai bước và đường mở công liên quan.

Kỳ công lấy readiness và blocker IDs từ backend. Manager xác nhận trước; bước cuối chỉ mở khi periodStatus=HR_REVIEW, kỳ đã kết thúc và không còn blocker. FINALIZED là trạng thái DTO của kỳ DB LOCKED; không đồng nghĩa đã tính/trả lương tiền. Không cho nút HR finalize xuất hiện chỉ vì `canFinalize` báo không có blocker trong một kỳ DRAFT.

### Checklist/hồ sơ/vi phạm

Checklist: template → generate/giao → start → từng mục/minh chứng → submit → tự hoàn tất hoặc chờ Manager theo cấu hình template → approve/reject/làm lại theo service. Giấy tờ: catalog áp dụng → chọn file → upload → submit → PENDING → reviewer approve/reject → lịch sử/nhắc nộp lại. Vi phạm: sự kiện OPEN → Employee giải trình → reviewer xem/confirm/dismiss → quyết định PENALTY riêng khi cần, không khấu trừ tự động.

## 4. Trạng thái và liên kết cần giữ

| Nghiệp vụ | Nguồn trạng thái | Chú ý |
|---|---|---|
| Ca | assignment status + plannedStartAt/plannedEndAt | Hiển thị đủ hai ngày với ca qua đêm |
| Công | attendanceStatus, kết quả công, payrollStatus | CHECKED_OUT không có nghĩa ON_TIME hoặc LOCKED |
| Điều chỉnh | managerStatus, hrStatus, status tổng hợp | Manager approve còn chờ bước cuối; badge đếm theo trường yêu cầu |
| Vi phạm | DTO OPEN/CONFIRMED/DISMISSED/RESOLVED | DB lần lượt PENDING/APPROVED/REJECTED/APPLIED |
| Quyết định | PENDING_APPROVAL/APPROVED/REJECTED/CANCELLED | PENDING_APPROVAL là mapping DTO của DB PENDING |
| Đào tạo | NOT_STARTED/IN_PROGRESS/FAILED/PASSED và expiry | Giữ điểm, hạn, reviewer; không lấy việc mở màn hình làm hoàn thành |
| Hồ sơ | reviewStatus và hạn giấy tờ | Trạng thái duyệt khác tình trạng hồ sơ tổng hợp |
| Kỳ công | DTO status, readiness status, periodStatus DB | Đánh giá đúng bước Manager/HR và điều kiện thời gian |
| Thông báo | readAt và deliveryStatus | Đã đọc khác đã gửi push; gateway chưa cấu hình không báo SENT |

Enum chưa biết được giữ nguyên để nhận ra thay đổi contract. Notification resolver dùng entityType + entityId; không suy đoán ID bằng tiêu đề. Blocker mở đúng entity; 403/404 hiển thị rõ. Mutations thành công làm mới dashboard, queue, detail, unread count và các màn liên quan khi được mở lại.

## 5. Quyết định chưa tự bổ sung

Giữ [BUSINESS_DECISION_REGISTER.md](BUSINESS_DECISION_REGISTER.md) cho giới hạn thời lượng ca, chính sách OT/retake/device, phân tách người duyệt, scope đa cửa hàng, ảnh hưởng thay đổi policy lên lịch sử, xử lý vi phạm sau điều chỉnh công, công thức lương và kênh push/face/scanner. Các giá trị/chính sách đang có trong source được giữ; không đặt thêm quy tắc để làm demo dễ đạt.
