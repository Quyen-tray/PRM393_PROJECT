import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/employee_bottom_navigation.dart';
import '../../../data/repositories/employee_providers.dart';

class EmployeeNotificationsPage extends ConsumerStatefulWidget {
  const EmployeeNotificationsPage({super.key});
  @override
  ConsumerState<EmployeeNotificationsPage> createState() => _EmployeeNotificationsPageState();
}

class _EmployeeNotificationsPageState extends ConsumerState<EmployeeNotificationsPage> {
  bool _loading = true;
  bool _markingAll = false;
  String? _error;
  int _unreadCount = 0;
  int _filter = 0;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final repo = ref.read(employeeRepositoryProvider);
      final results = await Future.wait([repo.getMyNotifications(), repo.getUnreadNotificationCount()]);
      if (!mounted) return;
      setState(() { _items = results[0] as List<Map<String, dynamic>>; _unreadCount = results[1] as int; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<Map<String, dynamic>> get _visibleItems => _items.where((n) {
    if (_filter == 0) return true;
    final type = '${n['notificationType'] ?? ''}'.toUpperCase();
    if (_filter == 1) return type.contains('REMIND') || type.contains('DUE') || type.contains('EXPIR');
    if (_filter == 2) return type.contains('APPROV') || type.contains('REJECT') || type.contains('REQUEST');
    return type.contains('SYSTEM') || type.contains('ANNOUNCE');
  }).toList();

  Future<void> _markRead(Map<String, dynamic> item) async {
    if (item['readAt'] != null) return;
    final id = (item['notificationId'] as num?)?.toInt();
    if (id == null) return;
    try {
      await ref.read(employeeRepositoryProvider).markNotificationRead(id);
      if (!mounted) return;
      setState(() { item['readAt'] = DateTime.now().toIso8601String(); if (_unreadCount > 0) _unreadCount--; });
    } catch (e) { _message(e.toString()); }
  }

  Future<void> _markAllRead() async {
    if (_unreadCount == 0 || _markingAll) return;
    setState(() => _markingAll = true);
    try {
      await ref.read(employeeRepositoryProvider).markAllNotificationsRead();
      if (!mounted) return;
      setState(() { for (final item in _items) { item['readAt'] ??= DateTime.now().toIso8601String(); } _unreadCount = 0; });
      _message('Đã đánh dấu tất cả thông báo đã đọc.');
    } catch (e) { _message(e.toString()); }
    finally { if (mounted) setState(() => _markingAll = false); }
  }

  void _message(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final visible = _visibleItems;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Thông báo'),
        leading: IconButton(onPressed: () => context.go(RouteNames.employeeHome), icon: const Icon(Icons.arrow_back)),
        actions: [IconButton(tooltip: 'Đánh dấu tất cả đã đọc', onPressed: _unreadCount == 0 || _markingAll ? null : _markAllRead, icon: _markingAll ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.done_all))],
      ),
      body: SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 680), child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 10), child: Row(children: [
          const Expanded(child: Text('Cập nhật dành cho bạn', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          if (_unreadCount > 0) Chip(label: Text('$_unreadCount chưa đọc')),
        ])),
        SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
          _filterChip('Tất cả', 0), _filterChip('Nhắc nhở', 1), _filterChip('Duyệt', 2), _filterChip('Hệ thống', 3),
        ])),
        const SizedBox(height: 8),
        Expanded(child: _loading ? const Center(child: CircularProgressIndicator())
          : _error != null ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!, textAlign: TextAlign.center), const SizedBox(height: 12), OutlinedButton(onPressed: _load, child: const Text('Thử lại'))])))
          : RefreshIndicator(onRefresh: _load, child: visible.isEmpty
            ? ListView(children: const [SizedBox(height: 150), Center(child: Text('Bạn chưa có thông báo nào.'))])
            : ListView.separated(padding: const EdgeInsets.fromLTRB(16, 4, 16, 20), itemCount: visible.length, separatorBuilder: (_, __) => const SizedBox(height: 8), itemBuilder: (context, index) {
                final item = visible[index];
                final unread = item['readAt'] == null;
                return Card(color: unread ? AppColors.surface : null, child: InkWell(borderRadius: BorderRadius.circular(12), onTap: () => _markRead(item), child: Padding(padding: const EdgeInsets.all(14), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  CircleAvatar(backgroundColor: unread ? AppColors.primary.withOpacity(.12) : Colors.black12, child: Icon(_iconFor('${item['notificationType'] ?? ''}'), color: unread ? AppColors.primary : AppColors.textSecondary)),
                  const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Expanded(child: Text('${item['title'] ?? 'Thông báo'}', style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w600))), if (unread) Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle))]),
                    const SizedBox(height: 5), Text('${item['message'] ?? ''}'),
                    if (item['createdAt'] != null) Padding(padding: const EdgeInsets.only(top: 7), child: Text(formatDate(item['createdAt']), style: Theme.of(context).textTheme.bodySmall)),
                  ])),
                ]))));
              })),
        ),
      ])))),
      bottomNavigationBar: const EmployeeBottomNavigation(selectedIndex: 0),
    );
  }

  Widget _filterChip(String label, int value) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(label), selected: _filter == value, onSelected: (_) => setState(() => _filter = value)));
  IconData _iconFor(String type) { final t = type.toUpperCase(); if (t.contains('APPROV') || t.contains('REJECT')) return Icons.fact_check_outlined; if (t.contains('REMIND') || t.contains('DUE')) return Icons.alarm_outlined; if (t.contains('SYSTEM')) return Icons.settings_outlined; return Icons.notifications_outlined; }
}
