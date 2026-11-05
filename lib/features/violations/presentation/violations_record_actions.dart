import 'package:flutter/material.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/presentation/record_action_context.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';
import 'package:hrm_coffee_shop_flutter/app/router/module_registry.dart'
    show module;
import 'package:go_router/go_router.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/presentation/linked_resource_list.dart';

List<Widget> buildViolationRecordActions(RecordActionContext record) {
  final context = record.context;
  final spec = record.spec;
  final row = record.row;
  final user = record.user;
  final key = record.key;
  final id = record.id;
  final own = record.own;
  final status = record.status;
  final form = record.form;
  final approve = record.approve;
  final reject = record.reject;
  final actions = <Widget>[];
  if (['violations', 'my-violations'].contains(key)) {
    actions.add(
      LinkedResourceList(
        '/violations/$id/explanations',
        spec,
        title: 'Giải trình của nhân viên',
        navigable: false,
      ),
    );
    if (own && status == 'OPEN') {
      actions.add(
        form('Gửi giải trình vi phạm', '/violations/$id/explanations', const [
          FieldSpec(
            'reason',
            'Nội dung giải trình',
            kind: FieldKind.multiline,
            required: true,
          ),
          FieldSpec(
            'evidenceStorageKey',
            'Tài liệu minh chứng (tùy chọn)',
            kind: FieldKind.upload,
            source: 'DOCUMENT',
          ),
        ]),
      );
    }
    if (user.has('VIOLATION_REVIEW') && !own && status == 'OPEN') {
      actions.add(approve('Xác nhận vi phạm', '/violations/$id/confirm'));
      actions.add(reject('Bác bỏ vi phạm', '/violations/$id/dismiss'));
    }
    if (user.has('REWARD_PROPOSE') && status == 'CONFIRMED') {
      actions.add(
        form(
          'Đề xuất phạt từ vi phạm',
          '/rewards-penalties',
          module('decisions')
              .fields
              .where(
                (f) => ![
                  'employeeId',
                  'reasonCode',
                  'decisionType',
                ].contains(f.key),
              )
              .toList(),
          initial: {'description': row['details']},
          fixed: {
            'employeeId': row['employeeId'],
            'decisionType': 'PENALTY',
            'reasonCode': row['ruleCode'],
            'violationEventId': row['violationId'],
          },
        ),
      );
    }
    if (row['attendanceId'] != null) {
      actions.add(
        OutlinedButton(
          onPressed: () => context.push(
            '/record/${own ? 'my-attendance' : 'attendance'}/${row['attendanceId']}',
          ),
          child: const Text('Công liên quan'),
        ),
      );
    }
  }
  return actions;
}
