import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/common_fields.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/domain/current_user.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/presentation/record_form.dart';

class RecordActionContext {
  const RecordActionContext(
      {required this.context,
      required this.ref,
      required this.spec,
      required this.row,
      required this.user});
  final BuildContext context;
  final WidgetRef ref;
  final ModuleSpec spec;
  final Json row;
  final CurrentUser user;
  String get key => spec.key;
  String get id => recordId(spec, row);
  bool get own => row['employeeId'] == user.employeeId;
  dynamic get status => row['status'] ?? row['reviewStatus'];
  Widget form(
    String label,
    String path,
    List<FieldSpec> fields, {
    Json initial = const {},
    Json fixed = const {},
    String method = 'POST',
  }) =>
      OutlinedButton(
        onPressed: () => editRecord(
          context,
          ref,
          title: label,
          fields: fields,
          initial: initial,
          path: path,
          fixed: fixed,
          method: method,
        ),
        child: Text(label),
      );
  Widget approve(String label, String path) => form(
        label,
        path,
        path.startsWith('/attendance/devices/') ||
                [
                  '/submit',
                  '/activate',
                  '/manager-confirm',
                  '/hr-finalize',
                ].any(path.endsWith)
            ? const []
            : const [noteField],
      );
  Widget reject(String label, String path) => form(label, path, const [
        FieldSpec('reason', 'Lý do', kind: FieldKind.multiline, required: true),
      ]);
}
