import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hrm_coffee_shop_flutter/core/presentation/business_labels.dart';
import 'package:hrm_coffee_shop_flutter/core/presentation/resource_widgets.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';
import 'package:hrm_coffee_shop_flutter/features/documents/presentation/submit_document.dart';

class MyDocumentsPage extends ConsumerWidget {
  const MyDocumentsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => PageBody(
        onRefresh: () async {
          ref.read(dataRevisionProvider.notifier).changed();
        },
        children: [
          const SectionTitle('Giấy tờ cần nộp'),
          ResourceView(
            const ResourceQuery('/employees/me/documents/catalog'),
            builder: (data) => Column(
              children: ResourcePage.parse(data).items.map((r) {
                final type = json(r['documentType']);
                return Card(
                  child: ListTile(
                    title: Text('${type['documentName']}'),
                    subtitle: Text(
                      '${r['mandatory'] == true ? 'Bắt buộc' : 'Tùy chọn'} · ${statusLabel(r['status'])}${r['rejectionReason'] == null ? '' : '\n${r['rejectionReason']}'}',
                    ),
                    trailing: r['canSubmit'] == true
                        ? IconButton(
                            tooltip: 'Nộp giấy tờ',
                            icon: const Icon(Icons.upload_file),
                            onPressed: () => submitDocument(context, ref, type),
                          )
                        : const Icon(Icons.hourglass_empty),
                  ),
                );
              }).toList(),
            ),
          ),
          const SectionTitle('Lịch sử nộp hồ sơ'),
          ResourceView(
            const ResourceQuery('/employees/me/documents'),
            builder: (data) => Column(
              children: ResourcePage.parse(data)
                  .items
                  .map(
                    (r) => Card(
                      child: ListTile(
                        title:
                            Text('${json(r['documentType'])['documentName']}'),
                        subtitle: Text(
                          '${statusLabel(r['reviewStatus'])} · ${dateText(r['uploadedAt'])}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(
                          '/record/my-document-records/${r['documentId']}',
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      );
}
