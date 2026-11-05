import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_coffee_shop_flutter/core/storage/evidence_service.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/presentation/record_form.dart';

Future<void> submitDocument(
  BuildContext context,
  WidgetRef ref,
  Json type, {
  int? employeeId,
}) async {
  final service = ref.read(evidenceServiceProvider);
  final repository = ref.read(resourceRepositoryProvider);
  final revision = ref.read(dataRevisionProvider.notifier);
  Object? error;
  try {
    final file = await service.choose('DOCUMENT');
    if (file == null || !context.mounted) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => RecordForm(
          title: 'Nộp ${type['documentName']}',
          fields: const [
            FieldSpec('issuedAt', 'Ngày cấp', kind: FieldKind.date),
            FieldSpec('expiresAt', 'Ngày hết hạn', kind: FieldKind.date),
          ],
          onSubmit: (value) async {
            final key = await service.upload(
              file,
              'DOCUMENT',
              employeeId: employeeId,
            );
            await repository.write(
              'POST',
              employeeId == null
                  ? '/employees/me/documents'
                  : '/employees/$employeeId/documents',
              {
                'documentTypeId': type['documentTypeId'],
                'storageKey': key,
                ...value,
              },
            );
            revision.changed();
          },
        ),
      ),
    );
  } catch (e) {
    error = e;
  }
  if (error != null && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }
}
