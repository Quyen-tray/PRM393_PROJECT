import 'package:flutter/material.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/presentation/record_action_context.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';
import 'package:hrm_coffee_shop_flutter/app/router/module_registry.dart'
    show module;
import 'package:hrm_coffee_shop_flutter/shared/resources/presentation/linked_resource_list.dart';

List<Widget> buildTrainingReviewRecordActions(RecordActionContext record) {
  final user = record.user;
  final key = record.key;
  final id = record.id;
  final own = record.own;
  final status = record.status;
  final approve = record.approve;
  final reject = record.reject;
  final actions = <Widget>[];
  if (key == 'training-reviews' &&
      trainingManager(user) &&
      !own &&
      status != 'PASSED') {
    actions.add(
      approve(
        'Xác nhận đã hoàn thành',
        '/training/completion-reviews/$id/approve',
      ),
    );
    actions.add(
      reject(
        'Chưa hoàn thành',
        '/training/completion-reviews/$id/not-complete',
      ),
    );
  }
  return actions;
}

List<Widget> buildEnrollmentRecordActions(RecordActionContext record) {
  final row = record.row;
  final user = record.user;
  final key = record.key;
  final actions = <Widget>[];
  if (key == 'enrollments') {
    if (user.employeeId != null) {
      actions.add(
        LinkedResourceList(
          '/training/courses/${row['courseId']}/attempts/me',
          module('enrollments'),
          title: 'Các lần kiểm tra',
          navigable: false,
        ),
      );
    }
  }
  return actions;
}

List<Widget> buildCourseRecordActions(RecordActionContext record) => const [];
