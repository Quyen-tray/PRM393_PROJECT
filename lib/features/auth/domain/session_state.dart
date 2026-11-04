import 'package:hrm_coffee_shop_flutter/features/auth/domain/current_user.dart';
import 'package:hrm_coffee_shop_flutter/features/workspace/domain/workspace.dart';

class SessionState {
  const SessionState(
      {this.loading = false, this.user, this.workspace, this.error});
  final bool loading;
  final CurrentUser? user;
  final Workspace? workspace;
  final Object? error;
}
