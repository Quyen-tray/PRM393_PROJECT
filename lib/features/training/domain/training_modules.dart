import 'package:flutter/material.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';
import 'package:hrm_coffee_shop_flutter/features/workspace/domain/workspace.dart';
import 'package:hrm_coffee_shop_flutter/features/training/domain/training_fields.dart';

final enrollmentsModule = ModuleSpec(
  'enrollments',
  'Chi tiết đào tạo',
  '/training/me',
  'employeeTrainingId',
  'courseName',
  access: (_) => true,
  detail: '/training/enrollments/{id}',
  kind: 'internal',
);

final trainingModule = ModuleSpec(
  'training',
  'Đào tạo của tôi',
  '/training/courses',
  'courseId',
  'courseName',
  access: employee,
  icon: Icons.school_outlined,
  kind: 'training',
  group: 'Công việc',
  workspaces: [Workspace.employee],
);

final trainingReviewsModule = ModuleSpec(
  'training-reviews',
  'Xác nhận đào tạo',
  '/training/completion-reviews/pending',
  'employeeTrainingId',
  'employeeName',
  access: trainingManager,
  detail: '/training/completion-reviews/{id}',
  icon: Icons.school,
  group: 'Duyệt',
);

final coursesModule = ModuleSpec(
  'courses',
  'Quản lý khóa học',
  '/training/courses',
  'courseId',
  'courseName',
  access: trainingManager,
  icon: Icons.menu_book,
  group: 'Danh mục',
  createPath: '/admin/training/courses',
  editPath: '/admin/training/courses/{id}',
  createAccess: admin,
  editAccess: admin,
  fields: courseFields,
);
