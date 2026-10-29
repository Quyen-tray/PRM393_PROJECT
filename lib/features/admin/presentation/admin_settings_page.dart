import 'package:flutter/material.dart';

import '../../../data/mock/admin_demo_data.dart';
import '../../../shared/widgets/app_widgets.dart';
import 'widgets/admin_scaffold.dart';

class AdminSettingsPage extends StatelessWidget {
  const AdminSettingsPage({super.key});

  @override
  Widget build(BuildContext context) => AdminScaffold(
        title: 'Cấu hình hệ thống',
        selectedIndex: 3,
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            AppPanel(
              child: Column(
                children: divided([
                  for (final s in AdminDemoData.settings)
                    ListTile(
                      title: Text(s.title),
                      subtitle: Text(s.value),
                      trailing: OutlinedButton(
                        onPressed: () => showAppSnack(context, 'Đang mở: ${s.title}'),
                        child: const Text('Sửa'),
                      ),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => showAppSnack(context, 'Đã lưu cấu hình'),
                child: const Text('Lưu thay đổi'),
              ),
            ),
          ],
        ),
      );
}
