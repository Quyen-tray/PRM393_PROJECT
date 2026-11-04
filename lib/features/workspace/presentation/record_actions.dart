import 'package:hrm_coffee_shop_flutter/features/attendance_requests/presentation/attendance_request_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/data/session_controller.dart';
import 'package:hrm_coffee_shop_flutter/core/presentation/resource_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/presentation/record_action_context.dart';
import 'package:hrm_coffee_shop_flutter/features/schedule/presentation/schedule_record_actions.dart';
import 'package:hrm_coffee_shop_flutter/features/attendance/presentation/attendance_record_actions.dart';
import 'package:hrm_coffee_shop_flutter/features/devices/presentation/devices_record_actions.dart';
import 'package:hrm_coffee_shop_flutter/features/checklist/presentation/checklist_record_actions.dart';
import 'package:hrm_coffee_shop_flutter/features/training/presentation/training_record_actions.dart';
import 'package:hrm_coffee_shop_flutter/features/documents/presentation/documents_record_actions.dart';
import 'package:hrm_coffee_shop_flutter/features/violations/presentation/violations_record_actions.dart';
import 'package:hrm_coffee_shop_flutter/features/rewards/presentation/rewards_record_actions.dart';
import 'package:hrm_coffee_shop_flutter/features/payroll/presentation/payroll_record_actions.dart';
import 'package:hrm_coffee_shop_flutter/features/accounts/presentation/accounts_record_actions.dart';
import 'package:hrm_coffee_shop_flutter/features/employees/presentation/employees_record_actions.dart';
import 'package:hrm_coffee_shop_flutter/features/positions/presentation/positions_record_actions.dart';

class RecordActions extends ConsumerWidget {
  const RecordActions({required this.spec, required this.row, super.key});
  final ModuleSpec spec;
  final Json row;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).user!;
    final record = RecordActionContext(
        context: context, ref: ref, spec: spec, row: row, user: user);
    final actions = <Widget>[];
    actions.addAll(buildScheduleRecordActions(record));
    actions.addAll(buildAttendanceRecordActions(record));
    actions.addAll(buildDeviceRecordActions(record));
    actions.addAll(buildExplanationRecordActions(record));
    actions.addAll(buildOvertimeRecordActions(record));
    actions.addAll(buildAdjustmentRecordActions(record));
    actions.addAll(buildChecklistRecordActions(record));
    actions.addAll(buildTrainingReviewRecordActions(record));
    actions.addAll(buildEnrollmentRecordActions(record));
    actions.addAll(buildDocumentRecordActions(record));
    actions.addAll(buildViolationRecordActions(record));
    actions.addAll(buildRewardDecisionRecordActions(record));
    if (row['violationEventId'] != null) {
      actions.add(
        OutlinedButton(
          onPressed: () => context.push(
            '/record/${user.has('VIOLATION_REVIEW') ? 'violations' : 'my-violations'}/${row['violationEventId']}',
          ),
          child: const Text('Vi phạm nguồn'),
        ),
      );
    }
    actions.addAll(buildPayrollRecordActions(record));
    actions.addAll(buildAccountRecordActions(record));
    actions.addAll(buildEmployeeRecordActions(record));
    actions.addAll(buildPositionRecordActions(record));
    actions.addAll(buildCourseRecordActions(record));
    actions.addAll(buildChecklistTemplateRecordActions(record));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (actions.isNotEmpty)
          SectionTitle(switch (spec.key) {
            'positions' => 'Điều kiện theo chức vụ',
            'employees' => 'Hồ sơ nhân viên',
            'templates' => 'Sử dụng mẫu',
            'accounts' => 'Vai trò và quyền truy cập',
            _ => 'Xử lý yêu cầu'
          }),
        ...actions.map(
          (a) => Padding(padding: const EdgeInsets.only(bottom: 10), child: a),
        ),
      ],
    );
  }
}
