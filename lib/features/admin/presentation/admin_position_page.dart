import 'package:flutter/material.dart';

import '../../../data/mock/admin_demo_data.dart';
import '../../../shared/widgets/app_widgets.dart';
import 'widgets/admin_scaffold.dart';

class AdminPositionPage extends StatelessWidget {
  const AdminPositionPage({super.key});

  @override
  Widget build(BuildContext context) => AdminScaffold(
        title: 'Quản lý chức vụ',
        selectedIndex: 4,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => showAppSnack(context, 'Đã tạo chức vụ mới'),
          icon: const Icon(Icons.add),
          label: const Text('Thêm chức vụ'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            AppPanel(
              child: Column(
                children: divided([
                  for (final p in AdminDemoData.positions)
                    ListTile(
                      title: Text(p.name),
                      subtitle: Text(p.desc),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${p.count} người'),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () => showAppSnack(context, 'Đang mở: ${p.name}'),
                            child: const Text('Sửa'),
                          ),
                        ],
                      ),
                    ),
                ]),
              ),
            ),
          ],
        ),
      );
}
