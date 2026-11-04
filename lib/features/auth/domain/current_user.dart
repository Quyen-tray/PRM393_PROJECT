import 'package:hrm_coffee_shop_flutter/features/workspace/domain/workspace.dart';

class CurrentUser {
  const CurrentUser(
      {required this.id,
      required this.name,
      required this.email,
      required this.roles,
      required this.permissions,
      this.employeeId});
  final int id;
  final String name, email;
  final int? employeeId;
  final Set<String> roles, permissions;
  factory CurrentUser.fromJson(
          Map<String, dynamic> profile, Map<String, dynamic> grants) =>
      CurrentUser(
          id: (profile['userId'] as num).toInt(),
          name: profile['displayName'] as String? ?? '',
          email: profile['email'] as String? ?? '',
          employeeId: (profile['employeeId'] as num?)?.toInt(),
          roles: Set<String>.from(
              grants['roles'] as List? ?? profile['roles'] as List? ?? []),
          permissions: Set<String>.from(grants['permissions'] as List? ?? []));
  bool has(String permission) => permissions.contains(permission);
  bool role(String role) => roles.contains(role);
  bool get manager => role('STORE_MANAGER');
  bool get admin => role('SYSTEM_ADMIN');
  List<Workspace> get workspaces => [
        if (employeeId != null || role('EMPLOYEE')) Workspace.employee,
        if (manager || role('OPERATIONS_DIRECTOR')) Workspace.manager,
        if (admin) Workspace.admin,
      ];
}
