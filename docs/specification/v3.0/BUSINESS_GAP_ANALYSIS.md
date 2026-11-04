# HRM Coffee Shop V3.0 — Business Gap Analysis

> Đây là gap analysis trước triển khai. Các gap đã xử lý và giới hạn còn lại của source hiện tại được đối chiếu tại [IMPLEMENTATION_LOG.md](IMPLEMENTATION_LOG.md), [IMPLEMENTED_FLOW_MATRIX.md](IMPLEMENTED_FLOW_MATRIX.md) và [VERIFICATION.md](VERIFICATION.md).

## Baseline mở rộng

Đã đọc Flutter và backend cùng ref case1/c889df1. Working tree case2/0af31cb là tổ tiên, còn UI demo cũ; không dùng trạng thái case2 để kết luận case1 thiếu screen/API integration.

Case1 có 84 file Dart, 48 file page, 25 file Dart test; backend có 259 file Java gồm 42 test Java. Chỉ review source, chưa chạy app/API/test/SQL Server. Master chính thức chưa có trong checkout.

“Đã có” dưới đây nghĩa có triển khai/wiring trong source, không đồng nghĩa đã nghiệm thu runtime. “Có một phần” chỉ ra điểm đứt cụ thể; “Có nhưng sai lệch” là mapping/semantics cần sửa; “Chưa có” là capability chưa tìm thấy; “Chưa đủ bằng chứng” cần kiểm tra runtime hoặc quyết định nghiệp vụ.

| Chức năng | Source backend + Flutter case1 | Phân loại | Gap cần xử lý |
|---|---|---|---|
| Google auth/secure tokens/refresh/logout | AuthRepository, ApiClient và LoginPage đã nối API thật | Đã có trong source | Chưa có nghiệm thu live OAuth/refresh trong lượt này. |
| Session/router guard | Bootstrap nằm trong Login, router tĩnh; role-selection cần User trong extra | Có một phần | Direct URL/reload/mất phiên/quyền đổi chưa có resolver tập trung. |
| Ba role chính/multi-role | User/WorkspaceOptions có Admin/Manager/Employee; HR thêm workspace theo permission; director map Manager | Có một phần | Cần tổ chức HR thành nhóm tác vụ trong ba workspace theo yêu cầu, giữ access permission-only và aliases. |
| Data/repositories/state | Auth/Employee/Checklist/Notification repositories có thật | Có một phần | EmployeeRepository khoảng 1.886 dòng nhiều domain; Map/dynamic; business state và reload chủ yếu trong widget. |
| Không dùng dữ liệu giả | Không tìm thấy call site DemoData. trong lib case1; còn Demo* enums | Đã có bằng chứng tĩnh | Không suy dữ liệu fake từ tên enum/file; cần request runtime để nghiệm thu dữ liệu thật. |
| Employee dashboard/schedule/profile | Screen/routes và repository calls có | Đã có trong source | Nâng task orchestration, shared shell, refresh và mapping trạng thái. |
| Check-in/out GPS/photo/upload | Current/store/device API, CameraCapturePage, upload và submit thật; poll/resume; key trong state | Có một phần | Binding thiết bị, retry qua restart, camera/GPS/device live cần hoàn thiện/verify. |
| Device binding | Frontend chọn ACTIVE record đầu tiên; server requireActive kiểm deviceId/employee/status | Có nhưng sai lệch với kỳ vọng khóa đúng máy | Chưa ràng buộc request với installation đang dùng; DeviceView không cung cấp đối chiếu, không có proof trong attendance request. Cần chốt semantics. |
| Device management | Pending approve/reject, history theo employee và revoke có API/UI | Có một phần | Quyền DEVICE_APPROVE + STAFF_REVIEW; duyệt lịch sử từ pending chưa thành inventory độc lập; no GET-by-id/global status query. |
| Store GPS configuration | Admin settings có xin GPS/lưu tọa độ; Employee đọc /stores/current | Đã có trong source | Cần nghiệm thu Admin → Employee trên thiết bị; không cần xây lại endpoint. |
| Explanation khi thiếu chấm công | Backend nhận requestedCheckInAt/out và scheduleId; Flutter form/repo chỉ gửi reason/code/IDs | Có một phần, gap P0 | Không có entry từ lịch khi chưa có attendance; không gửi giờ đề xuất để approve tạo/hoàn thiện công. Có thể submit nhưng reviewer không tạo được giờ mong muốn. |
| Adjustment hai bước | Employee form, Manager review, HR adjustments UI và backend có | Có một phần | Hai field thành hai request; note/timeline thiếu DTO; form còn yêu cầu nhập ISO text; chưa có refresh graph chung. |
| OT qua đêm | Backend dùng timestamps đủ ngày; Flutter form dùng một date cho cả start/end | Có nhưng sai lệch | Không nhập được OT bắt đầu hôm trước kết thúc hôm sau; cần hai ngày/thời điểm rõ. |
| Manager approval hub | API-backed adapters và actions có | Có một phần | Future.wait 14 nguồn; không lọc từng queue theo quyền, một lỗi có thể làm hỏng toàn hub; count thường là page-level. |
| Checklist template/task/review/rework | Versioning, Employee tasks/evidence/submit, Manager review, Admin editors đều có | Đã có trong source | Chốt reassign partial work/waiver; kiểm tra state/back/reload và history. |
| Training/quiz/manual review | Course/questions/enroll/quiz/review screens và APIs có | Đã có trong source | Manual queue là enrollment chưa pass, không employee submit; manual score route và attempt history policy cần chốt. |
| Training không chặn ca | eligibility hiện true, requirements/progress vẫn có | Đã có trong source | Phù hợp định hướng đã có trong phiên; không tái thêm gate ở UI. |
| Documents catalog/submit/review | EmployeeDocumentsTab, reviewer/admin requirements và APIs có | Đã có trong source | Nộp lại/renewal theo catalog; profile formatter đang thiếu UNDER_REVIEW/EXPIRED. |
| Violation explanation/review | Employee/Manager screens + explanation API có | Đã có trong source | Controller VIOLATION_REVIEW còn phụ thuộc REWARD_APPROVE/CRITICAL trong service, cần policy quyền rõ. |
| Violation → penalty | Entity có ViolationEventId nhưng DecisionRequest/create chưa ghi | Chưa có liên kết end-to-end | Cần source link/idempotency/history nếu tạo phạt từ violation; không tự phạt theo violation confirmed. |
| Sửa công → rà soát violation/decision | Metrics recompute; chưa thấy reconciliation trong adjustment/exception service | Chưa có orchestration | Cần task review hậu quả; không tự xóa quyết định tiền/kỷ luật. |
| Payroll periods/readiness/confirm/finalize/reopen | ManagerPayroll UI/API có, có check stage/date/canFinalize | Đã có trong source | Blockers mới label/count, chưa drill-down; phân biệt action permission và quyền đọc queue. |
| Tính lương tiền/apply quyết định | Chưa thấy payslip/line items/calculation/APPLIED producer | Chưa có trong phạm vi source | Chốt scope: kỳ công hiện có hay salary product bổ sung. |
| Dashboard Manager | API pending/nextActions thật; Flutter đã dùng | Có một phần | HR adjustment route null; filter chủ yếu documents; thiếu training entry và priority policy. |
| Dashboard Admin | Có UI tổng hợp store/accounts/courses/templates APIs | Có một phần | Count accounts scan tối đa 5.000; không có backend Admin overview; một số giải thích UI suy quyền theo role cần capability thực tế. |
| Notifications | List/pagination/read/read-all và type normalization có | Có một phần | Tap chỉ mark-read; chưa mở related entity; một số entity chưa GET-by-id/canonical target. |
| Trạng thái chuẩn | Các domain có DB→API mapping; formatter dùng một phần | Có nhưng sai lệch | UNDER_REVIEW, EXPIRED, RESTRICTED và public attendance states chưa map đầy đủ; unknown training bị gán “Chưa ghi danh”. |
| Error handling | ApiClient intercept refresh, envelope validation và HTTP/details có | Có một phần | Mất error.code; 403 bị thay message chung, mất lý do no-self/state/authority hữu ích; session loss chưa điều phối router. |
| Navigation/back/responsive | Bottom nav riêng theo role, nhiều back buttons, một số width constraints có | Có một phần | go() resets parent context; modal/Navigator detail không có route tải độc lập; state.extra không bền qua reload. |
| Upload/storage/permissions | Raw bytes/signed view; Android main INTERNET và iOS usage descriptions đã có | Đã có trong source | Malware scanner/face/push adapters chưa có dịch vụ thật; signed URL retry và platform acceptance cần kiểm tra. |
| Test quality | 25 Dart và 42 Java test sources, gồm nhiều flow HRM | Chưa đủ bằng chứng runtime | Chưa chạy; mocks/widget tests không chứng minh backend hoạt động; cần E2E thực trên SQL Server/thiết bị. |
| Master/API docs/schema baseline | API Reference thiếu endpoint mới; Master chính thức chưa có | Chưa đủ bằng chứng/phần tài liệu sai lệch | Chốt baseline đồng nhất; không bắt upload lại source đã có trong case1. |

## Chi tiết guard payroll đã hiệu chỉnh

PreAuthorize ở method thay thế cùng annotation ở class; service checks vẫn áp dụng. Theo [Spring Security Method Security](https://docs.spring.io/spring-security/reference/servlet/authorization/method-security.html):

- Create: class PAYROLL_VIEW và service PAYROLL_PERIOD_MANAGE.
- Manager confirm: class PAYROLL_VIEW và service STORE_MANAGER.
- HR finalize: class PAYROLL_VIEW và service PAYROLL_FINALIZE.
- Reopen POST: method/service PAYROLL_REOPEN; để mở list/readiness UI còn cần PAYROLL_VIEW.
- Sinh ABSENCE POST: method/service STORE_MANAGER; list/readiness UI còn cần PAYROLL_VIEW.

Không tự AND hai PreAuthorize class/method cùng loại. Capability end-to-end phải tính cả quyền đọc và action, nhưng ghi rõ nguồn từng yêu cầu.

## Các contract thiếu cần đánh giá có điều kiện

- GET-by-id/lookup cho explanation, OT, device, decision hoặc review enrollment khi cần detail/deep link bền qua reload.
- Canonical target cho EmployeeRewardPenalty numeric notification ID và decision ID có prefix.
- Adjustment group/atomic/history chỉ nếu chọn mô hình một hồ sơ cho nhiều field.
- Employee completion-submit chỉ nếu chọn flow tự báo hoàn thành; review từ enrollment đã có và phù hợp yêu cầu đơn giản trước đó.
- Violation link trong DecisionRequest/create và reconciliation sau sửa công nếu sản phẩm yêu cầu chuỗi khép kín.
- Blocker drill-down/paging và training/permission-aware dashboard projection.
- Quiz attempt snapshot/detail và salary API chỉ khi scope được chốt.

Xem [ARCHITECTURE_WORKFLOW_REVIEW.md](ARCHITECTURE_WORKFLOW_REVIEW.md) cho kiến trúc đích, [BUSINESS_LINKAGE_MATRIX.md](BUSINESS_LINKAGE_MATRIX.md) cho ma trận liên kết và [BUSINESS_DECISION_REGISTER.md](BUSINESS_DECISION_REGISTER.md) cho đề xuất quyết định.
