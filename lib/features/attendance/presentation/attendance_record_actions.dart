import 'package:flutter/material.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/presentation/record_action_context.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';
import 'package:hrm_coffee_shop_flutter/core/presentation/resource_widgets.dart';
import 'package:hrm_coffee_shop_flutter/core/presentation/business_labels.dart';
import 'package:hrm_coffee_shop_flutter/core/presentation/open_evidence.dart';
import 'package:hrm_coffee_shop_flutter/features/attendance_requests/domain/attendance_request_fields.dart';

List<Widget> buildAttendanceRecordActions(RecordActionContext record) {
  final context = record.context;
  final row = record.row;
  final key = record.key;
  final id = record.id;
  final own = record.own;
  final form = record.form;
  final actions = <Widget>[];
  if (['my-attendance', 'attendance'].contains(key)) {
    if (own && row['payrollStatus'] != 'LOCKED') {
      actions.add(
        form(
          'Giải trình sự cố chấm công',
          '/attendance/$id/explanation-requests',
          explanationFields,
          initial: {
            'requestedCheckInAt': row['checkInAt'],
            'requestedCheckOutAt': row['checkOutAt'],
          },
        ),
      );
      actions.add(
        form(
          'Đề nghị điều chỉnh giờ công',
          '/attendance/adjustment-requests',
          adjustmentFields,
          initial: {
            'requestedCheckInAt': row['checkInAt'],
            'requestedCheckOutAt': row['checkOutAt'],
          },
          fixed: {'attendanceId': row['attendanceId']},
        ),
      );
      actions.add(
        form('Đăng ký tăng ca', '/attendance/$id/overtime-requests', const [
          FieldSpec(
            'requestedStartAt',
            'Bắt đầu tăng ca (ngày và giờ)',
            kind: FieldKind.dateTime,
            required: true,
          ),
          FieldSpec(
            'requestedEndAt',
            'Kết thúc tăng ca (ngày và giờ)',
            kind: FieldKind.dateTime,
            required: true,
          ),
          FieldSpec(
            'reason',
            'Lý do tăng ca',
            kind: FieldKind.multiline,
            required: true,
          ),
        ]),
      );
    }
    actions.add(const SectionTitle('Lịch sử xác minh'));
    actions.add(
      ResourceView(
        ResourceQuery('/attendance/$id/verifications'),
        builder: (data) => Column(
          children: ResourcePage.parse(data)
              .items
              .map(
                (r) => Card(
                  child: ListTile(
                    title: Text(
                      '${r['verificationType']} · ${statusLabel(r['verificationStatus'])}',
                    ),
                    subtitle: Text(
                      '${dateText(r['verifiedAt'])}${r['distanceMeters'] == null ? '' : ' · ${r['distanceMeters']} m'}${r['failureReason'] == null ? '' : '\n${r['failureReason']}'}',
                    ),
                    trailing: r['evidenceViewUrl'] == null
                        ? null
                        : IconButton(
                            tooltip: 'Xem ảnh',
                            icon: const Icon(Icons.image_outlined),
                            onPressed: () => openEvidence(
                              context,
                              r['evidenceViewUrl'] as String,
                            ),
                          ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
  return actions;
}
