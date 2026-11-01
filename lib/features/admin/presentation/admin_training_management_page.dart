import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../data/mock/demo_data.dart';
import 'widgets/admin_bottom_navigation.dart';
import 'widgets/admin_more_menu.dart';

enum _TrainingFilter { all, mandatory, inProgress, completed }

class AdminTrainingManagementPage extends StatefulWidget {
  const AdminTrainingManagementPage({super.key});

  @override
  State<AdminTrainingManagementPage> createState() =>
      _AdminTrainingManagementPageState();
}

class _AdminTrainingManagementPageState
    extends State<AdminTrainingManagementPage> {
  static const _filters = <(_TrainingFilter, String)>[
    (_TrainingFilter.all, 'Tất cả'),
    (_TrainingFilter.mandatory, 'Bắt buộc'),
    (_TrainingFilter.inProgress, 'Đang học'),
    (_TrainingFilter.completed, 'Đã hoàn thành'),
  ];

  late List<DemoAdminTrainingItem> _items;
  DemoAdminTrainingType _selectedType = DemoAdminTrainingType.course;
  _TrainingFilter _selectedFilter = _TrainingFilter.all;

  @override
  void initState() {
    super.initState();
    _items = List.of(DemoData.adminTrainingItems);
  }

  List<DemoAdminTrainingItem> get _visibleItems {
    return _items.where((item) {
      if (item.type != _selectedType) return false;

      return switch (_selectedFilter) {
        _TrainingFilter.all => true,
        _TrainingFilter.mandatory => item.isMandatory,
        _TrainingFilter.inProgress =>
          item.completedCount > 0 && item.completedCount < item.totalCount,
        _TrainingFilter.completed =>
          item.totalCount > 0 && item.completedCount >= item.totalCount,
      };
    }).toList();
  }

  Future<void> _showCourseForm({DemoAdminTrainingItem? item}) async {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: item?.title ?? '');
    var isMandatory = item?.isMandatory ?? true;

    final draft = await showDialog<_CourseDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(item == null ? 'Thêm khóa học' : 'Sửa khóa học'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Tên khóa học',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập tên khóa học.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isMandatory,
                  title: const Text('Khóa học bắt buộc'),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => isMandatory = value);
                    }
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
                  _CourseDraft(
                    title: titleController.text.trim(),
                    isMandatory: isMandatory,
                  ),
                );
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );

    titleController.dispose();

    if (!mounted || draft == null) return;

    setState(() {
      if (item == null) {
        _items.insert(
          0,
          DemoAdminTrainingItem(
            title: draft.title,
            type: DemoAdminTrainingType.course,
            isMandatory: draft.isMandatory,
            completedCount: 0,
            totalCount: 15,
          ),
        );
        return;
      }

      final index = _items.indexOf(item);
      if (index != -1) {
        _items[index] = item.copyWith(
          title: draft.title,
          isMandatory: draft.isMandatory,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _visibleItems;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Quản lý đào tạo'),
        leading: IconButton(
          tooltip: 'Quay lại Dashboard Admin',
          onPressed: () => context.go(RouteNames.adminHome),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Row(
              children: [
                for (final type in DemoAdminTrainingType.values)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: ChoiceChip(
                        label: SizedBox(
                          width: double.infinity,
                          child: Text(
                            _typeLabel(type),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        selected: _selectedType == type,
                        onSelected: (_) {
                          setState(() {
                            _selectedType = type;
                            _selectedFilter = _TrainingFilter.all;
                          });
                        },
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.surface,
                        labelStyle: TextStyle(
                          color: _selectedType == type
                              ? Colors.white
                              : AppColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        side: BorderSide(
                          color: _selectedType == type
                              ? AppColors.primary
                              : const Color(0xFFEDE8E3),
                        ),
                        showCheckmark: false,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final (filter, label) = _filters[index];
                final selected = _selectedFilter == filter;

                return ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedFilter = filter),
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(
                    color: selected
                        ? AppColors.primary
                        : const Color(0xFFEDE8E3),
                  ),
                  showCheckmark: false,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: visibleItems.isEmpty
                ? const Center(
                    child: Text(
                      'Không có nội dung phù hợp.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: visibleItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 9),
                    itemBuilder: (context, index) {
                      final item = visibleItems[index];

                      return _TrainingItemCard(
                        item: item,
                        canEdit: item.type == DemoAdminTrainingType.course,
                        onEdit: () => _showCourseForm(item: item),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: _selectedType == DemoAdminTrainingType.course
          ? FloatingActionButton(
              onPressed: () => _showCourseForm(),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: AdminBottomNavigation(
        selectedIndex: 3,
        onDestinationSelected: (index) {
          if (index == 0) {
            context.go(RouteNames.adminHome);
            return;
          }
          if (index == 1) {
            context.go(RouteNames.adminAccounts);
            return;
          }
          if (index == 2) {
            context.go(RouteNames.adminPositions);
            return;
          }
          if (index == 3) return;

          showAdminMoreMenu(context);
        },
      ),
    );
  }
}

class _TrainingItemCard extends StatelessWidget {
  const _TrainingItemCard({
    required this.item,
    required this.canEdit,
    required this.onEdit,
  });

  final DemoAdminTrainingItem item;
  final bool canEdit;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final progress = item.totalCount == 0
        ? 0.0
        : (item.completedCount / item.totalCount).clamp(0.0, 1.0).toDouble();
    final progressPercent = (progress * 100).round();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDE8E3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1E4D8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _typeIcon(item.type),
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.isMandatory ? 'Bắt buộc' : 'Tùy chọn',
                      style: TextStyle(
                        color: item.isMandatory
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (canEdit)
                IconButton(
                  tooltip: 'Sửa khóa học',
                  onPressed: onEdit,
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: AppColors.textSecondary,
                    size: 19,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: const Color(0xFFEDE8E3),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF28A765),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$progressPercent%',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${item.completedCount}/${item.totalCount} nhân viên hoàn thành',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _typeLabel(DemoAdminTrainingType type) {
  return switch (type) {
    DemoAdminTrainingType.course => 'Khóa học',
    DemoAdminTrainingType.skill => 'Kỹ năng',
    DemoAdminTrainingType.certificate => 'Chứng chỉ',
  };
}

IconData _typeIcon(DemoAdminTrainingType type) {
  return switch (type) {
    DemoAdminTrainingType.course => Icons.menu_book_outlined,
    DemoAdminTrainingType.skill => Icons.psychology_alt_outlined,
    DemoAdminTrainingType.certificate => Icons.workspace_premium_outlined,
  };
}

class _CourseDraft {
  const _CourseDraft({
    required this.title,
    required this.isMandatory,
  });

  final String title;
  final bool isMandatory;
}
