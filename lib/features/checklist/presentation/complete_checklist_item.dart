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
            ? await _chooseEvidence(context, service)
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
                  child: Column(children: [
                    Image.memory(file.bytes, height: 220, fit: BoxFit.contain),
                    Text(file.name),
                  ]),
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

Future<UploadSelection?> _chooseEvidence(
    BuildContext context, EvidenceService service) async {
  final source = await showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(
          leading: const Icon(Icons.camera_alt_outlined),
          title: const Text('Chụp ảnh minh chứng'),
          onTap: () => Navigator.pop(context, 'camera')),
      ListTile(
          leading: const Icon(Icons.photo_library_outlined),
          title: const Text('Chọn ảnh có sẵn'),
          onTap: () => Navigator.pop(context, 'gallery')),
    ])),
  );
  if (source == null || !context.mounted) return null;
  if (source == 'gallery') return service.choose('CHECKLIST');
  final photo =
      await Navigator.of(context, rootNavigator: true).push<Uint8List>(
    MaterialPageRoute(
        builder: (_) => const CameraCapturePage(forChecklist: true)),
  );
  return photo == null
      ? null
      : UploadSelection('checklist.jpg', photo, 'image/jpeg');
}
