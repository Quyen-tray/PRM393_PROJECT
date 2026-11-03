import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/repositories/employee_providers.dart';

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _displayDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int _intOf(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

/// Một mục trong danh mục để chọn (loại hồ sơ hoặc khóa học).
class _CatalogEntry {
  const _CatalogEntry({required this.id, required this.name});

  final int id;
  final String name;
}

/// Một yêu cầu của chức vụ đang soạn. [id] là documentTypeId hoặc courseId.
class _ReqDraft {
  _ReqDraft({
    required this.id,
    required this.name,
    required this.isMandatory,
    required this.blocksShift,
    required this.from,
    this.to,
  });

  factory _ReqDraft.fromDocument(Map<String, dynamic> row) {
    final type = row['documentType'] is Map
        ? Map<String, dynamic>.from(row['documentType'] as Map)
        : <String, dynamic>{};
    return _ReqDraft(
      id: _intOf(type['documentTypeId']),
      name: (type['documentName'] ?? 'Loại hồ sơ').toString(),
      isMandatory: row['isMandatory'] != false,
      blocksShift: false,
      from: _dateOnly(
        DateTime.tryParse('${row['effectiveFrom']}') ?? DateTime.now(),
      ),
      to: row['effectiveTo'] == null
          ? null
          : _dateOnly(DateTime.parse('${row['effectiveTo']}')),
    );
  }

  factory _ReqDraft.fromTraining(Map<String, dynamic> row) => _ReqDraft(
    id: _intOf(row['courseId']),
    name: (row['courseName'] ?? 'Khóa học').toString(),
    isMandatory: row['isMandatory'] != false,
    blocksShift: row['blocksShiftAssignment'] == true,
    from: _dateOnly(
      DateTime.tryParse('${row['effectiveFrom']}') ?? DateTime.now(),
    ),
    to: row['effectiveTo'] == null
        ? null
        : _dateOnly(DateTime.parse('${row['effectiveTo']}')),
  );

  final int id;
  final String name;
  bool isMandatory;
  bool blocksShift;
  DateTime from;
  DateTime? to;

  Map<String, dynamic> toDocumentRequest() => {
    'documentTypeId': id,
    'isMandatory': isMandatory,
    'effectiveFrom': _isoDate(from),
    if (to != null) 'effectiveTo': _isoDate(to!),
  };

  Map<String, dynamic> toTrainingRequest() => {
    'courseId': id,
    'isMandatory': isMandatory,
    'blocksShiftAssignment': blocksShift,
    'effectiveFrom': _isoDate(from),
    if (to != null) 'effectiveTo': _isoDate(to!),
  };
}

/// Màn cấu hình yêu cầu giấy tờ và khóa bắt buộc của một chức vụ.
/// Máy chủ thay toàn bộ danh sách mỗi lần lưu, nên app luôn gửi danh sách đầy đủ.
class AdminPositionRequirementsPage extends ConsumerStatefulWidget {
  const AdminPositionRequirementsPage({super.key, required this.position});

  final Map<String, dynamic> position;

  @override
  ConsumerState<AdminPositionRequirementsPage> createState() =>
      _AdminPositionRequirementsPageState();
}

class _AdminPositionRequirementsPageState
    extends ConsumerState<AdminPositionRequirementsPage> {
  List<_ReqDraft> _documents = [];
  List<_ReqDraft> _trainings = [];
  List<_CatalogEntry> _documentTypes = [];
  List<_CatalogEntry> _courses = [];
  bool _loading = true;
  String? _error;
  int _version = 0;

  int get _positionId => _intOf(widget.position['positionId']);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(employeeRepositoryProvider);
      final results = await Future.wait<Object>([
        repo.getAdminDocumentTypes(), // 0
        repo.getPositionDocumentRequirements(_positionId), // 1
        repo.getTrainingCourses(), // 2
        repo.getPositionTrainingRequirements(_positionId), // 3
      ]);
      if (!mounted) return;
      setState(() {
        _documentTypes = (results[0] as List<Map<String, dynamic>>)
            .where((row) => row['isActive'] != false)
            .map(
              (row) => _CatalogEntry(
                id: _intOf(row['documentTypeId']),
                name: (row['documentName'] ?? 'Loại hồ sơ').toString(),
              ),
            )
            .toList();
        _documents = (results[1] as List<Map<String, dynamic>>)
            .map(_ReqDraft.fromDocument)
            .toList();
        _courses = (results[2] as List<Map<String, dynamic>>)
            .where((row) => row['isActive'] != false)
            .map(
              (row) => _CatalogEntry(
                id: _intOf(row['courseId']),
                name: (row['courseName'] ?? 'Khóa học').toString(),
              ),
            )
            .toList();
        _trainings = (results[3] as List<Map<String, dynamic>>)
            .map(_ReqDraft.fromTraining)
            .toList();
        _version++;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Không tải được yêu cầu của chức vụ.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveDocuments(List<_ReqDraft> drafts) async {
    await ref
        .read(employeeRepositoryProvider)
        .replacePositionDocumentRequirements(_positionId, [
          for (final draft in drafts) draft.toDocumentRequest(),
        ]);
    _showMessage('Đã lưu yêu cầu giấy tờ.');
    await _load();
  }

  Future<void> _saveTrainings(List<_ReqDraft> drafts) async {
    await ref
        .read(employeeRepositoryProvider)
        .replacePositionTrainingRequirements(_positionId, [
          for (final draft in drafts) draft.toTrainingRequest(),
        ]);
    _showMessage('Đã lưu khóa bắt buộc của chức vụ.');
    await _load();
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.position['positionName'] ?? 'Chức vụ').toString();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              tooltip: 'Tải lại',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Giấy tờ'),
              Tab(text: 'Khóa bắt buộc'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _load,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              )
            : TabBarView(
                children: [
                  _RequirementEditor(
                    key: ValueKey('docs-$_version'),
                    initial: _documents,
                    catalog: _documentTypes,
                    withBlocking: false,
                    emptyMessage: 'Chức vụ chưa yêu cầu giấy tờ nào.',
                    addLabel: 'Thêm loại hồ sơ',
                    onSave: _saveDocuments,
                  ),
                  _RequirementEditor(
                    key: ValueKey('trainings-$_version'),
                    initial: _trainings,
                    catalog: _courses,
                    withBlocking: true,
                    emptyMessage: 'Chức vụ chưa yêu cầu khóa bắt buộc nào.',
                    addLabel: 'Thêm khóa bắt buộc',
                    onSave: _saveTrainings,
                  ),
                ],
              ),
      ),
    );
  }
}

/// Danh sách yêu cầu có thể thêm, sửa, xóa; lưu toàn bộ danh sách qua [onSave].
class _RequirementEditor extends StatefulWidget {
  const _RequirementEditor({
    super.key,
    required this.initial,
    required this.catalog,
    required this.withBlocking,
    required this.emptyMessage,
    required this.addLabel,
    required this.onSave,
  });

  final List<_ReqDraft> initial;
  final List<_CatalogEntry> catalog;
  final bool withBlocking;
  final String emptyMessage;
  final String addLabel;
  final Future<void> Function(List<_ReqDraft> drafts) onSave;

  @override
  State<_RequirementEditor> createState() => _RequirementEditorState();
}

class _RequirementEditorState extends State<_RequirementEditor> {
  late final List<_ReqDraft> _drafts = [...widget.initial];
  bool _saving = false;

  Future<void> _addOrEdit({int? index}) async {
    final draft = await showDialog<_ReqDraft>(
      context: context,
      builder: (_) => _DraftDialog(
        catalog: widget.catalog,
        existing: index == null ? null : _drafts[index],
        usedIds: {for (final draft in _drafts) draft.id},
        withBlocking: widget.withBlocking,
      ),
    );
    if (draft == null || !mounted) return;
    setState(() {
      if (index == null) {
        _drafts.add(draft);
      } else {
        _drafts[index] = draft;
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.onSave(_drafts);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                error is ApiException
                    ? error.message
                    : 'Không lưu được yêu cầu.',
              ),
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _drafts.isEmpty
              ? Center(
                  child: Text(
                    widget.emptyMessage,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  itemCount: _drafts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _DraftCard(
                    draft: _drafts[index],
                    withBlocking: widget.withBlocking,
                    onEdit: _saving ? null : () => _addOrEdit(index: index),
                    onDelete: _saving
                        ? null
                        : () => setState(() => _drafts.removeAt(index)),
                  ),
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : () => _addOrEdit(),
                    icon: const Icon(Icons.add),
                    label: Text(widget.addLabel),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Lưu'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({
    required this.draft,
    required this.withBlocking,
    required this.onEdit,
    required this.onDelete,
  });

  final _ReqDraft draft;
  final bool withBlocking;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final window = draft.to == null
        ? 'Từ ${_displayDate(draft.from)}, không thời hạn'
        : 'Từ ${_displayDate(draft.from)} đến ${_displayDate(draft.to!)}';
    final flags = [
      draft.isMandatory ? 'Bắt buộc' : 'Không bắt buộc',
      if (withBlocking && draft.blocksShift) 'Chặn nhận ca',
    ];
    return Card(
      color: AppColors.surface,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    draft.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    flags.join(' · '),
                    style: TextStyle(
                      color: draft.isMandatory
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    window,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Sửa',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Xóa',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hộp thoại thêm hoặc sửa một yêu cầu. Khi thêm, chỉ hiện các mục chưa có trong danh sách.
class _DraftDialog extends StatefulWidget {
  const _DraftDialog({
    required this.catalog,
    required this.existing,
    required this.usedIds,
    required this.withBlocking,
  });

  final List<_CatalogEntry> catalog;
  final _ReqDraft? existing;
  final Set<int> usedIds;
  final bool withBlocking;

  @override
  State<_DraftDialog> createState() => _DraftDialogState();
}

class _DraftDialogState extends State<_DraftDialog> {
  late int? _id = widget.existing?.id;
  late bool _mandatory = widget.existing?.isMandatory ?? true;
  late bool _blocks = widget.existing?.blocksShift ?? false;
  late DateTime _from = widget.existing?.from ?? _dateOnly(DateTime.now());
  late DateTime? _to = widget.existing?.to;
  String? _error;

  List<_CatalogEntry> get _options {
    if (widget.existing != null) return widget.catalog;
    return [
      for (final entry in widget.catalog)
        if (!widget.usedIds.contains(entry.id)) entry,
    ];
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _from = _dateOnly(picked));
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to ?? _from,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _to = _dateOnly(picked));
  }

  void _submit() {
    final id = _id;
    if (id == null) {
      setState(() => _error = 'Chọn một mục.');
      return;
    }
    if (_to != null && _to!.isBefore(_from)) {
      setState(
        () => _error = 'Ngày hết hiệu lực phải sau hoặc bằng ngày có hiệu lực.',
      );
      return;
    }
    final name = _options
        .firstWhere(
          (entry) => entry.id == id,
          orElse: () => widget.catalog.firstWhere(
            (entry) => entry.id == id,
            orElse: () =>
                _CatalogEntry(id: id, name: widget.existing?.name ?? 'Mục'),
          ),
        )
        .name;
    Navigator.pop(
      context,
      _ReqDraft(
        id: id,
        name: name,
        isMandatory: _mandatory,
        blocksShift: widget.withBlocking && _blocks,
        from: _from,
        to: _to,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return AlertDialog(
      title: Text(editing ? 'Sửa yêu cầu' : 'Thêm yêu cầu'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (editing)
            Text(
              widget.existing!.name,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            DropdownButtonFormField<int>(
              initialValue: _id,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Chọn mục',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final entry in _options)
                  DropdownMenuItem(value: entry.id, child: Text(entry.name)),
              ],
              onChanged: (value) => setState(() => _id = value),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Bắt buộc'),
            value: _mandatory,
            onChanged: (value) => setState(() => _mandatory = value),
          ),
          if (widget.withBlocking)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Chặn nhận ca khi chưa đạt'),
              value: _blocks,
              onChanged: (value) => setState(() => _blocks = value),
            ),
          const SizedBox(height: 6),
          OutlinedButton(
            onPressed: _pickFrom,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Có hiệu lực từ: ${_displayDate(_from)}'),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _pickTo,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _to == null
                    ? 'Hết hiệu lực: không thời hạn'
                    : 'Hết hiệu lực: ${_displayDate(_to!)}',
              ),
            ),
          ),
          if (_to != null)
            TextButton(
              onPressed: () => setState(() => _to = null),
              child: const Text('Bỏ ngày hết hiệu lực'),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Lưu')),
      ],
    );
  }
}
