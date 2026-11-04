import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/repositories/employee_providers.dart';

/// Nhãn tiếng Việt cho loại checklist (ChecklistType trong backend).
const checklistTypes = <String, String>{
  'OPENING': 'Mở ca',
  'CLOSING': 'Đóng ca',
  'HANDOVER': 'Bàn giao ca',
  'SERVICE': 'Phục vụ',
  'INVENTORY': 'Kiểm kê',
};

String checklistTypeLabel(String? type) => checklistTypes[type] ?? (type ?? 'Chưa rõ');

int _intOf(Object? value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;

/// Một công việc trong mẫu, đang soạn thảo trên màn hình.
class _ItemDraft {
  _ItemDraft({
    required this.name,
    required this.instructions,
    required this.isRequired,
    required this.requiresEvidence,
    required this.requiresManagerApproval,
  });

  factory _ItemDraft.fromMap(Map<String, dynamic> map) => _ItemDraft(
        name: (map['itemName'] ?? '').toString(),
        instructions: (map['instructions'] ?? '').toString(),
        isRequired: map['isRequired'] != false,
        requiresEvidence: map['requiresEvidence'] == true,
        requiresManagerApproval: map['requiresManagerApproval'] == true,
      );

  factory _ItemDraft.blank() => _ItemDraft(
        name: '',
        instructions: '',
        isRequired: true,
        requiresEvidence: false,
        requiresManagerApproval: false,
      );

  String name;
  String instructions;
  bool isRequired;
  bool requiresEvidence;
  bool requiresManagerApproval;

  Map<String, dynamic> toRequest(int sortOrder) => {
        'itemName': name.trim(),
        if (instructions.trim().isNotEmpty) 'instructions': instructions.trim(),
        'isRequired': isRequired,
        'requiresEvidence': requiresEvidence,
        'requiresManagerApproval': requiresManagerApproval,
        'sortOrder': sortOrder,
      };
}

/// Tạo mới hoặc sửa một mẫu checklist. [template] là một phiên bản (TemplateView) khi sửa.
/// Đóng với một thông báo (String) khi đã lưu.
class AdminChecklistTemplateEditorPage extends ConsumerStatefulWidget {
  const AdminChecklistTemplateEditorPage({super.key, this.template});

  final Map<String, dynamic>? template;

  @override
  ConsumerState<AdminChecklistTemplateEditorPage> createState() =>
      _AdminChecklistTemplateEditorPageState();
}

class _AdminChecklistTemplateEditorPageState extends ConsumerState<AdminChecklistTemplateEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _name;
  late String _type;
  late bool _managerApproval;
  late List<_ItemDraft> _items;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.template != null;

  @override
  void initState() {
    super.initState();
    final template = widget.template;
    _code = TextEditingController(text: (template?['checklistCode'] ?? '').toString());
    _name = TextEditingController(text: (template?['checklistName'] ?? '').toString());
    _type = (template?['checklistType'] ?? 'SERVICE').toString();
    _managerApproval = template?['managerApprovalRequired'] == true;
    final rawItems = (template?['items'] as List?)?.whereType<Map>().toList() ?? <Map>[];
    rawItems.sort((a, b) => _intOf(a['sortOrder']).compareTo(_intOf(b['sortOrder'])));
    _items = [for (final item in rawItems) _ItemDraft.fromMap(Map<String, dynamic>.from(item))];
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _editItem({int? index}) async {
    final current = index == null ? _ItemDraft.blank() : _items[index];
    final draft = await showDialog<_ItemDraft>(
      context: context,
      builder: (dialogContext) => _ItemDialog(initial: current),
    );
    if (draft == null || !mounted) return;
    setState(() {
      if (index == null) {
        _items.add(draft);
      } else {
        _items[index] = draft;
      }
    });
  }

  void _move(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _items.length) return;
    setState(() {
      final item = _items.removeAt(index);
      _items.insert(target, item);
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_items.isEmpty) {
      setState(() => _error = 'Cần ít nhất một công việc trong mẫu.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final payload = <String, dynamic>{
      'checklistCode': _code.text.trim(),
      'checklistName': _name.text.trim(),
      'checklistType': _type,
      'managerApprovalRequired': _managerApproval,
      // Mẫu mới được kích hoạt ngay; khi sửa, trạng thái hoạt động giữ nguyên theo máy chủ.
      if (!_isEditing) 'isActive': true,
      'items': [for (var i = 0; i < _items.length; i++) _items[i].toRequest(i + 1)],
    };

    final repo = ref.read(employeeRepositoryProvider);
    try {
      if (!_isEditing) {
        await repo.createAdminChecklistTemplate(payload);
        if (mounted) Navigator.pop(context, 'Đã tạo mẫu checklist.');
        return;
      }
      final id = _intOf(widget.template!['templateId']);
      final oldVersion = _intOf(widget.template!['version']);
      final saved = await repo.updateAdminChecklistTemplate(id, payload);
      final newVersion = _intOf(saved['version']);
      if (!mounted) return;
      final message = newVersion != oldVersion
          ? 'Mẫu đã có lượt thực hiện nên đã tạo phiên bản v$newVersion. '
              'Kích hoạt ở tab Phiên bản để áp dụng.'
          : 'Đã lưu mẫu checklist.';
      Navigator.pop(context, message);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is ApiException ? error.message : 'Không lưu được mẫu checklist.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Quay lại',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(RouteNames.adminChecklistTemplates);
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(_isEditing ? 'Sửa mẫu checklist' : 'Tạo mẫu checklist'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            TextFormField(
              controller: _code,
              enabled: !_isEditing,
              maxLength: 40,
              decoration: InputDecoration(
                labelText: 'Mã checklist',
                helperText: _isEditing ? 'Mã không đổi khi sửa mẫu.' : 'Ví dụ: MO_CA_QUAY',
                border: const OutlineInputBorder(),
              ),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Nhập mã checklist.' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _name,
              maxLength: 150,
              decoration: const InputDecoration(
                labelText: 'Tên checklist',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? 'Nhập tên checklist.' : null,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _type,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Loại checklist', border: OutlineInputBorder()),
              items: [
                for (final entry in checklistTypes.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _type = value);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Cần quản lý duyệt sau khi nộp'),
              value: _managerApproval,
              onChanged: (value) => setState(() => _managerApproval = value),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Công việc',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton.icon(
                  onPressed: _saving ? null : () => _editItem(),
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm công việc'),
                ),
              ],
            ),
            if (_items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('Chưa có công việc nào.', style: TextStyle(color: AppColors.textSecondary)),
                ),
              )
            else
              for (var index = 0; index < _items.length; index++)
                _ItemTile(
                  index: index,
                  total: _items.length,
                  item: _items[index],
                  onEdit: _saving ? null : () => _editItem(index: index),
                  onUp: _saving ? null : () => _move(index, -1),
                  onDown: _saving ? null : () => _move(index, 1),
                  onDelete: _saving
                      ? null
                      : () => setState(() => _items.removeAt(index)),
                ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Lưu mẫu'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({
    required this.index,
    required this.total,
    required this.item,
    required this.onEdit,
    required this.onUp,
    required this.onDown,
    required this.onDelete,
  });

  final int index;
  final int total;
  final _ItemDraft item;
  final VoidCallback? onEdit;
  final VoidCallback? onUp;
  final VoidCallback? onDown;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final flags = [
      if (item.isRequired) 'Bắt buộc',
      if (item.requiresEvidence) 'Cần ảnh',
      if (item.requiresManagerApproval) 'Quản lý duyệt',
    ];
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Text(
                '${index + 1}',
                style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    flags.isEmpty ? 'Không bắt buộc' : flags.join(' · '),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Lên',
              onPressed: index == 0 ? null : onUp,
              icon: const Icon(Icons.arrow_upward, size: 18),
            ),
            IconButton(
              tooltip: 'Xuống',
              onPressed: index == total - 1 ? null : onDown,
              icon: const Icon(Icons.arrow_downward, size: 18),
            ),
            IconButton(
              tooltip: 'Sửa công việc',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
            ),
            IconButton(
              tooltip: 'Xóa công việc',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemDialog extends StatefulWidget {
  const _ItemDialog({required this.initial});

  final _ItemDraft initial;

  @override
  State<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<_ItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(text: widget.initial.name);
  late final TextEditingController _instructions = TextEditingController(text: widget.initial.instructions);
  late bool _isRequired = widget.initial.isRequired;
  late bool _requiresEvidence = widget.initial.requiresEvidence;
  late bool _requiresManagerApproval = widget.initial.requiresManagerApproval;

  @override
  void dispose() {
    _name.dispose();
    _instructions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial.name.isEmpty ? 'Thêm công việc' : 'Sửa công việc'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Tên công việc', border: OutlineInputBorder()),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Nhập tên công việc.' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _instructions,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(labelText: 'Hướng dẫn (không bắt buộc)', border: OutlineInputBorder()),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Bắt buộc hoàn thành'),
                value: _isRequired,
                onChanged: (value) => setState(() => _isRequired = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Cần ảnh minh chứng'),
                value: _requiresEvidence,
                onChanged: (value) => setState(() => _requiresEvidence = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Quản lý duyệt công việc này'),
                value: _requiresManagerApproval,
                onChanged: (value) => setState(() => _requiresManagerApproval = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.pop(
              context,
              _ItemDraft(
                name: _name.text.trim(),
                instructions: _instructions.text.trim(),
                isRequired: _isRequired,
                requiresEvidence: _requiresEvidence,
                requiresManagerApproval: _requiresManagerApproval,
              ),
            );
          },
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}
