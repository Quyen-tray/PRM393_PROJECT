# HRM Coffee Shop — Sổ quyết định nghiệp vụ

**Baseline:** Flutter và backend case1/c889df1; checkout case2/0af31cb là snapshot cũ.  
**Trạng thái tài liệu:** đề xuất để chủ dự án chốt, chưa phê duyệt thay đổi backend/API/database.

Các quyết định có thể đóng bằng một lựa chọn rõ và tiêu chí nghiệm thu. Không cần trả lời toàn bộ cùng lúc; ưu tiên các mục P0 trước khi triển khai phần phụ thuộc.

## 1. Định hướng đã có trong phiên

| Mã | Định hướng | Cách ghi vào baseline |
|---|---|---|
| FIX-01 | Ba role chính của navigation: EMPLOYEE, STORE_MANAGER, SYSTEM_ADMIN | Ba workspace chính; nhóm quyền HR là tác vụ được cấp, không tạo HR role. User nhiều role vẫn đổi workspace. |
| FIX-02 | Giữ điều kiện đạt khóa học; đào tạo chưa hoàn thành không chặn phân ca/check-in | Giữ passScore/kết quả backend. TrainingService.eligibility hiện true phù hợp định hướng này. Không thêm gate ở Flutter. |
| FIX-03 | Có flow Admin/Manager xác nhận hoàn thành đào tạo cho employee | Source non-quiz review từ enrollment có thể dùng. Flow quiz và trường hợp manual được ghi riêng; không coi enroll là PASSED. |
| FIX-04 | Admin có thể lấy GPS để lưu vị trí quán; Employee chấm công theo vị trí đó | Case1 đã có source UI/API wiring; nghiệm thu đo/lưu/tải lại/check-in thật. |
| FIX-05 | Dùng SQL Server trong môi trường người dùng quản lý bằng SSMS | Chốt schema/migration/seed trên SQL Server hiện có; cơ chế Testcontainers trong test source không đồng nghĩa phải đổi database phát triển sang Docker. |
| FIX-06 | Các hành vi thật phải có backend xác nhận và nút quay lại hợp lý | Giữ response thật, không mock success; route/back stack và refresh liên module là acceptance bắt buộc. |

Các mục FIX không được mở lại thành điều kiện mới chỉ vì refactor navigation.

## 2. Quyết định P0 — ảnh hưởng đến toàn luồng

| Mã | Hiện trạng / vấn đề cần chốt | Đề xuất cụ thể | Ảnh hưởng nếu chọn | Trạng thái |
|---|---|---|---|---|
| DEC-01 | Working tree case2 cũ; case1 chứa cả Flutter/backend mới. Master chính thức chưa có | Dùng case1/c889df1 làm baseline đánh giá/triển khai kế tiếp sau khi đối chiếu thay đổi người dùng; lưu một bộ commit + schema + API contract. Đưa bản yêu cầu đã chốt vào Master riêng | Tránh đánh giá thiếu/sửa lại chức năng đã tồn tại. Không tự checkout/merge/commit trong review | Cần chốt baseline triển khai |
| DEC-02 | Flutter đang có HR workspace thứ tư; backend có OPERATIONS_DIRECTOR, User.primaryRole đã map sang Manager | Giữ ba workspace chính theo FIX-01; /hr thành alias/module “Tác vụ được giao”. Giữ role OPERATIONS_DIRECTOR trong backend cho tới khi có quyết định migration, trình bày bằng Manager shell và quyền thực tế | Thay navigation/resolver; không xóa role/quyền hoặc tự cấp Admin cho director/HR | Cần chính thức hóa |
| DEC-03 | Bước cuối adjustment/payroll cần người có HR permissions; action permission đôi khi thiếu quyền đọc queue/detail | Chỉ định tài khoản thuộc ba role được giao ATTENDANCE_ADJUST_HR, PAYROLL_FINALIZE...; công bố bundle đọc/action tối thiểu. HR tasks truy cập được từ mọi shell phù hợp, không tự cấp STORE_MANAGER | Đảm bảo có người nhận bước cuối và không gặp flow có quyền duyệt nhưng không xem được hồ sơ | Cần chốt người chịu trách nhiệm và policy quyền |
| DEC-04 | Source cấm nhiều trường hợp tự duyệt; adjustment không bắt hai reviewer khác nhau | Giữ no-self-review; xác định có bắt Manager reviewer khác final reviewer hay không. Khuyến nghị tách hai người ở kỳ công/điều chỉnh nhạy cảm; thiếu người thì dùng người thay thế được cấp quyền rõ | Nếu bắt khác người cần backend validation + test; không giải quyết bằng ẩn nút hoặc admin bypass | Cần chốt phân tách nhiệm vụ |
| DEC-05 | Source thiết kế một quán; current store là active đầu tiên | Giữ một quán cho scope hiện tại. Nếu cần nhiều chi nhánh phải đặc tả store scope ở session/query/entity/permission trước | Multi-store là thay đổi scope/contract, không chỉ thêm dropdown | Cần ghi phạm vi chính thức |
| DEC-16 | Source payroll hỗ trợ readiness/chốt công; chưa thấy payslip, công thức lương, line items, apply quyết định tiền | Nghiệm thu hiện tại dưới tên “Kỳ công / đối soát”. Tách dự án tính lương tiền thành scope riêng nếu cần; định nghĩa earnings/deductions/tax/export trước khi thêm màn bảng lương | Tránh báo đã trả/trừ lương chỉ từ approval hoặc LOCKED | Cần chốt phạm vi payroll |
| DEC-17 | Quy tắc source là một ACTIVE và chặn PENDING trùng. Flutter chọn ACTIVE đầu tiên; request không chứng minh máy đang dùng là máy được duyệt | Chốt “duyệt thiết bị” phải ràng buộc cài đặt/thiết bị thực hay chỉ là duyệt record. Khuyến nghị ràng buộc installation/device credential ở mỗi attendance request; không dùng deviceId công khai như bằng chứng duy nhất | Cần proposal contract/security binding; phải nghiệm thu trên hai thiết bị/cài đặt khác nhau. Pending race cần integration verification | Cần chốt semantics và cơ chế binding |
| DEC-18 | Có GPS/photo API thật; face adapter NOT_RUN; đăng ký device chỉ ANDROID/IOS | Scope attendance hiện tại là GPS + ảnh bằng chứng trên Android/iOS. Admin/Manager có thể dùng web/desktop theo plugin/API. Chỉ mở Windows/Web attendance đầy đủ khi device-registration contract hỗ trợ; chỉ gọi nhận diện khuôn mặt khi có adapter thật | Nhãn UI, supported platform, camera/GPS error flow và acceptance rõ | Cần chốt nền tảng và mức xác minh |

## 3. Quyết định P1 — hoàn thiện từng chuỗi nghiệp vụ

| Mã | Hiện trạng | Quyết định cần có và đề xuất | Ảnh hưởng / dependency |
|---|---|---|---|
| DEC-06 | Ca qua đêm có source; assignment tạo PUBLISHED ngay; DRAFT/COMPLETED có schema nhưng chưa thấy publish/complete action | Chốt giới hạn thời lượng ca, tính ngày công và có cần draft/publish riêng không. Đề xuất dùng flow publish trực tiếp đang có cho demo; luôn hiển thị planned start/end đầy đủ ngày. Không tự đặt giới hạn giờ mới | Schedule UI, overlap/time-window, overnight tests; chỉ thêm publish API khi có quy trình thật |
| DEC-07 | OT yêu cầu start >= plannedEnd, end > start, max-minutes source default 240, không trùng pending/approved | Chốt chính sách OT qua ngày, giới hạn áp dụng, thời điểm được gửi và xử lý khi kỳ khóa. Dùng timestamp đủ ngày; không suy end date từ giờ | OT form/validation và payroll metrics; giá trị chính sách phải do chủ dự án chốt |
| DEC-08 | Training không chặn nhận ca/check-in; quiz pass theo threshold | Giữ FIX-02. Chốt cách trình bày training requirement: tiến độ bắt buộc về đào tạo nhưng không phải gate ca. Không dùng nhãn “không đủ điều kiện nhận ca” chỉ vì chưa học | Dashboard/profile/training labels; không cần đổi API để khôi phục gate |
| DEC-09 | Non-quiz review queue tự lấy enrollment chưa có pass còn hiệu lực, kể cả chưa có employee completion signal | Với flow đơn giản đã yêu cầu, đề xuất giữ review từ enrollment và gọi đúng “Chờ đánh giá/xác nhận đào tạo”. Nếu muốn Employee tự báo hoàn thành trước review, chọn thêm submit-completion + PENDING_REVIEW contract. Chốt course inactive còn được review hay archive | Quyết định có cần API mới; queue/count/status/notifications phải thống nhất với lựa chọn |
| DEC-10 | Manager có manual score API; failed quiz có thể làm lại, chưa thấy giới hạn attempt | Chốt có cho manual score đối với course quiz hay chỉ nguồn ngoại lệ tin cậy; ai được phép, có lý do/audit. Chốt retake/cooldown/attempt limits nếu cần; không tự áp số lượt mặc định | Quyền TRAINING_MANAGE, AttemptRequest, test và lịch sử kết quả |
| DEC-11 | Course có description/questions; question replacement xóa/thay bank; attempt chỉ giữ điểm/lượt/source | Chốt phạm vi đào tạo: catalog + quiz/manual review hay cần lesson/media/progress. Nếu cần chứng cứ học/thi, lưu version/snapshot câu hỏi và answers, đọc lại attempt | Có thể cần entity/API mới; không thể tái hiện bài thi cũ chỉ từ điểm tổng |
| DEC-12 | Violation confirm độc lập penalty; DecisionRequest chưa nhận/lưu violationEventId | Đề xuất action “Tạo đề xuất phạt từ vi phạm” giữ liên kết nguồn bắt buộc khi khởi tạo từ violation, vẫn review riêng. Chốt một violation có được nhiều decision/replacement không. Không auto trừ tiền | Request/validation/link history và chống tạo lặp; full payroll phụ thuộc DEC-16 |
| DEC-13 | Sửa công tính lại metrics nhưng không tự xử lý violation/decision đã sinh | Đề xuất tạo tác vụ rà soát hậu quả cho reviewer khi sửa làm thay đổi late/early leave/OT; giữ lịch sử. Không tự xóa quyết định đã duyệt. Chốt cách hủy/điều chỉnh nếu đã áp dụng | Orchestration và audit xuyên domain; phụ thuộc quyền và policy tài chính |
| DEC-14 | Adjustment đổi hai giờ tạo hai request; có thể duyệt riêng; note/timeline chưa đầy đủ DTO | Chốt đơn vị nghiệp vụ: từng field riêng hay một hồ sơ sửa công atomic. Đề xuất hồ sơ atomic nếu hai giờ là một đề xuất chung; nếu giữ source, UI/count ghi rõ từng giờ. Cần reviewer, time, note từng bước trong detail | Group/transaction/state/history contract; không group bằng timestamp heuristic |
| DEC-15 | Manager nextActions xếp theo count; counts khác đơn vị; chưa có SLA chính thức | Đề xuất thứ tự theo ảnh hưởng tác nghiệp và hạn: công hiện tại → quá hạn → blocker kỳ → chờ review; sau đó theo thời gian tạo. Chốt thời hạn/nhắc/escalation cụ thể trước khi gán urgency số | Dashboard task projection, queue sorting, reminders, counts đúng đơn vị |
| DEC-19 | Document catalog chặn pending hoặc approved còn hiệu lực, cho nộp mới sau reject/expiry | Giữ re-submit theo catalog. Chốt có cho gia hạn sớm trước expiry và thay file đã duyệt không; đề xuất tạo bản nộp mới, không sửa lịch sử đã duyệt. Chốt effective date của requirement mới | Document version/history, profile completeness, deadline/notification |
| DEC-20 | Checklist rejected được start lại; template used có version; reassign giữ run hiện tại; chưa có waiver action | Giữ rework đã có. Chốt reassign có giữ phần hoàn thành/evidence người cũ hay reset phần nào; có cho miễn/waive không và ai có quyền. Không thêm nút WAIVED chỉ từ schema | Task ownership, evidence history, completion/violation rules |
| DEC-21 | Explanation có thể sửa/tạo công qua Manager; adjustment sửa công qua hai bước | Chốt ranh giới dùng hai loại để tránh route bypass quy trình. Đề xuất explanation cho mất khả năng ghi nhận/không có công, adjustment cho sửa giờ đã ghi; backend cũng phải áp policy nếu cần hạn chế | Form chooser, service validation và review authority; không chỉ chặn UI |
| DEC-22 | Inbox có list/read; tap chỉ mark-read. Một số target không GET-by-id, decision ID có hai dạng | Đề xuất typed target resolver + detail reload; cần canonical object identity/context. Chốt notify ai/lúc nào cho device/document/training submission/review; push là kênh bổ sung, không nguồn sự thật | Detail API/metadata tối thiểu, notification templates, refresh/404/403 và back stack |
| DEC-23 | Cấu hình/chức vụ/course/template active và effective dates tác động dữ liệu đang có theo cách khác nhau | Chốt thay đổi áp dụng ngay hay cho assignment/enrollment mới. Đề xuất giữ snapshot lịch sử/attempt/run; requirement/profile hiện hành được tính theo effective date đã công bố | Policy versioning, training deactivation, pending task handling và migration |
| DEC-24 | Evidence retention có cấu hình; scan/face/push dùng adapter chưa thực hiện dịch vụ thật | Chốt adapter bắt buộc cho môi trường triển khai và quyền xem/tải evidence. Giữ hạn/format theo contract hiện hành cho tới khi có quyết định mới | Cấu hình triển khai, UI labels và acceptance; không coi source test/mock gateway là dịch vụ thật |

## 4. Quyết định kỹ thuật và nghiệm thu cần ghi thành baseline

| Mã | Nội dung đề xuất | Điều kiện hoàn thành |
|---|---|---|
| TECH-01 | Dùng NavigationRegistry + SessionController; role chọn shell, permission/state quyết định action | Direct URL, refresh, token hết hạn, user đổi quyền và multi-role đều có hành vi kiểm thử được. |
| TECH-02 | Tách EmployeeRepository theo domain dần; giữ lớp compatibility khi refactor | Không đổi contract hoặc tự tạo dữ liệu fallback; repository có typed DTO/pagination/error.code. |
| TECH-03 | Chuẩn hóa trạng thái theo public DTO và các trục riêng | Các giá trị UNDER_REVIEW/RESTRICTED/REVIEW_REQUIRED/FINALIZED/unknown không bị hiển thị sai; mapping có test phù hợp. |
| TECH-04 | UI work queue tải từng nguồn theo capability và isolate lỗi | Một queue 403/5xx không làm mất các queue người dùng được phép đọc. |
| TECH-05 | Read-after-write + invalidation theo ma trận nghiệp vụ | Chuyển màn/reload vẫn phản ánh kết quả; không chỉ đổi local widget state. |
| TECH-06 | Nghiệm thu scope deploy được chọn bằng backend/SQL Server thật | Có nguồn commit/schema rõ; thao tác Employee/Manager/Admin qua app persist sau restart; kiểm tra negative permissions, double-submit, timeout và camera/GPS. |
| TECH-07 | Không dùng hiện diện của Demo* enum/file hoặc mock test làm bằng chứng dữ liệu nghiệp vụ giả/thật | Kiểm tra call site, HTTP request và response. Case1 không tìm thấy call site DemoData.; test doubles chỉ phục vụ test. |
| TECH-08 | Hoàn thiện explanation requested times và entry từ ca chưa có attendance; OT nhập start/end đủ ngày | Dùng DTO/backend hiện có, không cần quyết định API mới. Manager approve giải trình thiếu công tạo được giờ được đề xuất; OT qua đêm gửi đúng hai thời điểm. |
| TECH-09 | Xác định nền tảng demo/triển khai và kiểm tra plugin OAuth/camera/GPS/secure storage theo từng target | Có thư mục Windows/Web/iOS/Android chưa đủ chứng minh chạy được; Employee device registration hiện chỉ ANDROID/IOS. Không công bố native Windows attendance/login hoàn chỉnh trước khi nghiệm thu. |

## 5. Cách chốt và theo dõi

Mỗi quyết định cần lưu: mã, lựa chọn được duyệt, người chốt, ngày hiệu lực, lý do, tài liệu/API/schema ảnh hưởng và acceptance tương ứng. Các phương án chưa chọn giữ trạng thái đề xuất.

Thứ tự chốt đề xuất:

1. DEC-01/02/03/04/05/16/17/18 để xác định baseline, quyền, scope cửa hàng, kỳ công và thiết bị.
2. DEC-09/12/13/14/21/22 để nối các điểm đứt end-to-end.
3. DEC-06/07/10/11/15/19/20/23/24 để hoàn thiện policy, lịch sử, dashboard và vận hành.

Định hướng đã có ở phần FIX được đưa vào Master khi chủ dự án chốt baseline; không yêu cầu xác nhận lại trong lúc hoàn thiện tài liệu này.
