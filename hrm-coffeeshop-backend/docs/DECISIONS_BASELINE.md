# Quyết định nghiệp vụ baseline

Các quyết định này là căn cứ triển khai Sprint 3. Mã trong backlog (B-20, B-21, B-22 của bản quyết định) được đặt tên lại thành DEC-PDF, DEC-OT, DEC-ABS để tránh trùng với mã task kỹ thuật B-xx.

## DEC-PDF — Hồ sơ HR chấp nhận PDF

| Định dạng | Quyết định |
|---|---|
| PDF | Chấp nhận (chỉ purpose `DOCUMENT`) |
| JPEG, PNG, WebP | Chấp nhận |
| DOC, DOCX, XLS, XLSX, khác | Từ chối |

Triển khai:
- Nhận dạng theo chữ ký đầu tệp (`common/FileSignature`). PDF phải bắt đầu bằng `%PDF-`.
- Content-Type khai báo, nếu có và không phải `application/octet-stream`, phải khớp định dạng thật.
- Giới hạn: hồ sơ HR 10 MB (`app.storage.max-document-bytes`). Ảnh chấm công và checklist vẫn 8 MB.
- Khóa lưu trữ do server sinh, phần mở rộng lấy từ chữ ký thật, không từ client.
- `GET /storage/view` trả `application/pdf` cho tệp `.pdf`, vẫn yêu cầu chữ ký HMAC và hạn.
- Điểm mở rộng quét mã độc: interface `UploadScanner`, mặc định `NoopUploadScanner` (chưa quét). **Phải thay trước production.**

Lưu ý: PDF có rác trước `%PDF-` bị từ chối. Đây là lựa chọn chặt hơn spec PDF.

## DEC-OT — OT chỉ tính sau khi ca kết thúc

- Điều kiện: `requestedStartAt >= shift.plannedEndAt`, `requestedEndAt > requestedStartAt`, thời lượng không vượt giới hạn.
- Hàm `OvertimeService.requireValidInterval` là nguồn duy nhất cho quy tắc này, có unit test `OvertimeIntervalTest` khớp bảng quyết định.
- Mốc so sánh là `plannedEndAt`, không phải giờ check-out thực tế. OT thực tế vẫn đối chiếu với attendance khi duyệt.
- OT tạo ra luôn ở trạng thái PENDING, không tự động được duyệt hay tính lương.
- Overlap và concurrency: đã xử lý ở B-02 (khóa dòng phân ca).

**Chưa chốt:** giới hạn thời lượng OT. Mặc định tạm 240 phút (`app.overtime.max-minutes`). Cần chủ dự án xác nhận con số này.

## DEC-ABS — Vắng mặt phải có đơn ABSENCE được quản lý duyệt

Quy trình:

1. Ca đã kết thúc, không có Attendance hợp lệ.
2. Quản lý gọi `POST /payroll-periods/{periodId}/absence-requests`: hệ thống tạo đơn `ABSENCE` PENDING cho từng ca như vậy (bỏ qua ca đã có đơn PENDING/APPROVED; đơn REJECTED được tạo lại).
3. Quản lý duyệt qua endpoint giải trình. APPROVED: ghi nhận vắng mặt, không ghi bản ghi công. REJECTED: không kết luận vắng mặt.
4. Readiness chặn theo trạng thái đơn mới nhất của ca.

| Tình huống | Chặn finalize? | Blocker |
|---|---|---|
| Có Attendance hợp lệ | Không (nếu các điều kiện khác đạt) | — |
| Không có Attendance, chưa có đơn ABSENCE | Có | `MISSING_ABSENCE_REQUEST` |
| ABSENCE đang chờ duyệt | Có | `PENDING_ABSENCE` |
| ABSENCE bị từ chối | Có, cho đến khi xử lý | `REJECTED_ABSENCE` |
| ABSENCE đã duyệt | Không | — |

Lưu ý:
- ABSENCE APPROVED không đồng nghĩa nghỉ có lương. Cách tính lương theo loại vắng mặt thuộc chính sách payroll, chưa đặc tả trong tài liệu này.
- Đơn ABSENCE không còn bị đếm trong `unresolvedAttendanceExceptions`, để tránh chặn hai lần.
- Người duyệt, thời gian duyệt và lý do được lưu trên đơn. Mỗi thao tác tạo/duyệt có bản ghi audit.

## Việc còn lại liên quan đến quyết định

- Chốt giới hạn thời lượng OT (DEC-OT).
- Chốt chính sách lương cho vắng mặt đã duyệt (DEC-ABS).
- Cập nhật SRS và API contract theo ba quyết định trên.
- Thay `NoopUploadScanner` bằng bộ quét thật trước production.
- Viết IT cho quy trình ABSENCE (tạo, duyệt, từ chối, readiness) và cho upload PDF. Chưa có trong bản này.
