enum UserRole { systemAdmin, storeManager, employee, unknown }

class User {
  const User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.roles,
    this.avatarUrl,
    this.phoneNumber,
    this.employeeId,
    this.status,
  });

  final String id;
  final String email;
  final String fullName;
  final List<String> roles;
  final String? avatarUrl;
  final String? phoneNumber;
  final int? employeeId;
  final String? status;

  bool hasRole(String role) =>
      roles.any((value) => value.toUpperCase() == role.toUpperCase());

  UserRole get primaryRole {
    if (hasRole('SYSTEM_ADMIN')) return UserRole.systemAdmin;
    if (hasRole('STORE_MANAGER') || hasRole('OPERATIONS_DIRECTOR')) {
      return UserRole.storeManager;
    }
    if (hasRole('EMPLOYEE')) return UserRole.employee;
    return UserRole.unknown;
  }

  factory User.fromJson(Map<String, dynamic> json) {
    final rawRoles = json['roles'];
    final roles = rawRoles is List
        ? rawRoles.map((role) => role.toString()).toList(growable: false)
        : const <String>[];
    final rawEmployeeId = json['employeeId'];
    return User(
      id: (json['userId'] ?? json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      fullName: (json['displayName'] ?? json['fullName'] ?? '').toString(),
      roles: roles,
      avatarUrl: json['avatarUrl']?.toString(),
      phoneNumber: json['phoneNumber']?.toString(),
      employeeId: rawEmployeeId is num
          ? rawEmployeeId.toInt()
          : int.tryParse(rawEmployeeId?.toString() ?? ''),
      status: json['status']?.toString(),
    );
  }
}
