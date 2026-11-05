import 'package:flutter/material.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/presentation/record_action_context.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';
import 'package:hrm_coffee_shop_flutter/features/accounts/presentation/account_permissions_editor.dart';

List<Widget> buildAccountRecordActions(RecordActionContext record) {
  final row = record.row;
  final user = record.user;
  final key = record.key;
  final id = record.id;
  final form = record.form;
  final actions = <Widget>[];
  if (key == 'accounts' && user.admin) {
    actions.add(
      form(
        'Cập nhật vai trò',
        '/admin/users/$id/roles',
        [
          FieldSpec(
            'roles',
            'Vai trò',
            kind: FieldKind.multiple,
            required: true,
            options: {
              'EMPLOYEE',
              'STORE_MANAGER',
              'SYSTEM_ADMIN',
              ...List<String>.from(row['roles'] as List? ?? []),
            }.toList(),
          ),
        ],
        initial: row,
        method: 'PUT',
      ),
    );
    actions.add(
      form(
        'Cập nhật trạng thái tài khoản',
        '/admin/users/$id/status',
        const [
          FieldSpec(
            'status',
            'Trạng thái',
            kind: FieldKind.choice,
            required: true,
            options: ['ACTIVE', 'LOCKED', 'INACTIVE'],
          ),
        ],
        initial: row,
        method: 'PATCH',
      ),
    );
    actions.add(AccountPermissionsEditor(id));
  }
  return actions;
}
