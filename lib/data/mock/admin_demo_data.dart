/// Presentation-only data for the admin (system administration) demo flow.
/// Replace with API data from /admin/* endpoints when the backend is ready.
enum AdminRole {
  admin('Admin'),
  manager('Manager'),
  employee('Employee');

  const AdminRole(this.label);
  final String label;
}

class AdminAccount {
  AdminAccount({
    required this.name,
    required this.code,
    required this.role,
    required this.position,
    this.active = true,
  });

  final String name;
  final String code;
  final AdminRole role;
  final String position;
  bool active;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

enum AdminCourseType { course, skill, certificate }

class AdminCourse {
  const AdminCourse(
    this.type,
    this.title,
    this.desc,
    this.mandatory,
    this.done,
    this.total,
  );

  final AdminCourseType type;
  final String title;
  final String desc;
  final bool mandatory;
  final int done;
  final int total;
}

abstract final class AdminDemoData {
  static const demoDate = 'Thứ Tư, 28/10/2026';

  static const stats = <(String, String)>[
    ('15', 'Tổng nhân viên'),
    ('12', 'Đang làm việc'),
    ('8', 'Khóa đào tạo'),
    ('4', 'Mẫu checklist'),
  ];

  static const monthLabels = ['T6', 'T7', 'T8', 'T9', 'T10'];
  static const monthValues = [9, 10, 12, 13, 15];

  static const todos = <(String, int)>[
    ('Khóa bắt buộc sắp hết hạn', 2),
    ('Checklist v1.1 chờ áp dụng', 1),
    ('Tài khoản chưa kích hoạt', 1),
  ];

  static final accounts = <AdminAccount>[
    AdminAccount(name: 'Quản trị viên', code: 'AD0001', role: AdminRole.admin, position: 'Quản trị hệ thống'),
    AdminAccount(name: 'Trần Thị Bích Ngọc', code: 'NV0010', role: AdminRole.manager, position: 'Quản lý cửa hàng'),
    AdminAccount(name: 'Nguyễn Văn An', code: 'NV0012', role: AdminRole.employee, position: 'Nhân viên phục vụ'),
    AdminAccount(name: 'Trần Văn Bình', code: 'NV0013', role: AdminRole.employee, position: 'Nhân viên pha chế'),
    AdminAccount(name: 'Lê Thị Hương', code: 'NV0014', role: AdminRole.employee, position: 'Nhân viên phục vụ'),
    AdminAccount(name: 'Phạm Quang Minh', code: 'NV0015', role: AdminRole.employee, position: 'Thu ngân', active: false),
    AdminAccount(name: 'Hoàng Thị Lan', code: 'NV0016', role: AdminRole.employee, position: 'Nhân viên pha chế'),
  ];

  static const positions = [
    (name: 'Quản lý cửa hàng', desc: 'Duyệt yêu cầu, xem báo cáo chấm công', count: 1),
    (name: 'Nhân viên pha chế', desc: 'Chuẩn bị đồ uống, kiểm tra máy pha cà phê', count: 4),
    (name: 'Nhân viên phục vụ', desc: 'Đón tiếp và phục vụ khách, vệ sinh bàn ghế', count: 6),
    (name: 'Thu ngân', desc: 'Thanh toán và kiểm đếm tiền cuối ca', count: 2),
  ];

  static const courses = [
    AdminCourse(AdminCourseType.course, 'An toàn thực phẩm', 'Bắt buộc cho toàn bộ nhân viên', true, 12, 15),
    AdminCourse(AdminCourseType.course, 'Quy trình phục vụ', 'Áp dụng cho nhân viên phục vụ', true, 10, 15),
    AdminCourse(AdminCourseType.course, 'Vệ sinh và an toàn lao động', 'Theo quy định của cửa hàng', true, 8, 15),
    AdminCourse(AdminCourseType.course, 'Mở và vệ sinh máy pha', 'Hướng dẫn vận hành máy espresso', false, 5, 15),
    AdminCourse(AdminCourseType.skill, 'Pha chế espresso', 'Kỹ năng pha chế cơ bản', false, 6, 12),
    AdminCourse(AdminCourseType.skill, 'Chăm sóc khách hàng', 'Giao tiếp và xử lý phản hồi', false, 9, 15),
    AdminCourse(AdminCourseType.certificate, 'Sơ cứu cơ bản', 'Chứng chỉ do đơn vị đào tạo cấp', false, 4, 15),
    AdminCourse(AdminCourseType.certificate, 'Chứng nhận an toàn thực phẩm', 'Cấp sau khóa An toàn thực phẩm', true, 11, 15),
  ];

  static const templates = [
    (name: 'Checklist đầu ca', tasks: 5),
    (name: 'Checklist cuối ca', tasks: 6),
    (name: 'Vệ sinh định kỳ', tasks: 8),
    (name: 'Kiểm tra thiết bị', tasks: 4),
  ];

  static const versions = [
    (version: '1.1', desc: 'Bản nháp, cập nhật lần cuối 26/10/2026', status: 'Chờ duyệt', active: false),
    (version: '1.0', desc: 'Đang áp dụng cho toàn cửa hàng từ 01/09/2026', status: 'Đang dùng', active: true),
  ];

  static const settings = [
    (title: 'Thông tin cửa hàng', value: '1 chi nhánh'),
    (title: 'Chính sách chấm công', value: 'Ca 08:00 đến 16:00, trễ tối đa 10 phút'),
    (title: 'Cài đặt GPS', value: 'Bán kính 100 m'),
    (title: 'Quy định vi phạm', value: '4 mức xử lý'),
    (title: 'Cấu hình thông báo', value: '3 loại thông báo'),
    (title: 'Sao lưu dữ liệu', value: 'Tự động lúc 02:00 hằng ngày'),
  ];
}
