import 'package:hrm_coffee_shop_flutter/features/attendance_requests/domain/attendance_request_modules.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';
import 'package:hrm_coffee_shop_flutter/features/training/domain/training_modules.dart';
import 'package:hrm_coffee_shop_flutter/features/documents/domain/documents_modules.dart';
import 'package:hrm_coffee_shop_flutter/features/schedule/domain/schedule_modules.dart';
import 'package:hrm_coffee_shop_flutter/features/attendance/domain/attendance_modules.dart';
import 'package:hrm_coffee_shop_flutter/features/checklist/domain/checklist_modules.dart';
import 'package:hrm_coffee_shop_flutter/features/devices/domain/devices_modules.dart';
import 'package:hrm_coffee_shop_flutter/features/violations/domain/violations_modules.dart';
import 'package:hrm_coffee_shop_flutter/features/rewards/domain/rewards_modules.dart';
import 'package:hrm_coffee_shop_flutter/features/employees/domain/employees_modules.dart';
import 'package:hrm_coffee_shop_flutter/features/payroll/domain/payroll_modules.dart';
import 'package:hrm_coffee_shop_flutter/features/reports/domain/reports_modules.dart';
import 'package:hrm_coffee_shop_flutter/features/accounts/domain/accounts_modules.dart';
import 'package:hrm_coffee_shop_flutter/features/positions/domain/positions_modules.dart';
import 'package:hrm_coffee_shop_flutter/features/store/domain/store_modules.dart';
import 'package:hrm_coffee_shop_flutter/features/notifications/domain/notifications_modules.dart';
import 'package:hrm_coffee_shop_flutter/features/skills/domain/skills_modules.dart';
import 'package:hrm_coffee_shop_flutter/features/audit/domain/audit_modules.dart';
export 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';
export 'package:hrm_coffee_shop_flutter/shared/resources/domain/common_fields.dart';

// Feature definitions own API paths, fields and access rules. Preserve navigation order here.
final modules = <ModuleSpec>[
  enrollmentsModule,
  myDocumentRecordsModule,
  myScheduleModule,
  myAttendanceModule,
  myChecklistsModule,
  trainingModule,
  myDocumentsModule,
  myDevicesModule,
  myExplanationsModule,
  myOvertimeModule,
  myAdjustmentsModule,
  myViolationsModule,
  myRewardsModule,
  employeesModule,
  assignmentsModule,
  shiftsModule,
  attendanceModule,
  devicesModule,
  explanationsModule,
  overtimeModule,
  adjustmentsModule,
  checklistsModule,
  checklistReviewsModule,
  trainingReviewsModule,
  documentsModule,
  violationsModule,
  decisionsModule,
  payrollModule,
  reportsAttendanceModule,
  reportsOperationsModule,
  accountsModule,
  positionsModule,
  coursesModule,
  templatesModule,
  documentTypesModule,
  storeSettingsModule,
  reminderRulesModule,
  skillsModule,
  auditModule,
  deliveriesModule,
  notificationsModule,
];
ModuleSpec module(String key) => modules.firstWhere((m) => m.key == key);
