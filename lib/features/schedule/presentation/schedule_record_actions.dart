import 'package:flutter/material.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/presentation/record_action_context.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:hrm_coffee_shop_flutter/core/presentation/resource_widgets.dart';
import 'package:hrm_coffee_shop_flutter/features/attendance_requests/domain/attendance_request_fields.dart';
import '../../attendance/data/attendance_controller.dart';

List<Widget> buildScheduleRecordActions(RecordActionContext record) {
  final context = record.context;
  final row = record.row;
  final user = record.user;
  final key = record.key;
  final id = record.id;
  final own = record.own;
  final status = record.status;
  final form = record.form;
  final approve = record.approve;
  final actions = <Widget>[];
  if (['my-schedule', 'assignments'].contains(key)) {
    if (own && status == 'PUBLISHED') {
      actions.add(
        FilledButton.icon(
          onPressed: () {
            record.ref
                .read(selectedAttendanceAssignmentProvider.notifier)
                .select(int.parse(id));
            context.push('/attendance/check-in');
          },
          icon: const Icon(Icons.fingerprint),
          label: const Text('Mở trang chấm công'),
        ),
      );
    }
    if (own) {
      actions.add(
        form(
          'Gửi giải trình ca này',
          '/attendance/explanation-requests',
          explanationFields,
          initial: {
            'requestedCheckInAt': row['plannedStartAt'],
            'requestedCheckOutAt': row['plannedEndAt'],
          },
          fixed: {'scheduleId': row['assignmentId']},
        ),
      );
    }
    if (user.manager && status == 'PUBLISHED') {
      actions.add(approve('Hủy phân ca', '/shift-assignments/$id/cancel'));
    }
    actions.add(
      ResourceView(
        ResourceQuery('/shift-assignments/$id/eligibility'),
        builder: (data) => Card(
          child: ListTile(
            leading: Icon(
              json(data)['eligible'] == true
                  ? Icons.check_circle_outline
                  : Icons.info_outline,
            ),
            title: Text(
              json(data)['eligible'] == true
                  ? 'Đủ điều kiện nhận ca'
                  : 'Có điều kiện chưa đạt',
            ),
            subtitle: Text(
              (json(data)['restrictions'] as List? ?? [])
                  .map(
                    (r) =>
                        json(r)['message'] ??
                        json(r)['code'] ??
                        'Điều kiện chưa đạt',
                  )
                  .join('\n'),
            ),
          ),
        ),
      ),
    );
    if (row['attendanceId'] != null) {
      actions.add(
        OutlinedButton(
          onPressed: () => context.push(
            '/record/${user.has('ATTENDANCE_VIEW_ALL') ? 'attendance' : 'my-attendance'}/${row['attendanceId']}',
          ),
          child: const Text('Mở bản ghi chấm công'),
        ),
      );
    }
  }
  return actions;
}
