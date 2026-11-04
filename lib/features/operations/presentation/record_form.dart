import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/presentation/business_labels.dart';
import '../../../core/presentation/resource_widgets.dart';
import '../data/operations_repository.dart';
import '../domain/module_registry.dart';
import 'lookup_picker.dart';
import '../../../core/storage/evidence_service.dart';

Future<bool?> editRecord(BuildContext context, WidgetRef ref,
    {required String title,
    required List<FieldSpec> fields,
    Json initial = const {},
    required String path,
    String method = 'POST',
    Json fixed = const {}}) {
  final repository = ref.read(operationsRepositoryProvider);
  final revision = ref.read(dataRevisionProvider.notifier);
  return Navigator.of(context, rootNavigator: true)
      .push<bool>(MaterialPageRoute(
          builder: (_) => RecordForm(
              title: title,
              fields: fields,
              initial: initial,
              onSubmit: (value) async {
                await repository.write(method, path, {...value, ...fixed});
                revision.changed();
              })));
}

class RecordForm extends ConsumerStatefulWidget {
  const RecordForm(
      {required this.title,
      required this.fields,
      this.initial = const {},
      required this.onSubmit,
      super.key});
  final String title;
  final List<FieldSpec> fields;
  final Json initial;
  final Future<void> Function(Json value) onSubmit;
  @override
  ConsumerState<RecordForm> createState() => _RecordFormState();
}

class _RecordFormState extends ConsumerState<RecordForm> {
  final _form = GlobalKey<FormState>();
  final values = <String, dynamic>{};
  final controllers = <String, TextEditingController>{};
  bool busy = false;
  Object? error;
  @override
  void initState() {
    super.initState();
    for (final f in widget.fields) {
      dynamic value = widget.initial[f.key] ?? f.defaultValue;
      if (value == null && f.key == 'workShiftId') {
        value = json(widget.initial['workShift'])['shiftId'];
      }
      if (value == null && f.key == 'documentTypeId') {
        value = json(widget.initial['documentType'])['documentTypeId'];
      }
      if (f.kind == FieldKind.toggle) value ??= false;
      if (f.kind == FieldKind.array || f.kind == FieldKind.multiple) {
        value ??= [];
      }
      values[f.key] = value;
      controllers[f.key] = TextEditingController(
          text: value == null
              ? ''
              : [FieldKind.date, FieldKind.dateTime].contains(f.kind)
                  ? dateText(value)
                  : '$value');
    }
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !_form.currentState!.validate()) return;
    _form.currentState!.save();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget
          .onSubmit({...values}..removeWhere((key, value) => value == null));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !busy,
      child: Scaffold(
          appBar: AppBar(title: Text(widget.title)),
          body: PageBody(children: [
            Form(
                key: _form,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ...widget.fields.map((f) => Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: field(f))),
                      if (error != null) ErrorPanel(error!),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                          onPressed: busy ? null : submit,
                          icon: busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.check),
                          label: Text(busy ? 'Đang lưu…' : 'Lưu và hoàn tất')),
                    ]))
          ])));
  Widget field(FieldSpec f) {
    final label = '${f.label}${f.required ? ' *' : ''}';
    final decoration =
        InputDecoration(labelText: label, border: const OutlineInputBorder());
    if (f.kind == FieldKind.upload) {
      return FormField<dynamic>(
          validator: (_) => f.required && values[f.key] == null
              ? 'Cần tải lên minh chứng'
              : null,
          builder: (field) =>
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                    icon: const Icon(Icons.attach_file),
                    label: Text(values[f.key] == null
                        ? 'Chọn và tải minh chứng'
                        : 'Đã tải: ${controllers[f.key]!.text}'),
                    onPressed: busy
                        ? null
                        : () async {
                            try {
                              final service = ref.read(evidenceServiceProvider);
                              final file = await service
                                  .choose(f.source ?? 'ATTENDANCE');
                              if (file == null || !mounted) return;
                              setState(() {
                                busy = true;
                                error = null;
                              });
                              final key = await service.upload(
                                  file, f.source ?? 'ATTENDANCE');
                              if (mounted) {
                                setState(() {
                                  values[f.key] = key;
                                  controllers[f.key]!.text = file.name;
                                  field.didChange(key);
                                });
                              }
                            } catch (e) {
                              if (mounted) setState(() => error = e);
                            } finally {
                              if (mounted) setState(() => busy = false);
                            }
                          }),
                if (field.hasError)
                  Text(field.errorText!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
              ]));
    }
    if (f.kind == FieldKind.toggle) {
      return SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          value: values[f.key] == true,
          onChanged: busy ? null : (v) => setState(() => values[f.key] = v));
    }
    if (f.kind == FieldKind.multiple) {
      return FormField<List>(
          initialValue: List.from(values[f.key] ?? []),
          validator: (v) => f.required && (values[f.key] as List).isEmpty
              ? 'Chọn ít nhất một giá trị'
              : null,
          builder: (state) =>
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label),
                Wrap(
                    spacing: 8,
                    children: f.options
                        .map((option) => FilterChip(
                            label: Text(roleName(option)),
                            selected: (values[f.key] as List).contains(option),
                            onSelected: busy
                                ? null
                                : (v) => setState(() {
                                      final list = List.from(values[f.key]);
                                      v
                                          ? list.add(option)
                                          : list.remove(option);
                                      values[f.key] = list;
                                      state.didChange(list);
                                    })))
                        .toList()),
                if (state.hasError)
                  Text(state.errorText!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error))
              ]));
    }
    if (f.kind == FieldKind.choice) {
      return DropdownButtonFormField<String>(
          initialValue: f.options.contains(values[f.key])
              ? values[f.key] as String
              : null,
          decoration: decoration,
          isExpanded: true,
          items: f.options
              .map((v) =>
                  DropdownMenuItem(value: v, child: Text(statusLabel(v))))
              .toList(),
          onChanged: busy ? null : (v) => values[f.key] = v,
          validator: (v) => f.required && v == null ? 'Vui lòng chọn' : null);
    }
    if (f.kind == FieldKind.lookup) {
      return FormField<dynamic>(
          initialValue: values[f.key],
          validator: (_) => f.required && values[f.key] == null
              ? 'Vui lòng chọn dữ liệu đã có trên hệ thống'
              : null,
          builder: (state) => InputDecorator(
              decoration: decoration.copyWith(errorText: state.errorText),
              child: InkWell(
                  onTap: busy
                      ? null
                      : () async {
                          final row =
                              await Navigator.of(context, rootNavigator: true)
                                  .push<Json>(MaterialPageRoute(
                                      builder: (_) => LookupPicker(f)));
                          if (row != null && mounted) {
                            setState(() {
                              values[f.key] = row[f.valueKey];
                              controllers[f.key]!.text =
                                  '${row[f.labelKey] ?? row[f.valueKey]}';
                              state.didChange(values[f.key]);
                            });
                          }
                        },
                  child: Row(children: [
                    Expanded(
                        child: Text(values[f.key] == null
                            ? 'Chọn từ danh sách'
                            : controllers[f.key]!.text ==
                                    values[f.key].toString()
                                ? 'Đã chọn · bấm để thay đổi'
                                : controllers[f.key]!.text)),
                    const Icon(Icons.expand_more)
                  ]))));
    }
    if (f.kind == FieldKind.array) {
      return FormField<List>(
          validator: (_) => f.required && (values[f.key] as List).isEmpty
              ? 'Cần thêm ít nhất một mục'
              : null,
          builder: (state) =>
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: Theme.of(context).textTheme.titleSmall),
                ...(values[f.key] as List).asMap().entries.map((e) => Card(
                    child: ListTile(
                        title: Text(
                            '${json(e.value)['itemName'] ?? json(e.value)['questionText'] ?? 'Mục ${e.key + 1}'}'),
                        onTap: busy ? null : () => editArray(f, e.key),
                        trailing: IconButton(
                            tooltip: 'Xóa mục',
                            icon: const Icon(Icons.close),
                            onPressed: busy
                                ? null
                                : () => setState(() => (values[f.key] as List)
                                    .removeAt(e.key)))))),
                TextButton.icon(
                    onPressed: busy ? null : () => editArray(f, null),
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm mục')),
                if (state.hasError)
                  Text(state.errorText!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error))
              ]));
    }
    if ([FieldKind.date, FieldKind.dateTime, FieldKind.time].contains(f.kind)) {
      return TextFormField(
          controller: controllers[f.key],
          readOnly: true,
          decoration: decoration.copyWith(
              suffixIcon: const Icon(Icons.calendar_today_outlined)),
          validator: (_) => f.required && values[f.key] == null
              ? 'Vui lòng chọn thời gian'
              : null,
          onTap: busy ? null : () => pickDate(f));
    }
    return TextFormField(
        controller: controllers[f.key],
        decoration: decoration,
        maxLines: f.kind == FieldKind.multiline ? 4 : 1,
        keyboardType: [FieldKind.integer, FieldKind.decimal].contains(f.kind)
            ? const TextInputType.numberWithOptions(decimal: true, signed: true)
            : f.kind == FieldKind.multiline
                ? TextInputType.multiline
                : TextInputType.text,
        enabled: !busy,
        validator: (v) {
          if ((v ?? '').trim().isEmpty) {
            return f.required ? 'Không được bỏ trống' : null;
          }
          if ([FieldKind.integer, FieldKind.decimal].contains(f.kind)) {
            final n = f.kind == FieldKind.integer
                ? int.tryParse(v!)
                : num.tryParse(v!);
            if (n == null) return 'Nhập số hợp lệ';
            if (f.min != null && n < f.min!) {
              return 'Giá trị tối thiểu ${f.min}';
            }
            if (f.max != null && n > f.max!) return 'Giá trị tối đa ${f.max}';
          }
          if (f.key == 'email' &&
              !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v!.trim())) {
            return 'Email chưa hợp lệ';
          }
          return null;
        },
        onSaved: (v) => values[f.key] = (v ?? '').trim().isEmpty
            ? null
            : f.kind == FieldKind.integer
                ? int.parse(v!)
                : f.kind == FieldKind.decimal
                    ? num.parse(v!)
                    : v!.trim());
  }

  Future<void> editArray(FieldSpec f, int? index) async {
    final list = values[f.key] as List;
    await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
        builder: (_) => RecordForm(
            title: index == null ? 'Thêm ${f.label.toLowerCase()}' : 'Sửa mục',
            fields: f.fields,
            initial: index == null
                ? {'sortOrder': list.length + 1}
                : json(list[index]),
            onSubmit: (v) async {
              setState(() => index == null ? list.add(v) : list[index] = v);
            })));
  }

  Future<void> pickDate(FieldSpec f) async {
    DateTime? date = DateTime.tryParse('${values[f.key]}')?.toLocal();
    final originalTime = date;
    if (f.kind != FieldKind.time) {
      date = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime(2100));
      if (date == null || !mounted) return;
    }
    String pad(int n) => '$n'.padLeft(2, '0');
    if (f.kind == FieldKind.date) {
      setState(() {
        values[f.key] = '${date!.year}-${pad(date.month)}-${pad(date.day)}';
        controllers[f.key]!.text = dateText(values[f.key]);
      });
      return;
    }
    if (!mounted) return;
    final timeParts = '${values[f.key]}'.split(':');
    final initialTime = f.kind == FieldKind.time && timeParts.length >= 2
        ? TimeOfDay(
            hour: int.tryParse(timeParts[0]) ?? 0,
            minute: int.tryParse(timeParts[1]) ?? 0)
        : originalTime == null
            ? TimeOfDay.now()
            : TimeOfDay.fromDateTime(originalTime);
    final time =
        await showTimePicker(context: context, initialTime: initialTime);
    if (time == null || !mounted) return;
    setState(() {
      values[f.key] = f.kind == FieldKind.time
          ? '${pad(time.hour)}:${pad(time.minute)}:00'
          : DateTime(date!.year, date.month, date.day, time.hour, time.minute)
              .toUtc()
              .toIso8601String();
      controllers[f.key]!.text = f.kind == FieldKind.time
          ? '${pad(time.hour)}:${pad(time.minute)}'
          : dateText(values[f.key]);
    });
  }
}

String roleName(String role) => switch (role) {
      'EMPLOYEE' => 'Nhân viên',
      'STORE_MANAGER' => 'Quản lý cửa hàng',
      'SYSTEM_ADMIN' => 'Quản trị hệ thống',
      _ => statusLabel(role)
    };
