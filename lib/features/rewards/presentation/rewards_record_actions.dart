import 'package:flutter/material.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/presentation/record_action_context.dart';

List<Widget> buildRewardDecisionRecordActions(RecordActionContext record) {
  final user = record.user;
  final key = record.key;
  final id = record.id;
  final own = record.own;
  final status = record.status;
  final approve = record.approve;
  final reject = record.reject;
  final actions = <Widget>[];
  if (['decisions', 'my-rewards'].contains(key) &&
      user.has('REWARD_APPROVE') &&
      !own) {
    if (status == 'PENDING_APPROVAL') {
      actions.add(
        approve('Phê duyệt quyết định', '/rewards-penalties/$id/approve'),
      );
      actions.add(
        reject('Từ chối quyết định', '/rewards-penalties/$id/reject'),
      );
    }
    if (['PENDING_APPROVAL', 'APPROVED'].contains(status)) {
      actions.add(reject('Hủy quyết định', '/rewards-penalties/$id/cancel'));
    }
  }
  return actions;
}
