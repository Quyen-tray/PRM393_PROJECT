import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../data/mock/admin_demo_data.dart';
import '../../../shared/widgets/app_widgets.dart';
import 'widgets/admin_scaffold.dart';

class AdminChecklistPage extends StatefulWidget {
  const AdminChecklistPage({super.key});

  @override
  State<AdminChecklistPage> createState() => _AdminChecklistPageState();
}

class _AdminChecklistPageState extends State<AdminChecklistPage> {
  bool _showVersions = false;

  List<Widget> _templateRows(BuildContext context) => [
        for (final t in AdminDemoData.templates)
          ListTile(
            title: Text(t.name),
            subtitle: Text('${t.tasks} công việc'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const StatusTag(
                  'v1.0',
                  color: AppColors.secondary,
                  background: Color(0xFFE3EFE6),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => showAppSnack(context, 'Đang mở: ${t.name}'),
                  child: const Text('Sửa'),
                ),
              ],
            ),
          ),
      ];

  List<Widget> get _versionRows => [
        for (final v in AdminDemoData.versions)
          ListTile(
            title: Text('Phiên bản ${v.version}'),
            subtitle: Text(v.desc),
            trailing: StatusTag(
              v.status,
              color: v.active ? AppColors.secondary : AppColors.primary,
              background: v.active ? const Color(0xFFE3EFE6) : const Color(0xFFF0E6DF),
            ),
          ),
      ];

  @override
  Widget build(BuildContext context) => AdminScaffold(
        title: 'Quản lý checklist',
        selectedIndex: 4,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => showAppSnack(context, 'Đã tạo mẫu checklist mới'),
          icon: const Icon(Icons.add),
          label: const Text('Tạo mẫu mới'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Mẫu')),
                  ButtonSegment(value: true, label: Text('Phiên bản')),
                ],
                selected: {_showVersions},
                onSelectionChanged: (s) => setState(() => _showVersions = s.first),
              ),
            ),
            const SizedBox(height: 12),
            AppPanel(
              child: Column(
                children: divided(
                  _showVersions ? _versionRows : _templateRows(context),
                ),
              ),
            ),
          ],
        ),
      );
}
