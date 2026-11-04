import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_coffee_shop_flutter/core/storage/evidence_service.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/common_fields.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/presentation/record_form.dart';

Future<void> completeChecklistItem(
  BuildContext context,
  WidgetRef ref,
  String taskId,
  Json item,
) async {
  final repository = ref.read(resourceRepositoryProvider);
  final revision = ref.read(dataRevisionProvider.notifier);
  try {
    final service = ref.read(evidenceServiceProvider);
    final file =
        item['requiresEvidence'] == true && !(item['hasEvidence'] == true)
            ? await service.choose('CHECKLIST')
            : null;
    if (item['requiresEvidence'] == true &&
        item['hasEvidence'] != true &&
        file == null) {
      return;
    }
    if (!context.mounted) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => RecordForm(
          title: 'Hoàn thành ${item['itemName']}',
          fields: const [noteField],
          onSubmit: (v) async {
            String? key;
            if (file != null) key = await service.upload(file, 'CHECKLIST');
            await repository.write(
              'POST',
              '/checklists/tasks/$taskId/items/${item['runItemId']}/complete',
              {...v, if (key != null) 'evidenceStorageKey': key},
            );
            revision.changed();
          },
        ),
      ),
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}
