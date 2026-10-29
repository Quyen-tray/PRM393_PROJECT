import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../data/mock/demo_data.dart';
import 'widgets/admin_bottom_navigation.dart';
import 'widgets/admin_more_menu.dart';

enum _ChecklistAdminTab { templates, versions }

class AdminChecklistManagementPage extends StatefulWidget {
  const AdminChecklistManagementPage({super.key});

  @override
  State<AdminChecklistManagementPage> createState() =>
      _AdminChecklistManagementPageState();
}

class _AdminChecklistManagementPageState
    extends State<AdminChecklistManagementPage> {
  late List<DemoAdminChecklistTemplate> _templates;
  late List<DemoAdminChecklistVersion> _versions;
  _ChecklistAdminTab _selectedTab = _ChecklistAdminTab.templates;

  @override
  void initState() {
    super.initState();
    _templates = List.of(DemoData.adminChecklistTemplates);
    _versions = List.of(DemoData.adminChecklistVersions);
  }

  Future<void> _showTemplateForm({
    DemoAdminChecklistTemplate? template,
  }) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: template?.name ?? '');
    final taskCountController = TextEditingController(
      text: '${template?.taskCount ?? 5}',
    );

    final draft = await showDialog<_TemplateDraft>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(template == null ? 'Thêm template' : 'Sửa template'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Tên checklist',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập tên checklist.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: taskCountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Số công việc',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final count = int.tryParse(value ?? '');
                  if (count == null || count < 1) {
                    return 'Số công việc phải lớn hơn 0.';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;

              Navigator.pop(
                dialogContext,
                _TemplateDraft(
                  name: nameController.text.trim(),
                  taskCount: int.parse(taskCountController.text),
                ),
              );
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    nameController.dispose();
    taskCountController.dispose();

    if (!mounted || draft == null) return;

    setState(() {
      if (template == null) {
        final templateId = 'checklist_${_templates.length + 1}';

        _templates.insert(
          0,
          DemoAdminChecklistTemplate(
            id: templateId,
            name: draft.name,
            taskCount: draft.taskCount,
            activeVersion: 'v1.0',
          ),
        );
        _versions.insert(
          0,
          DemoAdminChecklistVersion(
            templateId: templateId,
            version: 'v1.0',
            taskCount: draft.taskCount,
            updatedAt: '13/10/2026',
            status: DemoAdminChecklistVersionStatus.active,
          ),
        );
        return;
      }

      final templateIndex = _templates.indexOf(template);
      if (templateIndex == -1) return;

      _templates[templateIndex] = template.copyWith(
        name: draft.name,
        taskCount: draft.taskCount,
      );

      final activeVersionIndex = _versions.indexWhere(
        (version) =>
            version.templateId == template.id &&
            version.status == DemoAdminChecklistVersionStatus.active,
      );

      if (activeVersionIndex != -1) {
        _versions[activeVersionIndex] = _versions[activeVersionIndex].copyWith(
          taskCount: draft.taskCount,
        );
      }
    });
  }

  void _activateVersion(DemoAdminChecklistVersion selectedVersion) {
    setState(() {
      for (var index = 0; index < _versions.length; index++) {
        final version = _versions[index];
        if (version.templateId != selectedVersion.templateId) continue;

        final newStatus = version.version == selectedVersion.version
            ? DemoAdminChecklistVersionStatus.active
            : version.status == DemoAdminChecklistVersionStatus.active
                ? DemoAdminChecklistVersionStatus.archived
                : version.status;

        _versions[index] = version.copyWith(status: newStatus);
      }

      final templateIndex = _templates.indexWhere(
        (template) => template.id == selectedVersion.templateId,
      );

      if (templateIndex != -1) {
        _templates[templateIndex] = _templates[templateIndex].copyWith(
          activeVersion: selectedVersion.version,
          taskCount: selectedVersion.taskCount,
        );
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã kích hoạt phiên bản checklist.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showingTemplates = _selectedTab == _ChecklistAdminTab.templates;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Quản lý checklist'),
        leading: IconButton(
          tooltip: 'Quay lại Dashboard Admin',
          onPressed: () => context.go(RouteNames.adminHome),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: _ChecklistTabChip(
                    label: 'Template',
                    selected: showingTemplates,
                    onTap: () => setState(
                      () => _selectedTab = _ChecklistAdminTab.templates,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ChecklistTabChip(
                    label: 'Phiên bản',
                    selected: !showingTemplates,
                    onTap: () => setState(
                      () => _selectedTab = _ChecklistAdminTab.versions,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: showingTemplates
                ? ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: _templates.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 9),
                    itemBuilder: (context, index) {
                      final template = _templates[index];

                      return _TemplateCard(
                        template: template,
                        onTap: () => _showTemplateForm(template: template),
                      );
                    },
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: _versions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 9),
                    itemBuilder: (context, index) {
                      final version = _versions[index];
                      final template = _templates.firstWhere(
                        (item) => item.id == version.templateId,
                      );

                      return _VersionCard(
                        templateName: template.name,
                        version: version,
                        onActivate: () => _activateVersion(version),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: showingTemplates
          ? FloatingActionButton(
              onPressed: () => _showTemplateForm(),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: AdminBottomNavigation(
        selectedIndex: 4,
        onDestinationSelected: (index) {
          if (index == 0) {
            context.go(RouteNames.adminHome);
          } else if (index == 1) {
            context.go(RouteNames.adminAccounts);
          } else if (index == 2) {
            context.go(RouteNames.adminPositions);
          } else if (index == 3) {
            context.go(RouteNames.adminTraining);
          } else {
            showAdminMoreMenu(context);
          }
        },
      ),
    );
  }
}

class _ChecklistTabChip extends StatelessWidget {
  const _ChecklistTabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: SizedBox(
        width: double.infinity,
        child: Text(label, textAlign: TextAlign.center),
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(
        color: selected ? AppColors.primary : const Color(0xFFEDE8E3),
      ),
      showCheckmark: false,
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.onTap,
  });

  final DemoAdminChecklistTemplate template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDE8E3)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 6,
        ),
        leading: const Icon(
          Icons.fact_check_outlined,
          color: AppColors.primary,
        ),
        title: Text(
          template.name,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '${template.taskCount} task · ${template.activeVersion}',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        trailing: const Icon(
          Icons.edit_outlined,
          color: AppColors.textSecondary,
          size: 19,
        ),
      ),
    );
  }
}

class _VersionCard extends StatelessWidget {
  const _VersionCard({
    required this.templateName,
    required this.version,
    required this.onActivate,
  });

  final String templateName;
  final DemoAdminChecklistVersion version;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    final isActive = version.status == DemoAdminChecklistVersionStatus.active;
    final statusLabel = switch (version.status) {
      DemoAdminChecklistVersionStatus.active => 'Đang dùng',
      DemoAdminChecklistVersionStatus.draft => 'Bản nháp',
      DemoAdminChecklistVersionStatus.archived => 'Lưu trữ',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDE8E3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.history, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  templateName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${version.version} · ${version.taskCount} task · '
                  '${version.updatedAt}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: isActive ? AppColors.secondary : AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (!isActive)
            TextButton(
              onPressed: onActivate,
              child: const Text('Kích hoạt'),
            ),
        ],
      ),
    );
  }
}

class _TemplateDraft {
  const _TemplateDraft({
    required this.name,
    required this.taskCount,
  });

  final String name;
  final int taskCount;
}
