import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_coffee_shop_flutter/core/presentation/resource_widgets.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/common_fields.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/presentation/record_form.dart';

class PositionRequirements extends ConsumerWidget {
  const PositionRequirements(this.id, {super.key});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
        children: [
          requirement(context, ref, 'document', 'Yêu cầu giấy tờ', [
            documentTypeField,
            requiredField,
            const FieldSpec('effectiveFrom', 'Hiệu lực từ',
                kind: FieldKind.date),
            const FieldSpec('effectiveTo', 'Hiệu lực đến',
                kind: FieldKind.date),
          ]),
          requirement(context, ref, 'training', 'Yêu cầu đào tạo', [
            courseField,
            requiredField,
            const FieldSpec('effectiveFrom', 'Hiệu lực từ',
                kind: FieldKind.date),
            const FieldSpec('effectiveTo', 'Hiệu lực đến',
                kind: FieldKind.date),
          ]),
        ],
      );
  Widget requirement(
    BuildContext context,
    WidgetRef ref,
    String type,
    String title,
    List<FieldSpec> fields,
  ) =>
      ResourceView(
        ResourceQuery('/admin/job-positions/$id/$type-requirements'),
        builder: (data) {
          final rows = ResourcePage.parse(data).items;
          final normalized = rows
              .map(
                (r) => {
                  ...r,
                  if (type == 'document')
                    'documentTypeId': json(r['documentType'])['documentTypeId'],
                },
              )
              .toList();
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  if (type == 'training')
                    const Text(
                      'Yêu cầu đào tạo được theo dõi nhưng không chặn phân ca hoặc chấm công.',
                    ),
                  if (type == 'document')
                    const Text(
                        'Các giấy tờ nhân viên cần nộp khi giữ chức vụ này. Đánh dấu bắt buộc để theo dõi tình trạng hồ sơ.'),
                  if (rows.isEmpty)
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Chưa thiết lập yêu cầu.')),
                  ...rows.map((r) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(r['isMandatory'] == true
                            ? Icons.assignment_late_outlined
                            : Icons.assignment_outlined),
                        title: Text(
                            '${r['courseName'] ?? json(r['documentType'])['documentName'] ?? 'Yêu cầu'}'),
                        subtitle: Text(
                            r['isMandatory'] == true ? 'Bắt buộc' : 'Tùy chọn'),
                      )),
                  OutlinedButton(
                    onPressed: () => editRecord(
                      context,
                      ref,
                      title: title,
                      fields: [
                        FieldSpec(
                          'requirements',
                          title,
                          kind: FieldKind.array,
                          fields: fields,
                        ),
                      ],
                      initial: {'requirements': normalized},
                      path: '/admin/job-positions/$id/$type-requirements',
                      method: 'PUT',
                    ),
                    child: const Text('Chỉnh sửa yêu cầu áp dụng'),
                  ),
                ],
              ),
            ),
          );
        },
      );
}
