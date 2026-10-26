

**ĐẶC TẢ NGHIỆP VỤ**  
**HỆ THỐNG HRM COFFEE SHOP**

**SRS  •  ERD LOGIC  •  API DOCUMENTATION**

| Thông tin | Giá trị |
| :---- | :---- |
| Phiên bản | 2.0 – Phạm vi một cửa hàng cà phê |
| Ngày lập | 13/10/2026 |
| Nền tảng dữ liệu | Microsoft SQL Server |
| Định hướng | UX liền mạch, quy trình có kiểm soát, lưu vết đầy đủ |
| Trạng thái | Bản thiết kế đề xuất – cần đối chiếu DDL hiện tại trước khi triển khai |

*Tài liệu hợp nhất phạm vi nghiệp vụ, quy tắc, dữ liệu, API, phân quyền và kiểm thử nghiệm thu.*

# **MỤC LỤC**

* 1\. Tổng quan và phạm vi  
* 2\. Actor, vai trò và ma trận quyền  
* 3\. Quy trình nghiệp vụ đầu-cuối  
* 4\. Quy tắc nghiệp vụ chi tiết  
* 5\. Yêu cầu chức năng (SRS)  
* 6\. Yêu cầu phi chức năng và UX  
* 7\. ERD logic và thiết kế dữ liệu  
* 8\. API contract dùng chung  
* 9\. Danh mục API theo module  
* 10\. Dashboard, báo cáo và chỉ số  
* 11\. Bảo mật, quyền riêng tư và lưu trữ  
* 12\. State machine và xử lý lỗi  
* 13\. Kiểm thử nghiệm thu  
* 14\. Quyết định cần chốt trước khi phát triển  
* Phụ lục A. Mã lỗi chuẩn  
* Phụ lục B. JSON mẫu

Ghi chú: Mục lục là danh sách điều hướng thủ công. Có thể cập nhật bằng cách tạo Table of Contents tự động trong Microsoft Word nếu cần.

# **1\. Tổng quan và phạm vi**

## **1.1. Mục tiêu**

Xây dựng hệ thống HRM vận hành cho một cửa hàng cà phê duy nhất. Hệ thống quản lý nhân viên, hồ sơ theo chức vụ, đào tạo bắt buộc, lịch và phân ca, chấm công có xác minh, checklist đầu/cuối ca, vi phạm, thưởng/phạt, nhắc nhở và đối soát công trước khi chốt lương.

## **1.2. Phạm vi triển khai**

* Chỉ một cửa hàng vật lý trong phạm vi vận hành; không triển khai nghiệp vụ chuỗi cửa hàng hoặc điều chuyển giữa nhiều cửa hàng.  
* Ứng dụng dành cho System Admin, Store Manager và Employee. HR là tập quyền nghiệp vụ có thể gán cho người dùng được ủy quyền; không bắt buộc tạo actor nghiệp vụ thứ tư.  
* Đăng nhập Google, đăng xuất, hồ sơ cá nhân và kiểm soát quyền.  
* Check-in/check-out bằng GPS, định danh thiết bị, ảnh xác minh và cơ chế chống giả mạo theo giải pháp được chọn.  
* Đăng ký/đổi thiết bị có phê duyệt; xử lý ngoại lệ khi GPS không khả dụng.  
* Hồ sơ nhân viên theo chức vụ; LMS/đào tạo và kỹ năng; hạn chế phân ca khi thiếu yêu cầu bắt buộc.  
* Dashboard chấm công, trạng thái hồ sơ/đào tạo, đi muộn, vi phạm, thưởng/phạt và checklist.  
* Checklist vận hành đầu/cuối ca, nộp minh chứng và quy trình duyệt.  
* Thông báo trước hạn, nhắc quá hạn, audit log, báo cáo và đối soát công.

## **1.3. Ngoài phạm vi**

* Quản lý nhiều chi nhánh, luân chuyển nhân viên giữa cửa hàng.  
* Tính lương đầy đủ, thuế, bảo hiểm hoặc chuyển khoản ngân hàng; phạm vi hiện tại tập trung dữ liệu công và mức sẵn sàng chốt công.  
* Tự động phạt tiền hoặc khấu trừ lương chỉ dựa trên sự kiện chưa được xác minh.  
* Nhận diện khuôn mặt/anti-spoofing cụ thể trước khi chọn nhà cung cấp, đánh giá pháp lý và thử nghiệm.

## **1.4. Giả định**

Múi giờ vận hành mặc định là Asia/Ho\_Chi\_Minh. Mọi thời điểm lưu trữ và hiển thị cần có quy ước nhất quán. Các giá trị cấu hình mặc định chỉ là đề xuất ban đầu, có thể thay đổi bởi người có quyền.

# **2\. Actor, vai trò và ma trận quyền**

| Actor / nhóm quyền | Trách nhiệm chính | Giới hạn |
| :---- | :---- | :---- |
| System Admin | Quản lý cấu hình cửa hàng, chính sách, chức vụ, loại hồ sơ, khóa học, checklist template, tài khoản/quyền và audit. | Không mặc nhiên được duyệt mọi nghiệp vụ nhân sự nếu không được gán permission tương ứng. |
| Store Manager | Lập lịch, phân ca, xem tình trạng cửa hàng, xử lý ngoại lệ chấm công, duyệt checklist, xem dashboard và đề xuất/duyệt nghiệp vụ theo thẩm quyền. | Chỉ trong phạm vi dữ liệu được phân quyền; xem ảnh xác minh nhưng không tải xuống theo chính sách mặc định. |
| Employee | Xem lịch cá nhân, chấm công, đăng ký thiết bị, nộp hồ sơ, học khóa bắt buộc, thực hiện checklist và gửi giải trình. | Chỉ xem dữ liệu cá nhân và tài nguyên được giao; không tự duyệt yêu cầu của mình. |
| HR permission set | Rà soát hồ sơ, điều chỉnh/chốt công, đối soát kỳ công, truy cập ảnh theo quyền đặc biệt. | Là tập quyền được cấp cho người dùng được ủy quyền; cần audit mọi truy cập dữ liệu nhạy cảm. |
| Operations Director / approver | Duyệt quyết định thưởng/phạt nghiêm trọng hoặc ngoại lệ theo chính sách. | Chỉ cấp quyền khi có nhu cầu và thẩm quyền đã xác nhận. |

## **2.1. Nguyên tắc phân quyền**

* Áp dụng least privilege: chỉ cấp quyền tối thiểu cần cho công việc.  
* Backend là nơi quyết định quyền; không tin role hoặc employeeId do client tự khai báo.  
* Nhân viên không được duyệt yêu cầu của chính mình.  
* Quản lý trực tiếp có thể xem ảnh xác minh theo quyền nhưng mặc định không được tải; HR/Quản lý cấp cao chỉ được xem/tải khi được cấp quyền cụ thể và có audit.  
* Mọi thao tác phê duyệt quan trọng phải lưu người thực hiện, thời điểm, quyết định, lý do và giá trị trước/sau nếu có.

# **3\. Quy trình nghiệp vụ đầu-cuối**

## **3.1. Đăng nhập và khởi tạo phiên**

1. Người dùng đăng nhập bằng Google; backend xác minh ID token, issuer, audience, expiry và trạng thái tài khoản.  
2. Hệ thống ánh xạ tài khoản với hồ sơ nhân viên và permission hiệu lực.  
3. Ứng dụng tải cấu hình, hồ sơ cá nhân, lịch gần nhất, checklist đến hạn và thông báo chưa đọc.  
4. Nếu tài khoản chưa được gán quyền hoặc bị khóa, hệ thống không cho truy cập nghiệp vụ và hiển thị hướng dẫn liên hệ quản trị.

## **3.2. Đăng ký thiết bị**

5. Nhân viên đăng ký thiết bị đang dùng; backend tạo yêu cầu ở trạng thái PENDING.  
6. Trong thời gian chờ duyệt, thiết bị mới không được dùng để chấm công.  
7. Manager/HR được cấp quyền kiểm tra và duyệt/từ chối kèm lý do.  
8. Khi kích hoạt thiết bị mới, backend bảo đảm chỉ có một thiết bị ACTIVE cho mỗi nhân viên; chính sách xử lý thiết bị cũ phải được thực hiện nguyên tử.  
9. Thiết bị bị mất hoặc nghi ngờ bị lạm dụng cần được khóa/thu hồi và lưu audit.

## **3.3. Check-in**

10. Ứng dụng tải ca hiện tại và kiểm tra sơ bộ điều kiện: tài khoản hoạt động, thiết bị được duyệt, ca hợp lệ, đào tạo bắt buộc còn hiệu lực.  
11. Ứng dụng yêu cầu quyền vị trí và camera. Nếu người dùng từ chối camera, quy trình check-in chuẩn bị từ chối và hiển thị hướng dẫn.  
12. Ứng dụng thu tọa độ, độ chính xác, thời điểm đo; chụp ảnh xác minh và bắt đầu phiên kiểm tra liveness/face verification nếu được cấu hình.  
13. Backend kiểm tra bán kính, sai số GPS, cửa sổ thời gian, thiết bị, bằng chứng và chống gửi lặp.  
14. Nếu hợp lệ, tạo bản ghi check-in và trả trạng thái. Nếu không có GPS, cho phép tạo yêu cầu giải trình theo quy trình riêng, không âm thầm coi là check-in hợp lệ.  
15. Nếu camera hỏng, chỉ dùng QR tĩnh/Wi-Fi nội bộ như phương án ngoại lệ đã được phê duyệt; lưu phương thức xác minh và người duyệt.

## **3.4. Check-out và OT**

16. Nhân viên thực hiện xác minh theo yêu cầu tại check-out, tương tự check-in.  
17. Hệ thống ghi thời điểm ra và tính thời lượng hiện diện/làm việc theo chính sách.  
18. Thời gian ra muộn không tự động trở thành OT được thanh toán; OT cần yêu cầu/phê duyệt theo quy trình.  
19. Nếu quên check-out, nhân viên tạo đơn điều chỉnh kèm lý do/minh chứng; quản lý duyệt bước nghiệp vụ, HR duyệt tổng hợp trước khi chốt công.

## **3.5. Hồ sơ và đào tạo**

20. Mỗi chức vụ có bộ hồ sơ bắt buộc và khóa học/kỹ năng bắt buộc có hiệu lực theo thời gian.  
21. Nhân viên nộp tài liệu; trạng thái chờ duyệt, được duyệt, bị từ chối hoặc hết hạn được hiển thị rõ.  
22. Hệ thống tính trạng thái đủ/thiếu hồ sơ từ các yêu cầu có hiệu lực và tài liệu đã được duyệt.  
23. Hệ thống tính trạng thái đào tạo từ kết quả học/thi, hạn hiệu lực và yêu cầu chức vụ.  
24. Nếu khóa học được đánh dấu chặn phân ca, nhân viên chưa hoàn thành không được phân ca hợp lệ hoặc ca phải hiển thị trạng thái cần xử lý theo chính sách.

## **3.6. Checklist đầu ca/cuối ca**

25. Checklist được tạo từ template đã kích hoạt và gắn với ngày/ca hoặc lượt bàn giao.  
26. Mỗi task có người phụ trách, hạn hoàn thành, yêu cầu minh chứng và cấu hình có cần quản lý duyệt hay không.  
27. Task tự xác nhận được hoàn tất theo cấu hình; task quan trọng như doanh thu, kiểm kho, hủy hàng hoặc bàn giao quỹ cần duyệt.  
28. Nhân viên gửi ảnh/minh chứng, ghi chú và chuyển task sang SUBMITTED.  
29. Quản lý duyệt hoặc từ chối kèm lý do. Task bị từ chối quay lại trạng thái cần làm lại và tạo nhắc nhở.  
30. Checklist đầu/cuối ngày chưa hoàn thành có thể kích hoạt nhắc nhở và hiển thị trên dashboard ca tiếp theo.

## **3.7. Vi phạm, thưởng/phạt**

31. Hệ thống tạo ViolationEvent khi có dữ liệu đủ căn cứ theo rule, ví dụ đi muộn sau ân hạn hoặc checklist quá hạn.  
32. Sự kiện vi phạm là dữ liệu ghi nhận, không đồng nghĩa ngay với quyết định phạt tiền.  
33. Nhân viên có quyền xem nội dung liên quan và gửi giải trình theo quy trình.  
34. Vi phạm nhẹ có thể được tự động ghi nhận; quyết định thưởng/phạt có ảnh hưởng tài chính hoặc mức độ nghiêm trọng phải được người có thẩm quyền phê duyệt.  
35. Quyết định đã duyệt không được sửa trực tiếp; nếu sai cần hủy/thay thế bằng giao dịch có audit.

## **3.8. Chốt công**

36. Hệ thống tổng hợp ca đã lên lịch, check-in/out, ngoại lệ, điều chỉnh, OT, vắng mặt và các dữ liệu liên quan.  
37. Manager rà soát/xác nhận dữ liệu theo thẩm quyền.  
38. HR kiểm tra các đơn đang chờ, check-out thiếu, ngoại lệ chưa xử lý và OT chưa duyệt.  
39. Nếu còn điều kiện chặn, API readiness trả danh sách cần xử lý và không cho chốt.  
40. Khi đủ điều kiện, HR chốt kỳ công; dữ liệu bị khóa và chỉ mở lại qua quy trình đặc biệt có audit.

# **4\. Quy tắc nghiệp vụ chi tiết**

## **4.1. GPS và thời gian**

| Mã | Quy tắc | Giá trị/diễn giải |
| :---- | :---- | :---- |
| BR-GPS-01 | Bán kính cửa hàng | Có thể cấu hình 15–50 m; mặc định đề xuất 30 m. |
| BR-GPS-02 | Độ chính xác GPS | Phải có ngưỡng accuracy tối đa; giá trị cần chốt và kiểm thử với thiết bị thực tế. |
| BR-TIME-01 | Check-in sớm | Cho phép trước ca 15–30 phút theo cấu hình. |
| BR-TIME-02 | Ân hạn đi muộn | 3–5 phút/ca; mặc định đề xuất 5 phút. |
| BR-TIME-03 | Hạn mức ân hạn | Tối đa 3–5 lần/tháng theo cấu hình; cần chốt cách tính lượt và reset theo tháng. |
| BR-TIME-04 | Đi muộn | Tính từ phút đầu tiên sau khi hết thời gian ân hạn. |
| BR-OT-01 | OT | Ghi nhận thời gian thực tế nhưng chỉ tính OT được duyệt. |

## **4.2. Thiết bị và ảnh**

| Mã | Quy tắc | Diễn giải |
| :---- | :---- | :---- |
| BR-DEV-01 | Một thiết bị ACTIVE | Mỗi nhân viên chỉ có tối đa một thiết bị hoạt động tại một thời điểm. |
| BR-DEV-02 | Đổi thiết bị | Thiết bị mới chờ Manager/HR duyệt; backend phải khóa/thu hồi thiết bị cũ nhất quán. |
| BR-PHOTO-01 | Ảnh xác minh | Bắt buộc ở check-in/check-out theo quy trình chuẩn. |
| BR-PHOTO-02 | Chụp ngẫu nhiên | Chỉ áp dụng cho nhóm nhân viên đi thị trường nếu phạm vi sau này có nhóm này. |
| BR-CAM-01 | Không cấp quyền camera | Từ chối chấm công chuẩn và hiển thị hướng dẫn mở quyền. |
| BR-CAM-02 | Hỏng camera | QR/Wi-Fi nội bộ là phương án ngoại lệ, phải ghi lại và có quy tắc phê duyệt. |
| BR-RET-01 | Lưu ảnh | Mục tiêu 6–12 tháng; cần chốt thời hạn theo yêu cầu pháp lý, mục đích và chính sách dữ liệu. |

## **4.3. Hồ sơ và đào tạo**

* Yêu cầu hồ sơ được cấu hình theo chức vụ, có hiệu lực từ ngày và có thể có ngày hết hiệu lực.  
* Ví dụ thu ngân cần CCCD, sơ yếu lý lịch, giấy cam kết; vị trí liên quan thực phẩm có thể yêu cầu chứng chỉ an toàn thực phẩm.  
* Trạng thái tổng hợp: COMPLETE/INCOMPLETE/UNDER\_REVIEW/EXPIRED; trạng thái chi tiết từng tài liệu vẫn được giữ.  
* Đào tạo bắt buộc có thể có điểm đạt, số lần thi, thời hạn hiệu lực và cờ BlocksShiftAssignment.  
* Không lưu trạng thái tổng hợp như nguồn sự thật duy nhất; cần tính từ các yêu cầu và kết quả chi tiết.

## **4.4. Checklist, nhắc nhở**

| Mã | Quy tắc | Diễn giải |
| :---- | :---- | :---- |
| BR-CHK-01 | Template có version | Checklist đã tạo giữ nguyên nội dung của version tại thời điểm phát sinh. |
| BR-CHK-02 | Duyệt theo loại task | Doanh thu, kiểm kho, hủy hàng, bàn giao quỹ có thể yêu cầu quản lý duyệt; việc thường ngày có thể tự xác nhận. |
| BR-REM-01 | Nhắc trước hạn | Push notification trước 15 phút. |
| BR-REM-02 | Nhắc sau hạn | Mỗi 5 phút, tối đa 3 lần; sau đó tạo trạng thái vi phạm hoặc chuyển kiểm tra theo rule. |
| BR-REM-03 | Chống gửi lặp | Dùng khóa sự kiện nhắc nhở duy nhất để job chạy lại không gửi trùng. |

## **4.5. Thưởng/phạt và điều chỉnh công**

* Đi muộn, về sớm, checklist quên hoặc lỗi dịch vụ có thể tạo sự kiện vi phạm theo rule đã cấu hình.  
* KPI vượt trội hoặc khách khen có thể tạo đề xuất thưởng; cần lưu căn cứ.  
* Hệ thống tự ghi nhận lỗi nhẹ khi đủ dữ kiện; thưởng/phạt nặng do Store Manager/Operations Director hoặc người được ủy quyền duyệt.  
* Điều chỉnh công: Employee tạo đơn và minh chứng; Manager duyệt nghiệp vụ; HR duyệt tổng hợp để chốt công.  
* Mọi điều chỉnh phải có lịch sử giá trị cũ/mới, người thao tác, người duyệt, lý do và thời điểm.

# **5\. Yêu cầu chức năng (SRS)**

| ID | Nhóm | Yêu cầu | Actor |
| :---- | :---- | :---- | :---- |
| FR-001 | Xác thực | Hệ thống cho phép đăng nhập Google, đăng xuất, refresh phiên theo cơ chế bảo mật và xem hồ sơ cá nhân. | All |
| FR-002 | Quản lý quyền | Hệ thống kiểm tra quyền ở backend trên từng endpoint và phạm vi dữ liệu. | All |
| FR-003 | Cấu hình cửa hàng | Admin cấu hình tọa độ, bán kính GPS, cửa sổ check-in, ân hạn, lưu ảnh và reminder. | Admin |
| FR-004 | Thiết bị | Nhân viên đăng ký thiết bị; người có quyền duyệt/từ chối; mỗi nhân viên chỉ có một thiết bị ACTIVE. | Employee/Manager/HR |
| FR-005 | Check-in | Xác minh ca, thiết bị, GPS, ảnh và anti-spoofing theo cấu hình; chống gửi lặp. | Employee |
| FR-006 | Check-out | Xác minh và ghi nhận check-out; phân biệt thời gian hiện diện với OT đã duyệt. | Employee |
| FR-007 | Ngoại lệ GPS | Nhân viên gửi giải trình và ảnh; Manager duyệt/từ chối có lý do. | Employee/Manager |
| FR-008 | Điều chỉnh công | Đơn điều chỉnh có quy trình Manager rồi HR; giữ audit lịch sử. | Employee/Manager/HR |
| FR-009 | Lịch và phân ca | Manager tạo mẫu ca, phân ca và điều chỉnh; Employee xem lịch cá nhân. | Manager/Employee |
| FR-010 | Hồ sơ theo chức vụ | Admin cấu hình bộ hồ sơ; Employee nộp hồ sơ; người có quyền duyệt/từ chối. | All by permission |
| FR-011 | LMS | Quản lý khóa học bắt buộc, bài test, điểm, hiệu lực và điều kiện chặn ca. | All by permission |
| FR-012 | Kỹ năng | Lưu kỹ năng và kết quả đánh giá theo nhân viên. | Manager/HR |
| FR-013 | Checklist | Tạo checklist theo ca/ngày, giao nhiệm vụ, đính kèm minh chứng và duyệt theo loại. | All by permission |
| FR-014 | Vi phạm | Ghi nhận sự kiện, cho phép xác nhận/bác bỏ/giải trình và lưu căn cứ. | All by permission |
| FR-015 | Thưởng/phạt | Tạo đề xuất, phê duyệt theo thẩm quyền, không tự động khấu trừ lương từ sự kiện chưa xác minh. | Manager/HR/Director |
| FR-016 | Nhắc nhở | Gửi nhắc trước hạn và nhắc quá hạn theo cấu hình, chống gửi trùng. | System |
| FR-017 | Dashboard | Hiển thị chấm công, tình trạng hồ sơ/đào tạo, đi muộn, vi phạm, thưởng/phạt và checklist. | Manager/HR |
| FR-018 | Báo cáo | Báo cáo chấm công, checklist, hồ sơ/đào tạo và mức sẵn sàng chốt công. | Manager/HR |
| FR-019 | Chốt công | Kiểm tra điều kiện, xác nhận quản lý, HR chốt và khóa kỳ công. | Manager/HR |
| FR-020 | Audit | Ghi nhận các thao tác quan trọng và truy cập dữ liệu nhạy cảm. | System |

# **6\. Yêu cầu phi chức năng và UX**

## **6.1. UX liền mạch**

* Dashboard theo vai trò; ưu tiên việc cần làm tiếp theo thay vì chỉ hiển thị dữ liệu.  
* Trên màn hình chấm công, hiển thị sẵn ca hiện tại, thời gian được phép check-in, trạng thái GPS, camera, thiết bị và điều kiện đào tạo.  
* Luồng chấm công gồm các bước có trạng thái rõ ràng: kiểm tra điều kiện → lấy GPS → chụp ảnh/xác minh → gửi → kết quả.  
* Nếu lỗi, giữ dữ liệu đầu vào có thể tái sử dụng an toàn; không bắt người dùng nhập lại toàn bộ nếu mạng chập chờn.  
* Với mỗi trạng thái chờ duyệt, hiển thị người/bộ phận xử lý, thời điểm gửi và bước tiếp theo.  
* Thông báo phải deep-link đến đúng màn hình/task cần xử lý.  
* Checklist hiển thị số việc hoàn tất/còn lại, deadline, mức quan trọng và yêu cầu ảnh/duyệt.  
* Không hiển thị trạng thái kỹ thuật như stack trace; dùng thông điệp thân thiện và mã lỗi có thể tra cứu.

## **6.2. Bảo mật và độ tin cậy**

* HTTPS bắt buộc; token có thời hạn và refresh token được bảo vệ/thu hồi theo thiết kế.  
* Ảnh và tài liệu nhân viên lưu ở private storage, dùng signed URL có hạn hoặc cơ chế tương đương.  
* Không lưu dữ liệu sinh trắc học thô nếu không cần; xác định nhà cung cấp, mục đích, căn cứ xử lý và chính sách xóa trước khi triển khai.  
* API nhạy cảm phải có rate limit, kiểm tra quyền, validation và audit.  
* Dùng transaction cho phê duyệt thiết bị, điều chỉnh công, duyệt checklist và chốt công.  
* Đồng bộ giờ server; lưu thời gian client chỉ như dữ liệu tham khảo, không dùng làm nguồn thời gian duy nhất.  
* Đặt mục tiêu hiệu năng, tải đồng thời, RPO/RTO và lịch backup sau khi chốt quy mô thực tế.

## **6.3. Khả năng truy cập và UX lỗi**

* Thông báo lỗi có hành động khắc phục cụ thể.  
* Không chỉ dùng màu sắc để biểu thị trạng thái; kèm chữ/icon.  
* Cho phép thử lại an toàn khi timeout; các hành động quan trọng phải idempotent.  
* Form nộp hồ sơ/giải trình lưu nháp nếu phù hợp và thông báo rõ file nào đã upload thành công.

# **7\. ERD logic và thiết kế dữ liệu**

## **7.1. Quy ước dữ liệu**

* SQL Server; dùng DATETIME2 cho thời điểm, DECIMAL cho tiền và tọa độ, BIT cho cờ boolean.  
* Chọn một chuẩn khóa chính nhất quán trong toàn hệ thống: BIGINT IDENTITY hoặc UNIQUEIDENTIFIER. Tài liệu minh họa BIGINT cho bảng nghiệp vụ.  
* Mỗi bảng nghiệp vụ cần khóa chính, khóa ngoại, CreatedAt/UpdatedAt và CreatedBy/UpdatedBy khi phù hợp.  
* Không tạo BaseEntity table; các cột audit chung là cột vật lý trong từng bảng cần thiết.  
* Không dùng một Status chung cho các state machine khác nhau.

## **7.2. ERD tổng quan**

| erDiagram     STORE \|\|--o{ EMPLOYEE : employs     APP\_USER \|\|--o\| EMPLOYEE : has\_profile     APP\_USER \|\|--o{ USER\_ROLE : assigned     ROLE \|\|--o{ USER\_ROLE : contains     ROLE \|\|--o{ ROLE\_PERMISSION : grants     PERMISSION \|\|--o{ ROLE\_PERMISSION : defines     EMPLOYEE \|\|--o{ SHIFT\_ASSIGNMENT : receives     WORK\_SHIFT \|\|--o{ SHIFT\_ASSIGNMENT : schedules     SHIFT\_ASSIGNMENT \|\|--o\| ATTENDANCE : records     EMPLOYEE \|\|--o{ ATTENDANCE\_DEVICE : registers     ATTENDANCE \|\|--o{ ATTENDANCE\_VERIFICATION : verifies     ATTENDANCE\_DEVICE \|\|--o{ ATTENDANCE\_VERIFICATION : identifies     ATTENDANCE \|\|--o{ ATTENDANCE\_ADJUSTMENT\_HISTORY : adjusts     EMPLOYEE \|\|--o{ EMPLOYEE\_DOCUMENT : owns     DOCUMENT\_TYPE \|\|--o{ POSITION\_DOCUMENT\_REQUIREMENT : defines     JOB\_POSITION \|\|--o{ POSITION\_DOCUMENT\_REQUIREMENT : requires     JOB\_POSITION \|\|--o{ POSITION\_TRAINING\_REQUIREMENT : requires     TRAINING\_COURSE \|\|--o{ POSITION\_TRAINING\_REQUIREMENT : defines     EMPLOYEE \|\|--o{ EMPLOYEE\_TRAINING : learns     TRAINING\_COURSE \|\|--o{ EMPLOYEE\_TRAINING : tracks     CHECKLIST\_TEMPLATE \|\|--o{ CHECKLIST\_TEMPLATE\_ITEM : contains     CHECKLIST\_TEMPLATE \|\|--o{ CHECKLIST\_INSTANCE : generates     CHECKLIST\_INSTANCE \|\|--o{ CHECKLIST\_TASK : contains     CHECKLIST\_TASK \|\|--o{ CHECKLIST\_EVIDENCE : supports     CHECKLIST\_TASK \|\|--o{ CHECKLIST\_REVIEW : reviewed     EMPLOYEE \|\|--o{ VIOLATION\_EVENT : has     EMPLOYEE \|\|--o{ EMPLOYEE\_REWARD\_PENALTY : receives     APP\_USER \|\|--o{ NOTIFICATION : receives     APP\_USER \|\|--o{ AUDIT\_LOG : performs |
| :---- |

## **7.3. Danh mục bảng và trách nhiệm**

| Bảng | Trách nhiệm |
| :---- | :---- |
| AppUser | Tài khoản, email Google, trạng thái tài khoản. |
| Role / UserRole / Permission / RolePermission | Vai trò, quyền và ánh xạ quyền. |
| Store | Cửa hàng duy nhất, tọa độ, bán kính và cấu hình chung. |
| Employee | Hồ sơ nhân viên, mã nhân viên, chức vụ, trạng thái. |
| JobPosition | Danh mục chức vụ. |
| WorkShift | Mẫu ca và giờ bắt đầu/kết thúc. |
| ShiftAssignment | Phân ca theo nhân viên và ngày. |
| Attendance | Bản ghi check-in/check-out và trạng thái công. |
| AttendanceDevice | Thiết bị đăng ký, trạng thái, người duyệt. |
| AttendanceVerification | Kết quả GPS/thiết bị/ảnh/QR/Wi-Fi/liveness. |
| AttendanceAdjustmentHistory | Lịch sử giá trị chấm công trước/sau. |
| AttendanceAdjustmentRequest | Đơn điều chỉnh và luồng Manager/HR. |
| OvertimeRequest | Yêu cầu OT và quyết định phê duyệt. |
| DocumentType | Danh mục loại hồ sơ. |
| PositionDocumentRequirement | Bộ hồ sơ bắt buộc theo chức vụ và thời hạn hiệu lực. |
| EmployeeDocument | Hồ sơ nộp, file, trạng thái duyệt, hạn hiệu lực. |
| TrainingCourse | Khóa học, điểm đạt, thời hạn hiệu lực. |
| PositionTrainingRequirement | Khóa học bắt buộc theo chức vụ và cờ chặn ca. |
| EmployeeTraining / TrainingAttempt | Tiến độ và lịch sử các lần thi. |
| Skill / EmployeeSkill | Danh mục kỹ năng và kết quả đánh giá. |
| ChecklistTemplate / ChecklistTemplateItem | Mẫu checklist có version và quy tắc duyệt. |
| ChecklistInstance | Checklist cụ thể theo ngày/ca. |
| ChecklistTask | Nhiệm vụ, người phụ trách, deadline, trạng thái. |
| ChecklistEvidence | Ảnh/tài liệu minh chứng. |
| ChecklistReview | Quyết định duyệt/từ chối và lý do. |
| ViolationEvent | Sự kiện vi phạm và quá trình xử lý. |
| EmployeeRewardPenalty | Đề xuất/quyết định thưởng phạt. |
| ReminderRule | Cấu hình nhắc trước hạn, chu kỳ và số lần tối đa. |
| Notification | Thông báo, người nhận, deep link, trạng thái đọc. |
| AuditLog | Nhật ký thao tác quan trọng. |
| PayrollPeriod | Kỳ công, readiness, xác nhận và chốt công. |

## **7.4. Cột đề xuất cho các bảng trọng tâm**

### **Store**

| Cột | Kiểu | Ghi chú |
| :---- | :---- | :---- |
| StoreId | BIGINT PK | ID cửa hàng |
| Name | NVARCHAR(150) | Tên cửa hàng |
| Latitude / Longitude | DECIMAL(10,7) | Tọa độ cửa hàng |
| AttendanceRadiusMeters | INT | CHECK constraint 15–50 |
| CheckInEarlyMinutes | INT | CHECK constraint 15–30 |
| GraceMinutes | INT | CHECK constraint 3–5 |
| MonthlyGraceLimit | INT | Giới hạn số lần ân hạn |
| PhotoRetentionMonths | INT | Theo chính sách đã chốt |
| IsActive | BIT | Cửa hàng đang hoạt động |

### **AttendanceDevice**

| Cột | Kiểu | Ghi chú |
| :---- | :---- | :---- |
| DeviceId | BIGINT PK | ID thiết bị |
| EmployeeId | BIGINT FK | Chủ thiết bị |
| DeviceFingerprint | NVARCHAR(256) | Mã nhận diện đã bảo vệ |
| Platform | VARCHAR(20) | ANDROID/IOS |
| Status | VARCHAR(20) | PENDING/ACTIVE/LOCKED/REJECTED/REVOKED |
| RequestedAt | DATETIME2 | Thời điểm yêu cầu |
| ApprovedBy / ApprovedAt | FK / DATETIME2 | Người và thời điểm duyệt |
| RevokedAt | DATETIME2 NULL | Thời điểm thu hồi |

Ràng buộc: dùng filtered unique index hoặc cơ chế tương đương để mỗi EmployeeId chỉ có một bản ghi Status='ACTIVE'; thao tác chuyển thiết bị cần transaction.

### **AttendanceVerification**

| Cột | Kiểu | Ghi chú |
| :---- | :---- | :---- |
| VerificationId | BIGINT PK | ID xác minh |
| AttendanceId | BIGINT FK | Bản ghi công |
| DeviceId | BIGINT FK NULL | Thiết bị |
| VerificationType | VARCHAR(30) | GPS/DEVICE/PHOTO/FACE\_LIVENESS/QR/WIFI |
| Latitude / Longitude | DECIMAL(10,7) NULL | Tọa độ |
| AccuracyMeters / DistanceMeters | DECIMAL(8,2) NULL | Sai số/khoảng cách |
| EvidenceStorageKey | NVARCHAR(500) NULL | Khóa private storage |
| VerificationStatus | VARCHAR(20) | PASSED/FAILED/REVIEW\_REQUIRED/EXEMPTED |
| FailureReason / VerifiedAt | NVARCHAR(500) / DATETIME2 | Lý do và thời điểm |

### **EmployeeDocument và yêu cầu theo chức vụ**

PositionDocumentRequirement cần PositionId, DocumentTypeId, IsMandatory, EffectiveFrom, EffectiveTo. EmployeeDocument cần EmployeeId, DocumentTypeId, StorageKey, IssuedAt, ExpiresAt, ReviewStatus, ReviewedBy, ReviewedAt, RejectionReason. Trạng thái đủ hồ sơ được tính từ các yêu cầu đang hiệu lực và tài liệu hợp lệ đã duyệt.

### **Training**

TrainingCourse cần PassingScore, ValidityMonths, IsMandatoryTest. PositionTrainingRequirement cần IsMandatory và BlocksShiftAssignment. EmployeeTraining/TrainingAttempt cần trạng thái, điểm, thời điểm hoàn thành, hạn hiệu lực và lịch sử thử lại.

### **Checklist**

Template cần Version và IsActive; item cần IsMandatory, RequiresEvidence, RequiresManagerApproval. Instance gắn với ngày/ca; Task có AssignedEmployeeId, DueAt, Status; Evidence lưu storage key; Review lưu reviewer, decision, reason, reviewedAt.

### **Violation và thưởng/phạt**

ViolationEvent cần SourceType/SourceId, EmployeeId, RuleCode, OccurredAt, Status, EvidenceReference và trạng thái xử lý. EmployeeRewardPenalty cần DecisionType, ReasonCode, Amount, DecisionStatus, ProposedBy, ApprovedBy, ApprovedAt và EffectiveDate.

## **7.5. Ràng buộc toàn vẹn**

* Attendance có khóa duy nhất phù hợp với mô hình một bản ghi công chính cho mỗi ShiftAssignment; nếu hỗ trợ nhiều lần ra/vào, phải thiết kế rõ session con.  
* Thiết bị ACTIVE duy nhất theo nhân viên.  
* Không trùng yêu cầu hồ sơ cùng loại trong cùng thời gian hiệu lực.  
* Checklist task không được tạo trùng cho cùng instance/item nếu không cho phép lặp.  
* Không cho người thực hiện tự duyệt checklist bắt buộc quản lý duyệt.  
* Quyết định thưởng/phạt đã duyệt không sửa trực tiếp; tạo hủy/thay thế có audit.  
* AuditLog chỉ append; tài khoản nghiệp vụ thông thường không được sửa/xóa.

# **8\. API contract dùng chung**

## **8.1. Quy chuẩn**

| Thuộc tính | Quy ước |
| :---- | :---- |
| Base URL | /api/v1 |
| Protocol | HTTPS |
| Payload | JSON; request/response camelCase |
| Authentication | Bearer JWT; refresh token theo thiết kế |
| Resource naming | Danh từ số nhiều, path kebab-case |
| Date/time | ISO 8601; có offset/múi giờ rõ ràng |
| Pagination | page, size, sort |
| Idempotency | Dùng Idempotency-Key hoặc idempotencyKey cho thao tác quan trọng |
| Versioning | API version qua /v1 |

## **8.2. Response thành công**

| {   "success": true,   "message": "Attendance checked in successfully",   "data": {     "attendanceId": 1001,     "status": "CHECKED\_IN",     "checkInAt": "2026-10-13T07:00:00+07:00"   },   "timestamp": "2026-10-13T07:00:01+07:00" } |
| :---- |

## **8.3. Response lỗi**

| {   "success": false,   "message": "Check-in verification failed",   "data": null,   "error": {     "code": "GPS\_OUT\_OF\_RANGE",     "details": {       "distanceMeters": 72.5,       "allowedRadiusMeters": 30     }   },   "timestamp": "2026-10-13T07:00:01+07:00" } |
| :---- |

## **8.4. HTTP status**

| Status | Ý nghĩa |
| :---- | :---- |
| 200 | Thành công |
| 201 | Tạo tài nguyên |
| 202 | Đã tiếp nhận, chờ xử lý |
| 400 | Request sai định dạng/validation |
| 401 | Chưa xác thực/token không hợp lệ |
| 403 | Không đủ quyền |
| 404 | Không tìm thấy |
| 409 | Xung đột trạng thái nghiệp vụ |
| 422 | Dữ liệu đúng cấu trúc nhưng không thỏa quy tắc nghiệp vụ |
| 429 | Quá giới hạn yêu cầu |
| 500 | Lỗi hệ thống |

## **8.5. State values đề xuất**

| Đối tượng | Trạng thái |
| :---- | :---- |
| Device | PENDING, ACTIVE, LOCKED, REJECTED, REVOKED |
| Attendance | CHECKED\_IN, CHECKED\_OUT, REVIEW\_REQUIRED, ADJUSTMENT\_PENDING, FINALIZED |
| Verification | PASSED, FAILED, REVIEW\_REQUIRED, EXEMPTED |
| Adjustment | PENDING\_MANAGER, PENDING\_HR, APPROVED, REJECTED, CANCELLED |
| Document | PENDING, APPROVED, REJECTED, EXPIRED |
| Training | NOT\_STARTED, IN\_PROGRESS, PASSED, FAILED, EXPIRED |
| Checklist task | PENDING, IN\_PROGRESS, SUBMITTED, APPROVED, REJECTED, OVERDUE, WAIVED |
| Violation | OPEN, UNDER\_REVIEW, CONFIRMED, DISMISSED, RESOLVED |
| Reward/Penalty | DRAFT, PENDING\_APPROVAL, APPROVED, REJECTED, CANCELLED |
| Payroll period | DRAFT, REVIEWING, NOT\_READY, READY, FINALIZED, REOPENED |

# **9\. Danh mục API theo module**

Quyền trong bảng API là permission logic; tên role thực tế có thể ánh xạ bằng RBAC. Tất cả endpoint dưới đây nằm dưới /api/v1.

## **9.1. Authentication và User**

| Method | Endpoint | Quyền | Mục đích |
| :---- | :---- | :---- | :---- |
| POST | /auth/google | Public | Đăng nhập Google |
| POST | /auth/refresh | Refresh token | Cấp access token mới |
| POST | /auth/logout | Authenticated | Đăng xuất/thu hồi phiên |
| GET | /users/me | Authenticated | Xem hồ sơ hiện tại |
| PATCH | /users/me | Authenticated | Cập nhật trường được phép |
| GET | /users/me/permissions | Authenticated | Lấy quyền hiệu lực |

### **POST /auth/google – Request**

| {   "idToken": "google-id-token" } |
| :---- |

### **Response rút gọn**

| {   "success": true,   "message": "Login successful",   "data": {     "accessToken": "jwt-access-token",     "refreshToken": "refresh-token-if-used",     "tokenType": "Bearer",     "expiresIn": 900,     "user": {       "userId": 1,       "email": "employee@example.com",       "displayName": "Nguyen Van A",       "roles": \["EMPLOYEE"\]     }   },   "timestamp": "2026-10-13T07:00:00+07:00" } |
| :---- |

Backend phải xác minh ID token (issuer, audience, expiry, chữ ký) và trạng thái tài khoản. Không tin email/role do client tự gửi.

## **9.2. Store và cấu hình**

| Method | Endpoint | Quyền | Mục đích |
| :---- | :---- | :---- | :---- |
| GET | /stores/current | Authenticated | Cửa hàng hiện tại |
| GET | /admin/store-settings | Admin | Xem cấu hình cửa hàng |
| PATCH | /admin/store-settings | Admin | Cập nhật cấu hình |
| GET | /admin/attendance-policies | Admin | Xem chính sách công |
| PUT | /admin/attendance-policies | Admin | Cập nhật chính sách công |
| GET | /admin/reminder-rules | Admin | Danh sách rule nhắc |
| PUT | /admin/reminder-rules/{ruleId} | Admin | Cập nhật rule |

| {   "attendanceRadiusMeters": 30,   "checkInEarlyMinutes": 15,   "graceMinutes": 5,   "monthlyGraceLimit": 3,   "photoRetentionMonths": 12,   "lateReminderIntervalMinutes": 5,   "maxLateReminders": 3 } |
| :---- |

Validation: bán kính 15–50 m; check-in sớm 15–30 phút; ân hạn 3–5 phút; reminder quá hạn mỗi 5 phút tối đa 3 lần. Mọi thay đổi phải audit và quy định áp dụng cho ca đã tạo hay ca mới.

## **9.3. Employee management**

| Method | Endpoint | Quyền | Mục đích |
| :---- | :---- | :---- | :---- |
| GET | /employees | Admin/Manager | Danh sách theo quyền |
| POST | /employees | Admin/Manager được cấp quyền | Tạo nhân viên |
| GET | /employees/{employeeId} | Theo quyền | Chi tiết |
| PATCH | /employees/{employeeId} | Theo quyền | Cập nhật hồ sơ |
| PATCH | /employees/{employeeId}/status | Admin/Manager | Cập nhật trạng thái |
| GET | /employees/{employeeId}/overview | Theo quyền | Tổng quan hồ sơ/đào tạo/công |
| GET | /employees/{employeeId}/documents | Theo quyền | Hồ sơ |
| GET | /employees/{employeeId}/training | Theo quyền | Đào tạo |
| GET | /employees/{employeeId}/attendance-summary | Theo quyền | Tổng hợp công |
| GET | /admin/job-positions | Admin | Danh sách chức vụ |
| POST | /admin/job-positions | Admin | Tạo chức vụ |
| PUT | /admin/job-positions/{positionId} | Admin | Cập nhật chức vụ |

| {   "userId": 25,   "employeeCode": "EMP025",   "fullName": "Nguyen Van A",   "phone": "0900000000",   "positionId": 2,   "employmentStatus": "ACTIVE",   "hireDate": "2026-10-13" } |
| :---- |

Không nhận isProfileComplete hoặc isTrainingComplete làm dữ liệu gốc do client gửi. Backend phải tính các trạng thái này từ hồ sơ/đào tạo chi tiết.

## **9.4. Hồ sơ nhân viên**

| Method | Endpoint | Quyền | Mục đích |
| :---- | :---- | :---- | :---- |
| GET | /admin/document-types | Admin | Danh sách loại hồ sơ |
| POST | /admin/document-types | Admin | Tạo loại hồ sơ |
| GET | /admin/job-positions/{positionId}/document-requirements | Admin | Xem bộ hồ sơ |
| PUT | /admin/job-positions/{positionId}/document-requirements | Admin | Cập nhật bộ hồ sơ |
| POST | /employees/me/documents | Employee | Nộp hồ sơ của mình |
| GET | /employees/me/documents | Employee | Xem hồ sơ cá nhân |
| POST | /employees/{employeeId}/documents | Theo quyền | Nộp thay nhân viên |
| GET | /employees/{employeeId}/documents | Theo quyền | Xem hồ sơ |
| GET | /documents/{documentId} | Theo quyền | Metadata hồ sơ |
| POST | /documents/{documentId}/approve | Reviewer | Duyệt hồ sơ |
| POST | /documents/{documentId}/reject | Reviewer | Từ chối hồ sơ |

| {   "documentTypeId": 3,   "storageKey": "private-documents/employee-25/doc-123",   "issuedAt": "2026-01-01",   "expiresAt": "2027-01-01" } |
| :---- |

Khi từ chối, reason bắt buộc. File phải nằm trong private storage; dùng signed URL có thời hạn hoặc cơ chế upload/download được bảo vệ.

## **9.5. Lịch và phân ca**

| Method | Endpoint | Quyền | Mục đích |
| :---- | :---- | :---- | :---- |
| GET | /work-shifts | Theo quyền | Danh sách mẫu ca |
| POST | /work-shifts | Admin/Manager | Tạo mẫu ca |
| PUT | /work-shifts/{shiftId} | Admin/Manager | Cập nhật mẫu ca |
| GET | /shift-assignments | Manager | Xem phân ca |
| POST | /shift-assignments | Manager | Tạo phân ca |
| GET | /shift-assignments/me | Employee | Lịch cá nhân |
| GET | /shift-assignments/{assignmentId} | Theo quyền | Chi tiết phân ca |
| PATCH | /shift-assignments/{assignmentId} | Manager | Điều chỉnh phân ca |
| POST | /shift-assignments/{assignmentId}/cancel | Manager | Hủy phân ca |
| GET | /shift-assignments/{assignmentId}/eligibility | Theo quyền | Kiểm tra điều kiện nhận ca |

| {   "employeeId": 25,   "workShiftId": 2,   "workDate": "2026-10-14" } |
| :---- |

Nếu thiếu đào tạo bắt buộc, trả EMPLOYEE\_NOT\_ELIGIBLE\_FOR\_SHIFT hoặc tạo trạng thái cần xử lý theo chính sách; không âm thầm bỏ qua điều kiện.

## **9.6. Attendance – chấm công**

| Method | Endpoint | Quyền | Mục đích |
| :---- | :---- | :---- | :---- |
| POST | /attendance/check-in | Employee | Check-in |
| POST | /attendance/check-out | Employee | Check-out |
| GET | /attendance/me | Employee | Lịch sử cá nhân |
| GET | /attendance/me/current | Employee | Trạng thái ca hiện tại |
| GET | /attendance | Manager/HR | Danh sách chấm công |
| GET | /attendance/{attendanceId} | Theo quyền | Chi tiết công |
| GET | /attendance/{attendanceId}/verifications | Theo quyền | Kết quả xác minh |
| POST | /attendance/{attendanceId}/explanation-requests | Employee | Giải trình ngoại lệ |
| GET | /attendance/explanation-requests | Manager | Danh sách giải trình |
| POST | /attendance/explanation-requests/{requestId}/approve | Manager | Duyệt giải trình |
| POST | /attendance/explanation-requests/{requestId}/reject | Manager | Từ chối giải trình |
| POST | /attendance/{attendanceId}/overtime-requests | Theo quy trình | Yêu cầu OT |
| POST | /attendance/overtime-requests/{requestId}/approve | Manager | Duyệt OT |
| GET | /attendance/summary | Manager/HR | Tổng hợp công |

### **Check-in request**

| {   "shiftAssignmentId": 5001,   "deviceId": 120,   "location": {     "latitude": 10.7769,     "longitude": 106.7009,     "accuracyMeters": 12.5,     "capturedAt": "2026-10-14T06:55:00+07:00"   },   "photoEvidence": {     "storageKey": "attendance-evidence/session-abc/photo-1"   },   "faceVerification": {     "sessionId": "verification-session-abc"   },   "idempotencyKey": "checkin-5001-device120-unique" } |
| :---- |

### **Check-in response**

| {   "success": true,   "message": "Check-in recorded",   "data": {     "attendanceId": 9001,     "shiftAssignmentId": 5001,     "checkInAt": "2026-10-14T06:55:05+07:00",     "attendanceStatus": "CHECKED\_IN",     "verificationStatus": "PASSED",     "lateMinutes": 0   },   "timestamp": "2026-10-14T06:55:05+07:00" } |
| :---- |

Lỗi có thể gồm SHIFT\_NOT\_FOUND, CHECK\_IN\_TOO\_EARLY, GPS\_OUT\_OF\_RANGE, GPS\_ACCURACY\_INSUFFICIENT, DEVICE\_NOT\_ACTIVE, PHOTO\_REQUIRED, FACE\_VERIFICATION\_FAILED, CAMERA\_PERMISSION\_DENIED, ATTENDANCE\_ALREADY\_CHECKED\_IN và EMPLOYEE\_NOT\_ELIGIBLE\_FOR\_SHIFT.

### **Check-out request**

| {   "attendanceId": 9001,   "location": {     "latitude": 10.7769,     "longitude": 106.7009,     "accuracyMeters": 10.0,     "capturedAt": "2026-10-14T15:10:00+07:00"   },   "photoEvidence": {     "storageKey": "attendance-evidence/session-xyz/photo-2"   },   "faceVerification": {     "sessionId": "verification-session-xyz"   },   "idempotencyKey": "checkout-attendance9001-unique" } |
| :---- |

### **Check-out response**

| {   "success": true,   "message": "Check-out recorded",   "data": {     "attendanceId": 9001,     "checkOutAt": "2026-10-14T15:10:05+07:00",     "attendanceStatus": "CHECKED\_OUT",     "totalWorkedMinutes": 490,     "overtimeMinutes": 10,     "approvedOvertimeMinutes": 0   },   "timestamp": "2026-10-14T15:10:05+07:00" } |
| :---- |

Thời gian ngoài lịch không tự động trở thành OT được thanh toán. Backend cần phân biệt thời gian hiện diện, thời gian làm việc tính công và OT đã duyệt.

### **Thiết bị**

| Method | Endpoint | Quyền | Mục đích |
| :---- | :---- | :---- | :---- |
| POST | /attendance/devices/register | Employee | Đăng ký thiết bị |
| GET | /attendance/devices/me | Employee | Thiết bị cá nhân |
| GET | /attendance/devices/pending | Manager/HR | Thiết bị chờ duyệt |
| POST | /attendance/devices/{deviceId}/approve | Manager/HR | Duyệt thiết bị |
| POST | /attendance/devices/{deviceId}/reject | Manager/HR | Từ chối thiết bị |
| POST | /attendance/devices/{deviceId}/revoke | Manager/HR | Thu hồi thiết bị |

| {   "deviceFingerprint": "protected-device-fingerprint",   "platform": "ANDROID",   "deviceLabel": "Android device" } |
| :---- |

Tên máy không phải bằng chứng định danh đủ mạnh. Fingerprint có thể bị giả lập; cần kết hợp attestation, session bảo mật và kiểm soát server phù hợp nền tảng.

### **Giải trình GPS**

| {   "reasonCode": "GPS\_UNAVAILABLE",   "reason": "Điện thoại không lấy được vị trí tại thời điểm check-in",   "evidenceStorageKey": "attendance-evidence/explanations/123",   "requestedAction": "REVIEW\_CHECK\_IN" } |
| :---- |

Response tạo đơn nên trả requestId và status PENDING\_MANAGER. Khi duyệt/từ chối phải ghi reviewer, thời điểm, reason và audit.

### **Điều chỉnh công**

| Method | Endpoint | Quyền | Mục đích |
| :---- | :---- | :---- | :---- |
| POST | /attendance/adjustment-requests | Employee | Tạo đơn điều chỉnh |
| GET | /attendance/adjustment-requests/me | Employee | Đơn của mình |
| GET | /attendance/adjustment-requests | Manager/HR | Danh sách đơn |
| POST | /attendance/adjustment-requests/{requestId}/manager-approve | Manager | Duyệt nghiệp vụ |
| POST | /attendance/adjustment-requests/{requestId}/manager-reject | Manager | Từ chối |
| POST | /attendance/adjustment-requests/{requestId}/hr-approve | HR | Duyệt tổng hợp |
| POST | /attendance/adjustment-requests/{requestId}/hr-reject | HR | Từ chối tổng hợp |
| GET | /attendance/adjustment-requests/{requestId} | Theo quyền | Chi tiết đơn |

| {   "attendanceId": 9001,   "reasonCode": "FORGOT\_CHECK\_OUT",   "reason": "Quên check-out khi kết thúc ca",   "requestedCheckInAt": null,   "requestedCheckOutAt": "2026-10-14T15:00:00+07:00",   "evidenceStorageKey": "attendance-evidence/adjustments/456" } |
| :---- |

Luồng: PENDING\_MANAGER → PENDING\_HR → APPROVED. Khi từ chối, chuyển REJECTED kèm lý do. Cập nhật bản ghi công và lưu lịch sử trong transaction.

## **9.7. LMS và kỹ năng**

| Method | Endpoint | Quyền | Mục đích |
| :---- | :---- | :---- | :---- |
| GET | /training/courses | Theo quyền | Danh sách khóa học |
| POST | /admin/training/courses | Admin | Tạo khóa học |
| PUT | /admin/training/courses/{courseId} | Admin | Cập nhật khóa học |
| PUT | /admin/job-positions/{positionId}/training-requirements | Admin | Cấu hình bắt buộc |
| GET | /training/me | Employee | Khóa học của mình |
| POST | /training/courses/{courseId}/enroll | Theo quy trình | Đăng ký học |
| POST | /training/courses/{courseId}/attempts | Employee/LMS | Tạo/nộp lượt thi theo tích hợp |
| GET | /training/employees/{employeeId}/progress | Manager/HR | Tiến độ nhân viên |
| GET | /skills | Theo quyền | Danh sách kỹ năng |
| POST | /employees/{employeeId}/skills/assessments | Người đánh giá | Đánh giá kỹ năng |

| {   "success": true,   "message": "Training progress retrieved",   "data": {     "employeeId": 25,     "requiredCourses": 4,     "completedCourses": 3,     "missingCourses": 1,     "shiftEligibility": "RESTRICTED",     "restrictions": \[       {         "courseId": 10,         "courseName": "Food Safety",         "reason": "Mandatory course not completed"       }     \]   },   "timestamp": "2026-10-13T07:00:00+07:00" } |
| :---- |

Kết quả bài thi phải đến từ session/lượt thi được backend hoặc LMS tin cậy tạo; không tin điểm số tự gửi không có xác minh.

## **9.8. Checklist**

| Method | Endpoint | Quyền | Mục đích |
| :---- | :---- | :---- | :---- |
| GET | /admin/checklist-templates | Admin | Danh sách template |
| POST | /admin/checklist-templates | Admin | Tạo template |
| PUT | /admin/checklist-templates/{templateId} | Admin | Sửa template |
| POST | /admin/checklist-templates/{templateId}/activate | Admin | Kích hoạt version |
| POST | /checklists/instances/generate | Manager/System | Sinh checklist |
| GET | /checklists/me | Employee | Task được giao |
| GET | /checklists/instances | Manager | Danh sách checklist |
| GET | /checklists/tasks/{taskId} | Theo quyền | Chi tiết task |
| POST | /checklists/tasks/{taskId}/start | Employee được giao | Bắt đầu |
| POST | /checklists/tasks/{taskId}/evidence | Employee được giao | Thêm minh chứng |
| POST | /checklists/tasks/{taskId}/submit | Employee được giao | Gửi hoàn thành |
| POST | /checklists/tasks/{taskId}/approve | Manager | Duyệt task cần duyệt |
| POST | /checklists/tasks/{taskId}/reject | Manager | Từ chối task |
| POST | /checklists/tasks/{taskId}/reassign | Manager | Chuyển giao |
| GET | /checklists/reviews/pending | Manager | Danh sách chờ duyệt |

| {   "templateId": 10,   "workDate": "2026-10-14",   "shiftAssignmentId": 5001 } |
| :---- |

| {   "note": "Đã vệ sinh quầy và kiểm tra thiết bị",   "evidenceIds": \[7001, 7002\] } |
| :---- |

| {   "decision": "REJECTED",   "reason": "Khu vực quầy vẫn còn bẩn, vui lòng vệ sinh lại" } |
| :---- |

Endpoint approve phải kiểm tra RequiresManagerApproval. Task tự xác nhận phải hoàn tất theo cấu hình, không tạo bước duyệt giả.

## **9.9. Vi phạm và thưởng/phạt**

| Method | Endpoint | Quyền | Mục đích |
| :---- | :---- | :---- | :---- |
| GET | /violations | Manager/HR | Danh sách sự kiện |
| GET | /violations/{violationId} | Theo quyền | Chi tiết vi phạm |
| POST | /violations/{violationId}/confirm | Người được cấp quyền | Xác nhận |
| POST | /violations/{violationId}/dismiss | Người được cấp quyền | Bác bỏ |
| GET | /rewards-penalties | Manager/HR | Danh sách quyết định |
| POST | /rewards-penalties | Người có quyền đề xuất | Tạo đề xuất |
| GET | /rewards-penalties/me | Employee | Xem quyết định cá nhân |
| POST | /rewards-penalties/{decisionId}/approve | Approver | Duyệt |
| POST | /rewards-penalties/{decisionId}/reject | Approver | Từ chối |
| POST | /rewards-penalties/{decisionId}/cancel | Approver | Hủy theo quy trình |

| {   "employeeId": 25,   "decisionType": "REWARD",   "reasonCode": "EXCELLENT\_KPI",   "description": "Đạt KPI vượt mức trong kỳ đánh giá",   "amount": 500000,   "effectiveDate": "2026-10-31" } |
| :---- |

Đối với phạt, cần kiểm tra nội quy, căn cứ, quyền duyệt và khả năng giải trình. Không tự động khấu trừ lương dựa trên sự kiện chưa được xác minh.

## **9.10. Dashboard và báo cáo**

| Method | Endpoint | Quyền | Mục đích |
| :---- | :---- | :---- | :---- |
| GET | /dashboard/manager/overview | Manager | Tổng quan cửa hàng |
| GET | /dashboard/manager/attendance | Manager | Thống kê chấm công |
| GET | /dashboard/manager/employee-status | Manager | Hồ sơ và đào tạo |
| GET | /dashboard/manager/operations | Manager | Checklist/vận hành |
| GET | /dashboard/manager/rewards-penalties | Manager/HR | Thưởng phạt |
| GET | /dashboard/employee/overview | Employee | Tổng quan cá nhân |
| GET | /reports/attendance | Manager/HR | Báo cáo công |
| GET | /reports/payroll-readiness | HR | Mức sẵn sàng chốt công |
| GET | /reports/operations | Manager | Báo cáo checklist |

| GET /api/v1/dashboard/manager/attendance?from=2026-10-01\&to=2026-10-13\&shiftId=2   {   "success": true,   "message": "Attendance statistics retrieved",   "data": {     "period": {"from": "2026-10-01", "to": "2026-10-13"},     "scheduledShifts": 120,     "checkedInOnTime": 98,     "late": 12,     "absent": 4,     "missingCheckOuts": 3,     "verificationPending": 3,     "lateMinutesTotal": 185   },   "timestamp": "2026-10-13T18:00:00+07:00" } |
| :---- |

Số liệu trên chỉ minh họa. Dashboard cần định nghĩa công thức thống nhất, cách loại trừ bản ghi điều chỉnh và xử lý ngoại lệ.

## **9.11. Notification**

| Method | Endpoint | Quyền | Mục đích |
| :---- | :---- | :---- | :---- |
| GET | /notifications/me | Authenticated | Danh sách thông báo |
| GET | /notifications/me/unread-count | Authenticated | Số chưa đọc |
| POST | /notifications/{notificationId}/read | Recipient | Đánh dấu đã đọc |
| POST | /notifications/read-all | Recipient | Đánh dấu tất cả đã đọc |
| GET | /admin/notification-deliveries | Admin theo quyền | Theo dõi gửi thông báo |

Job nền xử lý nhắc nhở. Dùng khóa định danh theo event/resource/recipient/sequence để tránh gửi lặp khi job chạy lại.

## **9.12. Audit log**

| Method | Endpoint | Quyền | Mục đích |
| :---- | :---- | :---- | :---- |
| GET | /admin/audit-logs | Admin có quyền | Tra cứu audit |
| GET | /admin/audit-logs/{logId} | Admin có quyền | Chi tiết log |
| GET | /admin/audit-logs/export | Admin có quyền | Xuất log nếu được phép |

Không cung cấp endpoint sửa/xóa audit log cho tài khoản nghiệp vụ thông thường. Audit phải ghi các thay đổi chính sách, thiết bị, ngoại lệ công, hồ sơ, đào tạo, checklist, thưởng/phạt, quyền xem ảnh và chốt/mở lại kỳ công.

## **9.13. Kỳ công**

| Method | Endpoint | Quyền | Mục đích |
| :---- | :---- | :---- | :---- |
| GET | /payroll-periods | HR | Danh sách kỳ công |
| POST | /payroll-periods | HR/Admin theo quyền | Tạo kỳ công |
| GET | /payroll-periods/{periodId}/readiness | HR/Manager | Kiểm tra điều kiện chốt |
| POST | /payroll-periods/{periodId}/manager-confirm | Manager | Xác nhận dữ liệu |
| POST | /payroll-periods/{periodId}/hr-finalize | HR | Chốt kỳ công |
| POST | /payroll-periods/{periodId}/reopen | HR cấp cao/Admin theo quyền | Mở lại kỳ công |

| {   "success": true,   "message": "Payroll readiness retrieved",   "data": {     "periodId": 100,     "status": "NOT\_READY",     "totalEmployees": 25,     "pendingAdjustments": 2,     "missingCheckOuts": 1,     "pendingOvertimeApprovals": 3,     "unresolvedAttendanceExceptions": 1,     "canFinalize": false   },   "timestamp": "2026-10-13T18:00:00+07:00" } |
| :---- |

Backend tự tính canFinalize. Cần xác định ngoại lệ nào chặn chốt và ngoại lệ nào được phép chốt kèm ghi chú.

# **10\. Dashboard, báo cáo và chỉ số**

| Khu vực | Chỉ số gợi ý | Lưu ý |
| :---- | :---- | :---- |
| Chấm công | Tổng lượt phân ca, đúng giờ, đi muộn, vắng, thiếu check-out, chờ xác minh, tổng phút muộn. | Định nghĩa theo lượt phân ca; không đếm trùng do retry/điều chỉnh. |
| Nhân sự | Tỷ lệ hồ sơ đủ/thiếu/chờ duyệt/hết hạn; tỷ lệ đào tạo đủ/thiếu/hết hạn. | Tính từ yêu cầu hiện hành và tài liệu/kết quả được duyệt. |
| Checklist | Tỷ lệ hoàn thành đúng hạn, task quá hạn, task chờ duyệt, task bị từ chối/làm lại. | Phân biệt task tự xác nhận và task bắt buộc duyệt. |
| Vi phạm | Số sự kiện theo loại, trạng thái, kỳ và nhân viên. | Sự kiện không đồng nghĩa quyết định phạt. |
| Thưởng/phạt | Số đề xuất, đang chờ duyệt, đã duyệt, tổng giá trị theo loại. | Chỉ tính quyết định đã duyệt vào tổng chính thức. |
| Sẵn sàng chốt công | Đơn điều chỉnh chờ, thiếu check-out, OT chưa duyệt, ngoại lệ chưa xử lý. | API readiness là nguồn kiểm tra thống nhất. |

# **11\. Bảo mật, quyền riêng tư và lưu trữ**

* Ảnh chấm công, giấy tờ định danh và tài liệu nhân sự phải lưu trong private storage; truy cập theo quyền và ghi audit.  
* Chính sách ban đầu đề xuất lưu ảnh 6–12 tháng, nhưng thời hạn cuối cùng phải dựa trên mục đích xử lý, nghĩa vụ áp dụng và chính sách đã phê duyệt; xóa/ẩn danh khi hết hạn nếu không có căn cứ giữ lại.  
* Manager trực tiếp chỉ được xem ảnh theo quyền; không tải xuống theo chính sách mặc định. HR/Quản lý cấp cao có thể được quyền tải cụ thể, mọi lần truy cập/tải cần audit.  
* GPS phải được thu ở thời điểm cần cho chấm công; không theo dõi liên tục ngoài phạm vi nghiệp vụ nếu không có căn cứ và thông báo phù hợp.  
* Face verification/anti-spoofing có thể xử lý dữ liệu sinh trắc học; phải đánh giá pháp lý, minh bạch mục đích, tối thiểu hóa dữ liệu, kiểm soát nhà cung cấp và thời hạn lưu.  
* Không lưu access token, refresh token, ID token hoặc bí mật xác thực trong log.  
* Signed URL phải có thời hạn ngắn và không được dùng như đường dẫn công khai lâu dài.  
* Audit truy cập ảnh/tài liệu nhạy cảm phải gồm actor, resource, action, timestamp, purpose nếu cần và kết quả.

# **12\. State machine và xử lý lỗi**

## **12.1. Thiết bị**

| PENDING \--approve--\> ACTIVE PENDING \--reject--\> REJECTED ACTIVE \--lock--\> LOCKED ACTIVE \--revoke--\> REVOKED LOCKED \--unlock/approve--\> ACTIVE (nếu policy cho phép) |
| :---- |

## **12.2. Điều chỉnh công**

| PENDING\_MANAGER \--manager approve--\> PENDING\_HR PENDING\_MANAGER \--manager reject--\> REJECTED PENDING\_HR \--HR approve--\> APPROVED PENDING\_HR \--HR reject--\> REJECTED PENDING\_\* \--employee cancel (nếu policy cho phép)--\> CANCELLED |
| :---- |

## **12.3. Checklist**

| PENDING \-\> IN\_PROGRESS \-\> SUBMITTED SUBMITTED \-\> APPROVED SUBMITTED \-\> REJECTED \-\> IN\_PROGRESS PENDING/IN\_PROGRESS \-\> OVERDUE (theo deadline/rule) Task tự xác nhận có thể chuyển SUBMITTED \-\> APPROVED theo cấu hình. |
| :---- |

## **12.4. Mã lỗi chuẩn**

| Error code | Ý nghĩa | Hành vi UX |
| :---- | :---- | :---- |
| GPS\_OUT\_OF\_RANGE | Ngoài bán kính cho phép | Hiển thị khoảng cách và hướng dẫn. |
| GPS\_UNAVAILABLE | Không lấy được GPS | Hướng dẫn bật GPS hoặc gửi giải trình. |
| GPS\_ACCURACY\_INSUFFICIENT | Sai số GPS lớn | Thử lại ở vị trí thoáng. |
| DEVICE\_NOT\_ACTIVE | Thiết bị chưa duyệt/không hoạt động | Mở trạng thái đăng ký thiết bị. |
| CAMERA\_PERMISSION\_DENIED | Chưa cấp quyền camera | Hướng dẫn cấp quyền. |
| PHOTO\_REQUIRED | Thiếu ảnh bắt buộc | Yêu cầu chụp ảnh. |
| FACE\_VERIFICATION\_FAILED | Xác minh không đạt | Thử lại hoặc chuyển kiểm tra thủ công. |
| SHIFT\_NOT\_FOUND | Không tìm thấy ca | Làm mới lịch/liên hệ quản lý. |
| SHIFT\_NOT\_ELIGIBLE | Không đủ điều kiện nhận ca | Hiển thị lý do đào tạo/trạng thái. |
| ATTENDANCE\_ALREADY\_CHECKED\_IN | Đã check-in | Hiển thị bản ghi hiện tại. |
| OVERTIME\_NOT\_APPROVED | OT chưa duyệt | Hiển thị thời gian và trạng thái duyệt. |
| CHECKLIST\_REQUIRES\_REVIEW | Checklist chờ duyệt | Hiển thị người xử lý/trạng thái. |
| CHECKLIST\_EVIDENCE\_REQUIRED | Thiếu minh chứng | Hướng dẫn bổ sung. |
| DOCUMENT\_REQUIREMENT\_NOT\_MET | Thiếu hồ sơ | Mở danh sách hồ sơ còn thiếu. |
| TRAINING\_REQUIREMENT\_NOT\_MET | Thiếu đào tạo | Mở khóa học bắt buộc. |
| ATTENDANCE\_ADJUSTMENT\_PENDING | Đơn đang chờ xử lý | Hiển thị tiến trình. |
| PERMISSION\_DENIED | Không đủ quyền | Thông báo quyền truy cập. |

# **13\. Kiểm thử nghiệm thu**

| ID | Kịch bản | Kết quả mong đợi |
| :---- | :---- | :---- |
| TC01 | Check-in trong bán kính | Tạo một bản ghi công, GPS và ảnh hợp lệ. |
| TC02 | Check-in ngoài bán kính | Từ chối check-in chuẩn; trả GPS\_OUT\_OF\_RANGE. |
| TC03 | Đổi thiết bị chưa duyệt | Thiết bị mới không thể chấm công. |
| TC04 | Không cấp quyền camera | Từ chối chấm công chuẩn và hiển thị hướng dẫn. |
| TC05 | Camera hỏng, dùng dự phòng | Ghi phương thức QR/Wi-Fi, ngoại lệ và người duyệt. |
| TC06 | GPS không khả dụng | Tạo giải trình; không tự coi là check-in hợp lệ. |
| TC07 | Đi muộn sau ân hạn | Tính số phút muộn đúng chính sách. |
| TC08 | Vượt lượt ân hạn tháng | Áp dụng hạn mức và lưu lịch sử. |
| TC09 | Check-out muộn, OT chưa duyệt | Ghi thời gian thực tế; OT được duyệt vẫn bằng 0\. |
| TC10 | Thiếu chứng nhận bắt buộc | Không phân ca hợp lệ hoặc gắn hạn chế theo policy. |
| TC11 | Checklist quan trọng bị từ chối | Có lý do, thông báo và cho phép làm lại. |
| TC12 | Checklist tự xác nhận | Hoàn tất theo cấu hình không cần duyệt giả. |
| TC13 | Nhắc việc quá hạn | Nhắc trước 15 phút, sau hạn mỗi 5 phút tối đa 3 lần. |
| TC14 | Vi phạm nhẹ | Ghi sự kiện; không tự khấu trừ lương. |
| TC15 | Nhân viên tự duyệt đơn | Backend từ chối 403 hoặc lỗi quyền tương đương. |
| TC16 | Manager tải ảnh | Từ chối tải; chỉ cho xem nếu quyền cho phép. |
| TC17 | Điều chỉnh công | Lưu giá trị trước/sau, lý do, người duyệt, thời điểm. |
| TC18 | Chốt công còn ngoại lệ chặn | Không cho chốt, trả danh sách điều kiện chưa đạt. |
| TC19 | Retry check-in | Không tạo trùng khi dùng cùng idempotency key. |
| TC20 | Ảnh hết hạn lưu | Xóa/ẩn danh theo policy, audit, không xóa dữ liệu công cần giữ. |

# **14\. Quyết định cần chốt trước khi phát triển**

| ID | Quyết định | Đề xuất/việc cần làm |
| :---- | :---- | :---- |
| D-01 | HR là role hay permission set? | Đề xuất permission set gán cho người được ủy quyền để giữ ba actor chính. |
| D-02 | Nhà cung cấp FaceID/anti-spoofing | Chọn giải pháp, kiểm thử giả mạo, đánh giá pháp lý và phương án dự phòng. |
| D-03 | QR tĩnh/Wi-Fi dự phòng | Chốt điều kiện kích hoạt, ai duyệt, hạn ngoại lệ và mức tin cậy. |
| D-04 | Chính sách lưu ảnh | Chốt 6 hay 12 tháng hoặc thời hạn khác dựa trên mục đích/căn cứ áp dụng. |
| D-05 | Ngưỡng accuracy GPS | Đặt ngưỡng và kiểm thử thực địa; không chỉ kiểm tra khoảng cách. |
| D-06 | Ân hạn | Chốt 3 hay 5 phút; 3 hay 5 lượt/tháng; quy tắc reset tháng. |
| D-07 | Quy tắc chặn ca do đào tạo | Chốt khóa học nào chặn ca, ngoại lệ và người được mở khóa. |
| D-08 | Thẩm quyền thưởng/phạt | Chốt mức độ, cấp duyệt, quy trình giải trình và quy định nội bộ. |
| D-09 | Chốt công | Chốt điều kiện chặn, ngoại lệ cho phép và quyền mở lại kỳ. |
| D-10 | ID và naming conventions | Chọn BIGINT hay UUID; chuẩn tên bảng/cột, schema, migration. |
| D-11 | Lưu trữ và vận hành | Chọn private object storage, backup, retention, RPO/RTO và monitoring. |
| D-12 | API OpenAPI | Sau khi duyệt contract, sinh OpenAPI 3.1 và kiểm tra request/response tự động. |

# **Phụ lục A. Checklist trước khi đưa vào vận hành**

* ☐ Đã kiểm thử GPS tại vị trí thực tế và các loại điện thoại mục tiêu.  
* ☐ Đã kiểm thử cấp quyền camera/vị trí, từ chối quyền và hướng dẫn phục hồi.  
* ☐ Đã kiểm thử đổi máy, mất máy, thu hồi thiết bị và xử lý đồng thời.  
* ☐ Đã kiểm thử ảnh, quyền xem/tải, signed URL và thời hạn lưu.  
* ☐ Đã xác nhận bộ hồ sơ và đào tạo theo từng chức vụ.  
* ☐ Đã xác nhận template checklist đầu/cuối ca và ai phải duyệt từng loại.  
* ☐ Đã kiểm thử nhắc trước hạn, nhắc quá hạn, retry job và chống gửi trùng.  
* ☐ Đã kiểm thử điều chỉnh công, OT, đối soát và chốt/mở lại kỳ công.  
* ☐ Đã rà soát nội quy, thẩm quyền thưởng/phạt và chính sách dữ liệu cá nhân.  
* ☐ Đã cấu hình backup, monitoring, audit và quy trình xử lý sự cố.

# **Phụ lục B. Ghi chú triển khai**

Tài liệu này là đặc tả hợp nhất nghiệp vụ, SRS, ERD logic và API contract ở mức thiết kế. Đây chưa phải DDL SQL Server đã chạy, migration script hay OpenAPI được kiểm tra bằng công cụ. Trước khi lập trình, đối chiếu các bảng hiện tại, chuẩn hóa naming, khóa chính/khóa ngoại, constraint, index, phân trang, error schema và xác thực.

Các dữ liệu ví dụ trong JSON, số liệu dashboard, ID và timestamp chỉ nhằm minh họa. Không dùng trực tiếp làm dữ liệu thật.

Cần review pháp lý/bảo vệ dữ liệu cho GPS, ảnh nhận diện, dữ liệu sinh trắc học, hồ sơ nhân viên, thời hạn lưu và chính sách xử lý vi phạm trước khi đưa vào sử dụng.