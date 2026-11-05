import 'package:flutter/material.dart';
import '../../../core/presentation/evidence_gallery.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/presentation/record_action_context.dart';
import 'package:go_router/go_router.dart';

List<Widget> buildExplanationRecordActions(RecordActionContext record) {
  final user = record.user;
  final key = record.key;
  final id = record.id;
  final own = record.own;
  final status = record.status;
  final approve = record.approve;
  final reject = record.reject;
  final actions = <Widget>[];
  if (['my-explanations', 'explanations'].contains(key) &&
      user.manager &&
      !own &&
      status == 'PENDING_MANAGER') {
    actions.add(
      approve(
        'Duyệt giải trình',
        '/attendance/explanation-requests/$id/approve',
      ),
    );
    actions.add(
      reject(
        'Từ chối giải trình',
        '/attendance/explanation-requests/$id/reject',
      ),
    );
  }
  if (['my-explanations', 'explanations'].contains(key)) {
    actions
        .add(EvidenceGallery('/attendance/explanation-requests/$id/evidence'));
  }
  return actions;
}

List<Widget> buildOvertimeRecordActions(RecordActionContext record) {
  final user = record.user;
  final key = record.key;
  final id = record.id;
  final own = record.own;
  final status = record.status;
  final approve = record.approve;
  final reject = record.reject;
  final actions = <Widget>[];
  if (['my-overtime', 'overtime'].contains(key) &&
      user.manager &&
      !own &&
      status == 'PENDING') {
    actions.add(
      approve('Duyệt tăng ca', '/attendance/overtime-requests/$id/approve'),
    );
    actions.add(
      reject('Từ chối tăng ca', '/attendance/overtime-requests/$id/reject'),
    );
  }
  if (['my-overtime', 'overtime'].contains(key)) {
    actions.add(EvidenceGallery('/attendance/overtime-requests/$id/evidence'));
  }
  return actions;
}

List<Widget> buildAdjustmentRecordActions(RecordActionContext record) {
  final context = record.context;
  final row = record.row;
  final user = record.user;
  final key = record.key;
  final id = record.id;
  final own = record.own;
  final approve = record.approve;
  final reject = record.reject;
  final actions = <Widget>[];
  if (['my-adjustments', 'adjustments'].contains(key)) {
    if (user.manager && !own && row['managerStatus'] == 'PENDING') {
      actions.add(
        approve(
          'Quản lý duyệt',
          '/attendance/adjustment-requests/$id/manager-approve',
        ),
      );
      actions.add(
        reject(
          'Quản lý từ chối',
          '/attendance/adjustment-requests/$id/manager-reject',
        ),
      );
    }
    if (user.has('ATTENDANCE_ADJUST_HR') &&
        !own &&
        row['managerStatus'] == 'APPROVED' &&
        row['hrStatus'] == 'PENDING') {
      actions.add(
        approve(
          'Nhân sự duyệt và áp dụng',
          '/attendance/adjustment-requests/$id/hr-approve',
        ),
      );
      actions.add(
        reject(
          'Nhân sự từ chối',
          '/attendance/adjustment-requests/$id/hr-reject',
        ),
      );
    }
    actions.add(
      OutlinedButton(
        onPressed: () => context.push(
          '/record/${user.has('ATTENDANCE_VIEW_ALL') || user.has('ATTENDANCE_ADJUST_HR') ? 'attendance' : 'my-attendance'}/${row['attendanceId']}',
        ),
        child: const Text('Xem bản ghi công liên quan'),
      ),
    );
  }
  if (['my-adjustments', 'adjustments'].contains(key)) {
    actions
        .add(EvidenceGallery('/attendance/adjustment-requests/$id/evidence'));
  }
  return actions;
}
