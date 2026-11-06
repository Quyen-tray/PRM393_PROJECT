import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_coffee_shop_flutter/core/presentation/resource_widgets.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';

String shiftAssignmentOptionLabel(Json row) {
  final shiftName = json(row['workShift'])['shiftName'] ?? 'Ca làm';
  String time(dynamic value) {
    final parsed = DateTime.tryParse('$value')?.toLocal();
    if (parsed == null) return '--:--';
    return '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}';
  }

  return '${row['employeeName'] ?? 'Nhân viên'} · $shiftName · '
      '${row['workDate'] ?? 'Chưa có ngày'} · '
      '${time(row['plannedStartAt'])}–${time(row['plannedEndAt'])} · '
      '#${row['assignmentId'] ?? '?'}';
}

class LookupPicker extends ConsumerStatefulWidget {
  const LookupPicker(this.field, {super.key});
  final FieldSpec field;
  @override
  ConsumerState<LookupPicker> createState() => _LookupPickerState();
}

class _LookupPickerState extends ConsumerState<LookupPicker> {
  int page = 0;
  String search = '';
  @override
  Widget build(BuildContext context) {
    final f = widget.field;
    final serverSearch =
        f.source == '/employees' || f.source == '/employees/linkable-users';
    return Scaffold(
      appBar: AppBar(title: Text('Chọn ${f.label.toLowerCase()}')),
      body: PageBody(
        children: [
          TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              labelText: serverSearch
                  ? 'Tìm theo tên hoặc mã'
                  : 'Lọc trong trang hiện tại',
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() {
              search = v;
              if (serverSearch) page = 0;
            }),
          ),
          const SizedBox(height: 14),
          ResourceView(
            ResourceQuery(f.source!, {
              'page': page,
              'size': 50,
              if (serverSearch && search.isNotEmpty) 'q': search,
            }),
            builder: (data) {
              final result = ResourcePage.parse(data);
              final rows = result.items.where(
                (r) =>
                    r['isActive'] != false &&
                    (f.source != '/shift-assignments' ||
                        r['status'] == 'PUBLISHED') &&
                    (serverSearch ||
                        '${f.source == '/shift-assignments' ? shiftAssignmentOptionLabel(r) : r[f.labelKey]} ${r['employeeCode'] ?? ''}'
                            .toLowerCase()
                            .contains(search.toLowerCase())),
              );
              return Column(
                children: [
                  if (rows.isEmpty) const EmptyPanel(),
                  ...rows.map(
                    (r) => Card(
                      child: ListTile(
                        title: Text(
                          f.source == '/shift-assignments'
                              ? shiftAssignmentOptionLabel(r)
                              : '${r[f.labelKey] ?? r[f.valueKey]}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: r['employeeCode'] == null
                            ? null
                            : Text('${r['employeeCode']}'),
                        trailing: const Icon(Icons.add_circle_outline),
                        onTap: () => Navigator.pop(context, r),
                      ),
                    ),
                  ),
                  if (result.totalPages > 1)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'Trang trước',
                          onPressed:
                              page > 0 ? () => setState(() => page--) : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text('${page + 1}/${result.totalPages}'),
                        IconButton(
                          tooltip: 'Trang sau',
                          onPressed: page + 1 < result.totalPages
                              ? () => setState(() => page++)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
