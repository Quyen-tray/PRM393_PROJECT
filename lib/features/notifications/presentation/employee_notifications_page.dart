import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../data/mock/demo_data.dart';

class EmployeeNotificationsPage extends StatefulWidget {
  const EmployeeNotificationsPage({super.key});

  @override
  State<EmployeeNotificationsPage> createState() =>
      _EmployeeNotificationsPageState();
}

class _EmployeeNotificationsPageState extends State<EmployeeNotificationsPage> {
  _NotificationFilter _filter = _NotificationFilter.all;
  final Set<int> _readNotifications = {};

  int get _unreadCount => DemoData.employeeNotifications
      .asMap()
      .entries
      .where((entry) =>
          entry.value.isUnread && !_readNotifications.contains(entry.key))
      .length;

  List<int> get _visibleNotificationIndexes =>
      List<int>.generate(DemoData.employeeNotifications.length, (index) => index)
          .where((index) {
        final notification = DemoData.employeeNotifications[index];
        return switch (_filter) {
          _NotificationFilter.all => true,
          _NotificationFilter.reminders =>
            notification.category == DemoNotificationCategory.reminder,
          _NotificationFilter.approvals =>
            notification.category == DemoNotificationCategory.approval,
          _NotificationFilter.system =>
            notification.category == DemoNotificationCategory.system,
        };
      }).toList();

  bool _isUnread(int index, DemoEmployeeNotification notification) =>
      notification.isUnread && !_readNotifications.contains(index);

  void _markRead(int index) {
    if (_readNotifications.contains(index) ||
        !DemoData.employeeNotifications[index].isUnread) {
      return;
    }
    setState(() => _readNotifications.add(index));
  }

  void _markAllRead() {
    setState(() {
      _readNotifications.addAll(
        DemoData.employeeNotifications.asMap().entries
            .where((entry) => entry.value.isUnread)
            .map((entry) => entry.key),
      );
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Đã đánh dấu tất cả thông báo đã đọc.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final visibleIndexes = _visibleNotificationIndexes;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Thông báo'),
        leading: IconButton(
          tooltip: 'Quay lại trang chủ',
          onPressed: () => context.go(RouteNames.employeeHome),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            tooltip: 'Đánh dấu tất cả đã đọc',
            onPressed: _unreadCount == 0 ? null : _markAllRead,
            icon: const Icon(Icons.done_all),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Cập nhật dành cho bạn',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (_unreadCount > 0)
                        _UnreadCountBadge(count: _unreadCount),
                    ],
                  ),
                ),
                _NotificationFilterBar(
                  selected: _filter,
                  onChanged: (filter) => setState(() => _filter = filter),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: visibleIndexes.isEmpty
                      ? const _EmptyNotifications()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                          itemCount: visibleIndexes.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 9),
                          itemBuilder: (context, listIndex) {
                            final notificationIndex =
                                visibleIndexes[listIndex];
                            final notification = DemoData
                                .employeeNotifications[notificationIndex];
                            return _NotificationCard(
                              notification: notification,
                              isUnread:
                                  _isUnread(notificationIndex, notification),
                              onTap: () => _markRead(notificationIndex),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Lịch',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'Checklist',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Cá nhân',
          ),
        ],
        onDestinationSelected: (index) {
          if (index == 0) {
            context.go(RouteNames.employeeHome);
          } else if (index == 1) {
            context.go(RouteNames.employeeSchedule);
          } else if (index == 2) {
            context.go(RouteNames.employeeChecklist);
          } else if (index == 3) {
            context.go(RouteNames.employeeProfile);
          }
        },
      ),
    );
  }
}

enum _NotificationFilter { all, reminders, approvals, system }

class _NotificationFilterBar extends StatelessWidget {
  const _NotificationFilterBar({
    required this.selected,
    required this.onChanged,
  });

  final _NotificationFilter selected;
  final ValueChanged<_NotificationFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    const filters = [
      (value: _NotificationFilter.all, label: 'Tất cả'),
      (value: _NotificationFilter.reminders, label: 'Nhắc nhở'),
      (value: _NotificationFilter.approvals, label: 'Duyệt'),
      (value: _NotificationFilter.system, label: 'Hệ thống'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final filter in filters) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(filter.label),
                selected: selected == filter.value,
                onSelected: (_) => onChanged(filter.value),
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.surface,
                side: BorderSide(
                  color: selected == filter.value
                      ? AppColors.primary
                      : const Color(0xFFE5E1DA),
                ),
                labelStyle: TextStyle(
                  color: selected == filter.value
                      ? Colors.white
                      : AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UnreadCountBadge extends StatelessWidget {
  const _UnreadCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBDD),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count chưa đọc',
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.isUnread,
    required this.onTap,
  });

  final DemoEmployeeNotification notification;
  final bool isUnread;
  final VoidCallback onTap;

  IconData get _icon {
    if (notification.title.toLowerCase().contains('checklist')) {
      return Icons.checklist_outlined;
    }
    if (notification.title.toLowerCase().contains('khóa học')) {
      return Icons.school_outlined;
    }
    return switch (notification.category) {
      DemoNotificationCategory.reminder => Icons.calendar_month_outlined,
      DemoNotificationCategory.approval => Icons.swap_horiz,
      DemoNotificationCategory.system => Icons.campaign_outlined,
    };
  }

  Color get _iconColor => switch (notification.category) {
        DemoNotificationCategory.reminder => const Color(0xFF3486D8),
        DemoNotificationCategory.approval => const Color(0xFF27965C),
        DemoNotificationCategory.system => const Color(0xFFDA594C),
      };

  Color get _iconBackground => switch (notification.category) {
        DemoNotificationCategory.reminder => const Color(0xFFE8F2FF),
        DemoNotificationCategory.approval => const Color(0xFFE8F6EC),
        DemoNotificationCategory.system => const Color(0xFFFFECEA),
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isUnread
                  ? const Color(0xFFE5C2AE)
                  : const Color(0xFFEDE8E3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _iconBackground,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(_icon, color: _iconColor, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight:
                                  isUnread ? FontWeight.w800 : FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF3486D8),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.timeLabel,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none,
              size: 42,
              color: AppColors.textSecondary.withValues(alpha: 0.65),
            ),
            const SizedBox(height: 10),
            const Text(
              'Không có thông báo trong mục này.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
