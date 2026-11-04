import 'package:hrm_coffee_shop_flutter/core/presentation/business_labels.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';

String rowTitle(ModuleSpec spec, Json row) =>
    valueText(spec.titleKey, row[spec.titleKey] ?? row['title'] ?? spec.title);
String rowSubtitle(ModuleSpec spec, Json row) {
  if (spec.kind == 'notifications') {
    return '${row['message'] ?? ''}\n${dateText(row['createdAt'])}${row['readAt'] == null ? ' · Chưa đọc' : ''}';
  }
  if (spec.kind == 'schedule') {
    return '${json(row['workShift'])['shiftName'] ?? ''}\n${dateText(row['plannedStartAt'])} → ${dateText(row['plannedEndAt'])} · ${statusLabel(row['status'])}';
  }
  return [
    if (row['roles'] is List)
      (row['roles'] as List)
          .map((r) => switch (r) {
                'EMPLOYEE' => 'Nhân viên',
                'STORE_MANAGER' => 'Quản lý',
                'SYSTEM_ADMIN' => 'Quản trị',
                _ => statusLabel(r)
              })
          .join(' · '),
    if (row['attendanceStatus'] != null) statusLabel(row['attendanceStatus']),
    if ((row['lateMinutes'] as num? ?? 0) > 0)
      'Đi muộn ${row['lateMinutes']} phút',
    if ((row['earlyLeaveMinutes'] as num? ?? 0) > 0)
      'Về sớm ${row['earlyLeaveMinutes']} phút',
    if (row['employeeCode'] != null) '${row['employeeCode']}',
    if (row['email'] != null) '${row['email']}',
    if (row['employeeName'] != null && spec.titleKey != 'employeeName')
      '${row['employeeName']}',
    if (row['workDate'] != null && spec.titleKey != 'workDate')
      dateText(row['workDate']),
    if (spec.key == 'devices' && row['deviceLabel'] != null)
      '${row['deviceLabel']}',
    if ((row['status'] ?? row['reviewStatus'] ?? row['employmentStatus']) !=
        null)
      statusLabel(
        row['status'] ?? row['reviewStatus'] ?? row['employmentStatus'],
      ),
    if (row['dueAt'] != null) 'Hạn ${dateText(row['dueAt'])}',
    if (row['description'] != null) '${row['description']}',
  ].join(' · ');
}
