# HRM Coffee Shop — Test coverage và trạng thái kiểm chứng

Trạng thái mã nguồn được đối chiếu với thư mục `src/test` trong gói backend v4.
**Quan trọng:** các test đã được viết nhưng chưa được chạy trong môi trường hiện tại vì không có Maven và Docker/SQL Server Testcontainers.

| TC | Nội dung | Test hiện có | Trạng thái mã |
|---|---|---|---|
| TC21 | Hai check-in đồng thời cùng ca | `CheckInRaceIT` | Đã viết, chưa chạy |
| TC22 | Hai OT overlap đồng thời | `OvertimeRulesIT` | Đã viết, chưa chạy |
| TC23 | OT giao ca / khoảng không hợp lệ | `OvertimeRulesIT`, `OvertimeIntervalTest` | Đã viết, chưa chạy |
| TC24 | Ca kết thúc không chấm công chặn payroll đến khi ABSENCE được duyệt | `AbsenceWorkflowIT`, `PayrollLockIT` | Đã viết, chưa chạy |
| TC25 | Sửa/hủy/tạo/chuyển ca thuộc kỳ đã khóa | `ScheduleLockIT`, `PayrollLockIT` | Đã viết, chưa chạy |
| TC26 | Evidence của nhân viên khác | `ChecklistEvidenceKeysTest`, `EvidenceKeysTest` | Đã viết |
| TC27 | Submit document với storage key không tồn tại | `DocumentSubmitIT` | Đã viết, chưa chạy |
| TC28 | HR upload hồ sơ thay nhân viên | `HrUploadAndAccessIT.hrUploadsPdfOnBehalfOfEmployee` | Đã viết, chưa chạy |
| TC29 | Nhân viên xem hồ sơ của nhân viên khác → 403 | `HrUploadAndAccessIT.employeeCannotViewAnotherEmployeesDocument` | Đã viết, chưa chạy |
| TC30 | Hai kỳ công trùng ngày đồng thời | `PayrollPeriodCreateConcurrencyIT` | Đã viết, chưa chạy |
| TC31 | Upload vượt dung lượng / sai chữ ký file | `FileSignatureTest`, `UploadSizeLimitIT` | Đã viết, chưa chạy |
| TC32 | Không có token → 401 | `UnauthenticatedAccessIT.requestWithoutTokenIsUnauthorized` | Đã viết, chưa chạy |
| TC33 | Có token nhưng thiếu quyền → 403 | `UnauthenticatedAccessIT.authenticatedUserWithoutPermissionGetsForbidden` | Đã viết, chưa chạy |
| TC34 | Nhiều 401 đồng thời chỉ refresh một lần | Flutter F-06 | Chưa làm; ngoài phạm vi backend |
| TC35 | Evidence sai employeeId | `ChecklistEvidenceKeysTest` | Đã viết |
| TC36 | Khóa/gỡ System Admin cuối cùng | `LastAdminGuardIT` | Đã viết, chưa chạy |

## Test bổ sung đã viết trong đợt tiếp tục backend

- `UploadSizeLimitIT`: upload ATTENDANCE lớn hơn 8 MB bị từ chối trước khi lưu.
- `SignedFileAccessAuditIT`: truy cập file hợp lệ, file không tồn tại, chữ ký sai/hết hạn và path traversal; kiểm tra trạng thái audit, actor claim và correlation ID.
- `NotificationDispatcherJobTest`: atomic claim thua cuộc không gửi push, gửi thành công chuyển SENT, retry đến lần thứ 5 chuyển FAILED, push exception giữ PENDING để retry.
- `CorrelationIdFilterTest`: giữ correlation ID hợp lệ, thay ID không an toàn, trả ID qua response và dọn MDC.

## Còn thiếu trước release

- Kiểm chứng transaction boundary ở mức integration/transaction manager: không mở transaction DB trong lúc gửi mạng (source hiện chia claim/send/update thành ba bước).
- Test 403 theo từng nhóm endpoint nhạy cảm, ngoài test đại diện TC33.
- Load/concurrency test có đo latency trên SQL Server có dữ liệu gần thực tế.

## Cách chạy

Yêu cầu JDK 17+, Maven 3.9+ và Docker đang hoạt động:

```bash
mvn test
./scripts/run-integration-tests.sh
```

`run-integration-tests.sh` hiện chạy toàn bộ 17 lớp integration qua Testcontainers SQL Server. Sau đó chạy toàn bộ verify nếu môi trường cho phép:

```bash
mvn -B verify
```

Không đánh dấu test là PASS chỉ vì source test đã tồn tại.
