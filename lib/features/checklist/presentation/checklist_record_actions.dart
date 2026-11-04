import 'package:flutter/material.dart';
import '../../../core/presentation/evidence_gallery.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/presentation/record_action_context.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/common_fields.dart';
import 'package:hrm_coffee_shop_flutter/core/presentation/resource_widgets.dart';
import 'package:hrm_coffee_shop_flutter/features/checklist/presentation/complete_checklist_item.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/presentation/action_command.dart';

List<Widget> buildChecklistRecordActions(RecordActionContext record) {
  final context = record.context;
  final ref = record.ref;
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
  if (['checklists', 'checklist-reviews', 'my-checklists'].contains(key)) {
    if (own && ['PENDING', 'REJECTED', 'OVERDUE'].contains(status)) {
      actions.add(
        ActionCommand(
          'checklist-start-$id',
          status == 'REJECTED' ? 'Làm lại checklist' : 'Bắt đầu checklist',
          '/checklists/tasks/$id/start',
        ),
      );
    }
    actions.add(const SectionTitle('Các công việc'));
    for (final item in ResourcePage.parse(row['items']).items) {
      actions.add(
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    item['isCompleted'] == true
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                  ),
                  title: Text(
                    '${item['itemName']}${item['isRequired'] == true ? ' *' : ''}',
                  ),
                  subtitle: Text(
                    '${item['instructions'] ?? ''}${item['requiresEvidence'] == true ? '\nCần ảnh minh chứng' : ''}',
                  ),
                ),
                if (item['note'] != null) Text('${item['note']}'),
                if (item['hasEvidence'] == true)
                  EvidenceGallery('/checklists/tasks/$id/evidence',
                      itemId: item['runItemId']),
                if (own && ['IN_PROGRESS', 'OVERDUE'].contains(status))
                  OutlinedButton.icon(
                    onPressed: () =>
                        completeChecklistItem(context, ref, id, item),
                    icon: const Icon(Icons.check),
                    label: Text(
                      item['requiresEvidence'] == true
                          ? 'Ảnh và hoàn thành mục'
                          : 'Hoàn thành mục',
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    if (own && ['IN_PROGRESS', 'OVERDUE'].contains(status)) {
      actions.add(
        approve('Gửi checklist để duyệt', '/checklists/tasks/$id/submit'),
      );
    }
    if (user.manager && !own && status == 'SUBMITTED') {
      actions.add(
        approve('Duyệt checklist', '/checklists/tasks/$id/approve'),
      );
      actions.add(reject('Yêu cầu làm lại', '/checklists/tasks/$id/reject'));
    }
    if (user.manager) {
      actions.add(
        form('Giao lại checklist', '/checklists/tasks/$id/reassign', const [
          employeeField,
        ]),
      );
    }
  }
  return actions;
}

List<Widget> buildChecklistTemplateRecordActions(RecordActionContext record) {
  final user = record.user;
  final key = record.key;
  final id = record.id;
  final approve = record.approve;
  final actions = <Widget>[];
  if (key == 'templates' && user.admin && record.row['isActive'] != true) {
    actions.add(const Text('Chọn phiên bản mẫu dùng cho các checklist tạo mới. Các phiên bản khác cùng mã sẽ ngừng sử dụng; checklist đã giao giữ nguyên nội dung cũ.'));
    actions.add(
      approve(
        'Dùng phiên bản này cho checklist mới',
        '/admin/checklist-templates/$id/activate',
      ),
    );
  }
  return actions;
}
