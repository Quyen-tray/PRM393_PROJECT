import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_coffee_shop_flutter/core/storage/evidence_service.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/common_fields.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/presentation/record_form.dart';
import '../../attendance/presentation/camera_capture_page.dart';

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
            ? await _captureEvidence(context)
            : null;
    if (item['requiresEvidence'] == true &&
        item['hasEvidence'] != true &&
        file == null) {
      return;
    }
    if (!context.mounted) return;
    String? uploadedKey;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => RecordForm(
          title: 'Hoàn thành ${item['itemName']}',
          fields: const [noteField],
          initial: {'note': item['note']},
          header: file == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Image.memory(file.bytes,
                      height: 220, fit: BoxFit.contain),
                ),
          onSubmit: (v) async {
            if (file != null) {
              uploadedKey ??= await service.upload(file, 'CHECKLIST');
            }
            await repository.write(
              'POST',
              '/checklists/tasks/$taskId/items/${item['runItemId']}/complete',
              {
                ...v,
                if (uploadedKey != null) 'evidenceStorageKey': uploadedKey
              },
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

Future<UploadSelection?> _captureEvidence(BuildContext context) async {
  final photo =
      await Navigator.of(context, rootNavigator: true).push<Uint8List>(
    MaterialPageRoute(
        builder: (_) => const CameraCapturePage(forChecklist: true)),
  );
  return photo == null
      ? null
      : UploadSelection('checklist.jpg', photo, 'image/jpeg');
}
