import 'package:flutter/material.dart';
import '../../../shared/resources/data/resource_repository.dart';
import '../../../core/presentation/business_labels.dart';

class ScheduleBoard extends StatelessWidget {
  const ScheduleBoard(this.rows,
      {required this.onOpen, this.descending = false, super.key});
  final List<Json> rows;
  final void Function(Json) onOpen;
  final bool descending;
  @override
  Widget build(BuildContext context) {
    final groups = <String, List<Json>>{};
    for (final row in rows) {
      groups.putIfAbsent('${row['workDate']}', () => []).add(row);
    }
    final days = groups.keys.toList()
      ..sort((a, b) => descending ? b.compareTo(a) : a.compareTo(b));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final day in days) ...[
        Padding(
            padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
            child: Row(children: [
              const Icon(Icons.calendar_today_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(dateText(day),
                      style: Theme.of(context).textTheme.titleMedium)),
              Text('${groups[day]!.length} ca',
                  style: Theme.of(context).textTheme.labelMedium),
            ])),
        for (final row in groups[day]!)
          Card(
              child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: const CircleAvatar(child: Icon(Icons.schedule_outlined)),
            title: Text(
                '${row['employeeName'] ?? json(row['workShift'])['shiftName'] ?? 'Ca làm'}'),
            subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                    '${json(row['workShift'])['shiftName'] ?? ''}\n${dateText(row['plannedStartAt'])} → ${dateText(row['plannedEndAt'])}\n${statusLabel(row['status'])}')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onOpen(row),
          )),
      ],
    ]);
  }
}
