# HRM Coffee Shop V3.0 — Tiến độ review kiến trúc và Phase 0

> **Cập nhật triển khai 04/11/2026:** yêu cầu đã chuyển từ audit sang hoàn thiện project. Backend/Flutter hiện có thay đổi và kiểm thử runtime; xem [IMPLEMENTATION_LOG.md](IMPLEMENTATION_LOG.md), [IMPLEMENTED_FLOW_MATRIX.md](IMPLEMENTED_FLOW_MATRIX.md) và [VERIFICATION.md](VERIFICATION.md). Phần dưới giữ nguyên bản ghi Phase 0, không mô tả trạng thái hiện tại.

## Trạng thái

**Static source review đã mở rộng sang Flutter và backend cùng ref case1/c889df1.** Bản đánh giá trước chỉ đọc Flutter case2 đã bỏ sót Flutter API-backed ở case1; các báo cáo đã được sửa phạm vi.

Working tree vẫn case2/0af31cb. Không checkout/merge/commit; chỉ cập nhật tài liệu. Không chạy app/backend/test/OpenAPI hoặc SQL Server trong lượt này. Chưa có Master chính thức được phê duyệt trong checkout; không tuyên bố nghiệm thu V3.0.

## Snapshot và inventory

| Phạm vi | Bằng chứng | Kết quả |
|---|---|---|
| Snapshot đầy đủ | case1/c889df14360cb583d49c6364f2bdca5d610bf13c | Cả lib/test và backend có source. |
| Checkout hiện tại | case2/0af31cb547580157e57d04f6dec039a8a229c7cc | Là tổ tiên case1; Flutter demo cũ, không đại diện bản đầy đủ. |
| Flutter | 84 file Dart, 48 page files, 25 test Dart | Auth/API/screens ba role và HR task workspace đã có; cần hoàn thiện guard/state/linkage. |
| Backend | 259 Java gồm 42 test; 46 controllers, 45 entities, 45 repositories, 44 services; 1 pom và 4 SQL | Nhiều domain rules/transition/permission có source; chưa nghiệm thu runtime. |
| Tài liệu | API Reference ngoài checkout; Draft V3 trong hội thoại | Reference thiếu các endpoint mới; Master file chính thức chưa có. |
| Source riêng tư/local | .env/data/artifact không dùng làm bằng chứng | Không đọc bí mật hoặc dùng artifact để khẳng định behavior. |

## Công việc đã hoàn thành trong review

- Đối chiếu source backend Controller/DTO/Service/Security/entity/SQL/test.
- So sánh toàn bộ lib/test giữa case2 và case1; đọc Flutter case1 router/auth/client/repos/dashboard/navigation, camera/GPS, requests/training/documents/approvals/notifications/payroll và tests inventory.
- Xác định auth thật, raw upload và check-in/out đã có trong case1; không còn kết luận mọi Flutter flow là demo.
- Phát hiện source gaps: router guard/bootstrap, HR workspace, device binding, explanation thiếu giờ/đường vào khi chưa có công, OT dùng một ngày, formatter mismatch, queue permissions/failure isolation, notification/blocker drill-down và cross-domain links.
- Hiệu chỉnh payroll permission: method-level PreAuthorize thay cùng annotation class-level; action guard khác với quyền đọc list/readiness.
- Hoàn thiện thiết kế navigation theo ba role, flow/state catalogue, dashboard orchestration, linkage/invalidation matrix và decision register.

## Deliverables

### Báo cáo source đã cập nhật

1. [SOURCE_AUDIT.md](SOURCE_AUDIT.md)
2. [BUSINESS_GAP_ANALYSIS.md](BUSINESS_GAP_ANALYSIS.md)
3. [API_SCREEN_PERMISSION_MATRIX.md](API_SCREEN_PERMISSION_MATRIX.md)
4. [EXISTING_WORKFLOW_MAP.md](EXISTING_WORKFLOW_MAP.md)

### Thiết kế để chốt triển khai

1. [ARCHITECTURE_WORKFLOW_REVIEW.md](ARCHITECTURE_WORKFLOW_REVIEW.md) — entry point: đánh giá, vấn đề ưu tiên, navigation ba role, dashboard và lộ trình.
2. [END_TO_END_WORKFLOWS_AND_STATES.md](END_TO_END_WORKFLOWS_AND_STATES.md) — flow thực tế/đích, public state catalog và acceptance.
3. [BUSINESS_LINKAGE_MATRIX.md](BUSINESS_LINKAGE_MATRIX.md) — liên kết nghiệp vụ, refresh, blockers/deep links và contract gaps.
4. [BUSINESS_DECISION_REGISTER.md](BUSINESS_DECISION_REGISTER.md) — định hướng đã có, quyết định cần bổ sung và đề xuất cụ thể.

## Công việc tiếp theo theo phụ thuộc

1. Chốt baseline source/schema/API và scope ba workspace chính.
2. Chuẩn hóa session/router/capability từ code đã có.
3. Khép các flow thiếu dữ liệu hiện có contract: explanation time/schedule entry, OT đủ ngày, trạng thái/403 và queue permission.
4. Chốt device binding, final approver, adjustment grouping, violation/penalty/payroll scope trước phần backend phụ thuộc.
5. Hoàn thiện notification/blocker resolver và refresh liên module.
6. Nghiệm thu từng flow trên app với backend/SQL Server thật; test camera/GPS/two-device/retry/permissions theo scope nền tảng.

Các mục trên là kế hoạch/thiết kế; chưa triển khai thay đổi source nghiệp vụ/API/DB/UI trong review này.
