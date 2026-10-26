enum UserRole {
  systemAdmin,
  storeManager,
  employee,
}

class User {
  const User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.avatarUrl,
  });

  final String id;
  final String email;
  final String fullName;
  final UserRole role;
  final String? avatarUrl;
}