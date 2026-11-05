enum Workspace {
  employee('EMPLOYEE', 'Nhân viên'),
  manager('STORE_MANAGER', 'Quản lý cửa hàng'),
  admin('SYSTEM_ADMIN', 'Quản trị hệ thống');

  const Workspace(this.code, this.label);
  final String code;
  final String label;
}
