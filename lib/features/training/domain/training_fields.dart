import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/common_fields.dart';

const quizQuestionFields = [
  FieldSpec(
    'questionText',
    'Câu hỏi',
    kind: FieldKind.multiline,
    required: true,
  ),
  FieldSpec('optionA', 'Đáp án A', required: true),
  FieldSpec('optionB', 'Đáp án B', required: true),
  FieldSpec('optionC', 'Đáp án C', required: true),
  FieldSpec('optionD', 'Đáp án D', required: true),
  FieldSpec(
    'correctOption',
    'Đáp án đúng',
    kind: FieldKind.choice,
    required: true,
    options: ['A', 'B', 'C', 'D'],
  ),
  FieldSpec(
    'sortOrder',
    'Thứ tự',
    kind: FieldKind.integer,
    required: true,
    min: 1,
  ),
];
const courseFields = [
  FieldSpec('courseCode', 'Mã khóa học', required: true),
  FieldSpec('courseName', 'Tên khóa học', required: true),
  FieldSpec(
    'description',
    'Nội dung và hướng dẫn học',
    kind: FieldKind.multiline,
  ),
  FieldSpec(
    'passScore',
    'Điểm đạt (%)',
    kind: FieldKind.decimal,
    required: true,
    min: 0,
    max: 100,
    defaultValue: 70,
  ),
  FieldSpec(
    'validityMonths',
    'Hiệu lực (tháng)',
    kind: FieldKind.integer,
    min: 1,
  ),
  FieldSpec(
    'isMandatoryTest',
    'Có bài kiểm tra trắc nghiệm',
    kind: FieldKind.toggle,
  ),
  activeField,
];
