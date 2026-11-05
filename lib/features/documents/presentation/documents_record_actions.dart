import 'package:flutter/material.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/presentation/record_action_context.dart';
import 'package:hrm_coffee_shop_flutter/core/presentation/open_evidence.dart';

List<Widget> buildDocumentRecordActions(RecordActionContext record) {
  final context = record.context;
  final row = record.row;
  final user = record.user;
  final key = record.key;
  final id = record.id;
  final own = record.own;
  final approve = record.approve;
  final reject = record.reject;
  final actions = <Widget>[];
  if (['documents', 'my-document-records'].contains(key)) {
    if (row['viewUrl'] != null) {
      actions.add(
        FilledButton.icon(
          onPressed: () => openEvidence(context, row['viewUrl'] as String),
          icon: const Icon(Icons.open_in_new),
          label: const Text('Xem giấy tờ'),
        ),
      );
    }
    if (user.has('DOCUMENT_REVIEW') &&
        !own &&
        row['reviewStatus'] == 'PENDING') {
      actions.add(approve('Duyệt hồ sơ', '/documents/$id/approve'));
      actions.add(reject('Từ chối hồ sơ', '/documents/$id/reject'));
    }
  }
  return actions;
}
