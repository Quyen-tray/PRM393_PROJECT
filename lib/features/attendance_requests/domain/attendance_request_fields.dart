import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';

const explanationFields = [
  FieldSpec(
    'reasonCode',
    'Loại sự cố',
    kind: FieldKind.choice,
    required: true,
    options: [
      'GPS_UNAVAILABLE',
      'MISSED_CHECK_IN',
      'MISSED_CHECK_OUT',
      'DEVICE_ISSUE',
      'CAMERA_ISSUE',
      'BUSINESS_TRIP',
      'OTHER',
    ],
  ),
  FieldSpec(
    'reason',
    'Nội dung giải trình',
    kind: FieldKind.multiline,
    required: true,
  ),
  FieldSpec(
    'requestedCheckInAt',
    'Giờ vào đề nghị (ngày và giờ)',
    kind: FieldKind.dateTime,
  ),
  FieldSpec(
    'requestedCheckOutAt',
    'Giờ ra đề nghị (ngày và giờ)',
    kind: FieldKind.dateTime,
  ),
  FieldSpec(
    'evidenceStorageKey',
    'Ảnh minh chứng (tùy chọn)',
    kind: FieldKind.upload,
    source: 'ATTENDANCE',
  ),
];
const adjustmentFields = [
  FieldSpec(
    'reasonCode',
    'Lý do điều chỉnh',
    kind: FieldKind.choice,
    required: true,
    options: ['INCORRECT_TIME', 'DEVICE_ISSUE', 'OTHER'],
  ),
  FieldSpec(
    'reason',
    'Nội dung yêu cầu',
    kind: FieldKind.multiline,
    required: true,
  ),
  FieldSpec(
    'requestedCheckInAt',
    'Giờ vào đề nghị (ngày và giờ)',
    kind: FieldKind.dateTime,
  ),
  FieldSpec(
    'requestedCheckOutAt',
    'Giờ ra đề nghị (ngày và giờ)',
    kind: FieldKind.dateTime,
  ),
  FieldSpec(
    'evidenceStorageKey',
    'Ảnh minh chứng (tùy chọn)',
    kind: FieldKind.upload,
    source: 'ATTENDANCE',
  ),
];
