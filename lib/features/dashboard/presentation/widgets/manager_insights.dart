import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/presentation/business_labels.dart';
import '../../../../core/presentation/resource_widgets.dart';
import '../../../../shared/resources/data/resource_repository.dart';
import '../../../auth/data/session_controller.dart';

class ManagerInsights extends ConsumerWidget {
  const ManagerInsights({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider).user!;
    Widget chart(String title, Json values, {String? path, String? detail}) =>
        MetricChart(
            title: title,
            values: values,
            detail: detail,
            onOpen: path == null ? null : () => context.push(path));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionTitle('Chấm công hôm nay'),
      ResourceView(const ResourceQuery('/dashboard/manager/overview'),
          builder: (data) {
        final attendance = json(json(data)['attendanceToday']);
        return chart(
            'Tình hình chấm công',
            {
              'Đúng giờ': attendance['checkedInOnTime'] ?? 0,
              'Đi muộn': attendance['late'] ?? 0,
              'Vắng sau khi ca kết thúc': attendance['absent'] ?? 0,
              'Thiếu check-out': attendance['missingCheckOuts'] ?? 0,
              'Cần xác minh': attendance['verificationPending'] ?? 0,
            },
            detail:
                '${attendance['scheduledShifts'] ?? 0} ca được phân hôm nay',
            path:
                user.has('ATTENDANCE_VIEW_ALL') ? '/module/attendance' : null);
      }),
      const SectionTitle('Nhân viên và năng lực'),
      ResourceView(const ResourceQuery('/dashboard/manager/employee-status'),
          builder: (data) {
        final status = json(data);
        final path = user.has('EMPLOYEE_VIEW') ? '/module/employees' : null;
        final profiles = json(status['profileStatus']);
        final training = json(status['trainingStatus']);
        final skills = json(status['skillAssessmentStatus']);
        return Column(children: [
          chart(
              'Tình trạng hồ sơ',
              {
                for (final entry in profiles.entries)
                  statusLabel(entry.key): entry.value,
              },
              detail: 'Hồ sơ của nhân viên đang làm việc',
              path: path),
          chart(
              'Đào tạo bắt buộc',
              {
                'Đã đủ đào tạo': training['COMPLETE'] ?? 0,
                'Còn thiếu hoặc hết hạn': training['MISSING'] ?? 0,
              },
              path: path),
          chart(
              'Đánh giá kỹ năng',
              {
                'Đã có đánh giá': skills['ASSESSED'] ?? 0,
                'Chưa được đánh giá': skills['NOT_ASSESSED'] ?? 0,
              },
              detail: 'Xem hồ sơ từng nhân viên để biết mức kỹ năng.',
              path: path),
        ]);
      }),
      const SectionTitle('Vận hành trong tháng'),
      ResourceView(const ResourceQuery('/dashboard/manager/operations'),
          builder: (data) {
        final operations = json(data);
        return chart(
            'Checklist vận hành',
            {
              for (final entry in json(operations['byStatus']).entries)
                statusLabel(entry.key): entry.value,
            },
            detail: '${operations['totalChecklists'] ?? 0} checklist · '
                '${operations['completionRatePercent'] ?? 0}% đã duyệt',
            path: user.has('CHECKLIST_VIEW') ? '/module/checklists' : null);
      }),
      ResourceView(
          ResourceQuery('/dashboard/manager/attendance', {
            'from': DateTime.now()
                .copyWith(day: 1)
                .toIso8601String()
                .substring(0, 10),
            'to': DateTime.now().toIso8601String().substring(0, 10),
          }), builder: (data) {
        final attendance = json(data);
        return chart(
            'Đi muộn trong tháng',
            {
              'Lượt đúng giờ': attendance['checkedInOnTime'] ?? 0,
              'Lượt đi muộn': attendance['late'] ?? 0,
              'Lượt vắng': attendance['absent'] ?? 0,
            },
            detail: '${attendance['lateMinutesTotal'] ?? 0} phút đi muộn',
            path: '/module/reports-attendance');
      }),
      if (user.has('REWARD_VIEW'))
        ResourceView(
            const ResourceQuery('/dashboard/manager/rewards-penalties'),
            builder: (data) {
          final decisions = json(data);
          return chart(
              'Thưởng và phạt trong tháng',
              {
                'Thưởng đã duyệt': decisions['approvedRewards'] ?? 0,
                'Phạt đã duyệt': decisions['approvedPenalties'] ?? 0,
                'Chờ xét duyệt': decisions['pendingDecisions'] ?? 0,
              },
              detail: 'Tổng thưởng: ${decisions['rewardTotal'] ?? 0} đ · '
                  'Tổng phạt: ${decisions['penaltyTotal'] ?? 0} đ',
              path: '/module/decisions');
        }),
    ]);
  }
}

class MetricChart extends StatelessWidget {
  const MetricChart(
      {required this.title,
      required this.values,
      this.detail,
      this.onOpen,
      super.key});
  final String title;
  final Json values;
  final String? detail;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final entries = values.entries.where((e) => e.value is num).toList();
    final maximum = entries.fold<double>(1,
        (max, e) => (e.value as num) > max ? (e.value as num).toDouble() : max);
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(
                      child: Text(title,
                          style: Theme.of(context).textTheme.titleMedium)),
                  if (onOpen != null)
                    IconButton(
                        onPressed: onOpen,
                        tooltip: 'Xem chi tiết $title',
                        icon: const Icon(Icons.chevron_right)),
                ]),
                if (detail != null)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(detail!)),
                if (entries.isEmpty)
                  const Text('Chưa có dữ liệu trong khoảng thời gian này.'),
                for (final entry in entries)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(children: [
                              Expanded(child: Text(entry.key)),
                              const SizedBox(width: 8),
                              Text('${entry.value}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700))
                            ]),
                            const SizedBox(height: 5),
                            LinearProgressIndicator(
                                value: ((entry.value as num) / maximum)
                                    .clamp(0, 1),
                                minHeight: 7,
                                borderRadius: BorderRadius.circular(4),
                                semanticsLabel: entry.key,
                                semanticsValue: '${entry.value}'),
                          ])),
              ],
            )));
  }
}
