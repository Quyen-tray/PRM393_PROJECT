import 'package:flutter/material.dart';
import '../../../shared/resources/presentation/related_section.dart';
import '../../auth/data/session_controller.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/presentation/record_action_context.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/common_fields.dart';
import 'package:hrm_coffee_shop_flutter/app/router/module_registry.dart'
    show module;
import 'package:hrm_coffee_shop_flutter/core/presentation/resource_widgets.dart';
import 'package:hrm_coffee_shop_flutter/core/presentation/business_labels.dart';
import 'package:hrm_coffee_shop_flutter/features/documents/presentation/submit_document.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/presentation/linked_resource_list.dart';

List<Widget> buildEmployeeRecordActions(RecordActionContext record,
    {bool linkSections = true}) {
  final context = record.context;
  final ref = record.ref;
  final row = record.row;
  final user = record.user;
  final key = record.key;
  final id = record.id;
  final form = record.form;
  final actions = <Widget>[];
  if (key == 'employees') {
    if (user.has('EMPLOYEE_MANAGE') &&
        ref.read(sessionProvider).workspace != Workspace.manager) {
      actions.add(
        form(
          'Thay đổi trạng thái làm việc',
          '/employees/$id/status',
          const [
            FieldSpec(
              'status',
              'Trạng thái',
              kind: FieldKind.choice,
              required: true,
              options: ['ACTIVE', 'ON_LEAVE', 'SUSPENDED', 'RESIGNED'],
            ),
            FieldSpec('reason', 'Lý do', kind: FieldKind.multiline),
          ],
          initial: {'status': row['employmentStatus']},
          method: 'PATCH',
        ),
      );
    }
    actions.add(
      ResourceView(
        ResourceQuery('/employees/$id/overview'),
        builder: (data) => InfoCard(json(data), title: 'Tổng hợp nhân viên'),
      ),
    );
    actions.add(
      LinkedResourceList(
        '/employees/$id/training',
        module('enrollments'),
        title: 'Đào tạo',
      ),
    );
    if (user.has('DEVICE_APPROVE')) {
      actions.add(
        LinkedResourceList(
          '/attendance/devices/employees/$id',
          module('devices'),
          title: 'Thiết bị chấm công',
        ),
      );
    }
    if (user.has('DOCUMENT_REVIEW')) {
      actions.add(
        LinkedResourceList(
          '/employees/$id/documents',
          module('documents'),
          title: 'Giấy tờ',
        ),
      );
      actions.add(
        ResourceView(
          ResourceQuery('/employees/$id/documents/catalog'),
          builder: (data) => Column(
            children: ResourcePage.parse(data).items.map((r) {
              final type = json(r['documentType']);
              return ListTile(
                title: Text('${type['documentName']}'),
                subtitle: Text(statusLabel(r['status'])),
                trailing: r['canSubmit'] == true
                    ? IconButton(
                        tooltip: 'Nộp thay nhân viên',
                        icon: const Icon(Icons.upload_file),
                        onPressed: () => submitDocument(
                          context,
                          ref,
                          type,
                          employeeId: row['employeeId'] as int,
                        ),
                      )
                    : null,
              );
            }).toList(),
          ),
        ),
      );
    }
    actions.add(
      LinkedResourceList(
        '/employees/$id/skills',
        module('skills'),
        title: 'Đánh giá kỹ năng',
        navigable: false,
      ),
    );
    if (user.has('TRAINING_MANAGE')) {
      actions.add(
        form('Đánh giá kỹ năng', '/employees/$id/skills/assessments', const [
          FieldSpec(
            'skillId',
            'Kỹ năng',
            kind: FieldKind.lookup,
            required: true,
            source: '/skills',
            valueKey: 'skillId',
            labelKey: 'skillName',
          ),
          FieldSpec(
            'level',
            'Mức đánh giá (1–5)',
            kind: FieldKind.integer,
            required: true,
            min: 1,
            max: 5,
          ),
          noteField,
        ]),
      );
    }
  }
  if (!linkSections) return actions;
  return actions.map((action) {
    if (action is LinkedResourceList) {
      return RelatedSection(
          title: action.title,
          icon: action.spec.icon,
          subtitle: 'Mở danh sách và xem chi tiết',
          route:
              '/employee-records/$id/${action.spec.key == 'enrollments' ? 'training' : action.spec.key}');
    }
    if (action is ResourceView) {
      return RelatedSection(
          title: action.query.path.endsWith('overview')
              ? 'Tổng hợp hồ sơ và chấm công'
              : 'Danh mục giấy tờ cần nộp',
          route:
              '/employee-records/$id/${action.query.path.endsWith('overview') ? 'overview' : 'document-catalog'}');
    }
    return action;
  }).toList();
}
