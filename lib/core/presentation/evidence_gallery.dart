import 'package:flutter/material.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_endpoints.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';
import 'resource_widgets.dart';

class EvidenceGallery extends StatelessWidget {
  const EvidenceGallery(this.path, {this.itemId, super.key});
  final String path;
  final Object? itemId;
  @override
  Widget build(BuildContext context) =>
      ResourceView(ResourceQuery(path), builder: (data) {
        final rows = ResourcePage.parse(data)
            .items
            .where((r) =>
                (itemId == null || '${r['runItemId']}' == '$itemId') &&
                r['evidenceViewUrl'] != null)
            .toList();
        if (rows.isEmpty) {
          return const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Chưa có ảnh bằng chứng được phép xem.'));
        }
        return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: rows.asMap().entries.map((entry) {
              final uri = Uri.parse(ApiEndpoints.baseUrl)
                  .resolve('${entry.value['evidenceViewUrl']}');
              return OutlinedButton.icon(
                  icon: const Icon(Icons.image_outlined),
                  label: Text('Xem ảnh ${entry.key + 1}'),
                  onPressed: () => showDialog<void>(
                      context: context,
                      builder: (dialog) => Dialog.fullscreen(
                              child: Scaffold(
                            appBar: AppBar(title: const Text('Ảnh bằng chứng')),
                            body: Center(
                                child: InteractiveViewer(
                                    minScale: .5,
                                    maxScale: 5,
                                    child: Image.network(
                                      uri.toString(),
                                      loadingBuilder: (_, image, progress) =>
                                          progress == null
                                              ? image
                                              : const CircularProgressIndicator(),
                                      errorBuilder: (_, error, stack) =>
                                          const Padding(
                                              padding: EdgeInsets.all(24),
                                              child: Text(
                                                  'Ảnh đã hết hạn hoặc không tải được. Đóng ảnh và tải lại chi tiết để lấy liên kết mới.')),
                                    ))),
                          ))));
            }).toList());
      });
}
