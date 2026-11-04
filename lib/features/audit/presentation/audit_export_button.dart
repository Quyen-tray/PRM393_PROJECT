import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hrm_coffee_shop_flutter/core/presentation/resource_widgets.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';
import 'package:hrm_coffee_shop_flutter/features/audit/data/audit_repository.dart';

class AuditExportButton extends ConsumerWidget {
  const AuditExportButton(this.query, {super.key});
  final Json query;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(operationProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          icon: const Icon(Icons.download),
          label: const Text('Xuất CSV · tối đa 5.000 dòng'),
          onPressed: state.busy.contains('export-audit')
              ? null
              : () => ref.read(operationProvider.notifier).run(
                    'export-audit',
                    () async {
                      final csv = await ref
                          .read(auditRepositoryProvider)
                          .exportAudit(query);
                      await FilePicker.saveFile(
                        fileName:
                            'hrm-audit-${DateTime.now().toIso8601String().substring(0, 10)}.csv',
                        bytes: Uint8List.fromList(utf8.encode('\uFEFF$csv')),
                        mimeType: 'text/csv',
                      );
                    },
                  ),
        ),
        if (state.errors['export-audit'] != null)
          ErrorPanel(state.errors['export-audit']!),
      ],
    );
  }
}
