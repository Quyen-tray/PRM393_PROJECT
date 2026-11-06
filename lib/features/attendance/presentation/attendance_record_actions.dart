import 'package:flutter/material.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/presentation/record_action_context.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/presentation/action_command.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';
import 'package:hrm_coffee_shop_flutter/core/presentation/resource_widgets.dart';
import 'package:hrm_coffee_shop_flutter/core/presentation/business_labels.dart';
import 'package:hrm_coffee_shop_flutter/core/presentation/open_evidence.dart';
import 'package:hrm_coffee_shop_flutter/features/attendance_requests/domain/attendance_request_fields.dart';

String verificationEventLabel(dynamic event) {
  switch (event) {
    case 'CHECK_IN':
      return 'Check-in';
    case 'CHECK_OUT':
      return 'Check-out';
    case 'SPOT_CHECK':
      return 'Kiểm tra giữa ca';
    default:
      return 'Chấm công';
  }
}

List<Widget> buildAttendanceRecordActions(RecordActionContext record) {
  final context = record.context;
  final row = record.row;
  final key = record.key;
  final id = record.id;
  final own = record.own;
  final form = record.form;
  final actions = <Widget>[];
  if (['my-attendance', 'attendance'].contains(key)) {
    if (key == 'attendance' &&
        record.user.has('ATTENDANCE_REVIEW') &&
        row['attendanceStatus'] == 'CHECKED_IN') {
      final spotCheck = json(row['spotCheck']);
      final spotCheckStatus = spotCheck['status']?.toString();
      if (spotCheckStatus == null ||
          ['NOT_SELECTED', 'SCHEDULED'].contains(spotCheckStatus)) {
        actions.add(ActionCommand(
          'attendance-spot-check-$id',
          'Yêu cầu kiểm tra giữa ca ngay',
          '/attendance/$id/spot-check',
        ));
      } else if (spotCheckStatus == 'REQUESTED') {
        actions.add(Text(
          'Đã gửi yêu cầu kiểm tra giữa ca. Hạn phản hồi: ${dateText(spotCheck['responseDeadlineAt'])}',
        ));
      } else if (spotCheckStatus == 'VERIFIED') {
        actions.add(const Text('Nhân viên đã xác nhận kiểm tra giữa ca.'));
      } else if (spotCheckStatus == 'MISSED') {
        actions.add(const Text('Nhân viên đã bỏ lỡ lượt kiểm tra giữa ca.'));
      }
    }
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
                      '${verificationEventLabel(r['eventType'])} · ${r['verificationType']} · ${statusLabel(r['verificationStatus'])}',
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
