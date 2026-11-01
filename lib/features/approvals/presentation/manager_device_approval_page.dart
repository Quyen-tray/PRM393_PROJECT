import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/repositories/employee_providers.dart';
import '../../home/presentation/widgets/manager_more_menu.dart';

class ManagerDeviceApprovalPage extends ConsumerStatefulWidget {
  const ManagerDeviceApprovalPage({super.key});

  @override
  ConsumerState<ManagerDeviceApprovalPage> createState() => _ManagerDeviceApprovalPageState();
}

class _ManagerDeviceApprovalPageState extends ConsumerState<ManagerDeviceApprovalPage> {
  List<Map<String, dynamic>> _devices = [];
  bool _loading = true;
  final Set<int> _busy = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await ref.read(employeeRepositoryProvider).getPendingAttendanceDevices();
      if (mounted) setState(() => _devices = result);
    } catch (error) {
      if (mounted) setState(() => _error = error is ApiException ? error.message : 'Không tải được danh sách thiết bị.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(Map<String, dynamic> device) async {
    final id = _asInt(device['deviceId']);
    if (id == null) return;
    setState(() { _busy.add(id); _error = null; });
    try {
      await ref.read(employeeRepositoryProvider).approveAttendanceDevice(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã phê duyệt thiết bị.')));
        await _load();
      }
    } catch (error) {
      if (mounted) setState(() => _error = error is ApiException ? error.message : 'Không thể phê duyệt thiết bị.');
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _reject(Map<String, dynamic> device) async {
    final id = _asInt(device['deviceId']);
    if (id == null) return;
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Từ chối thiết bị'),
        content: TextField(controller: controller, autofocus: true, maxLength: 500, maxLines: 3,
          decoration: const InputDecoration(labelText: 'Lý do từ chối', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Hủy')),
          FilledButton(onPressed: () { if (controller.text.trim().isNotEmpty) Navigator.pop(dialogContext, controller.text.trim()); }, child: const Text('Từ chối')),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || reason == null || reason.isEmpty) return;
    setState(() { _busy.add(id); _error = null; });
    try {
      await ref.read(employeeRepositoryProvider).rejectAttendanceDevice(deviceId: id, reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã từ chối thiết bị.')));
        await _load();
      }
    } catch (error) {
      if (mounted) setState(() => _error = error is ApiException ? error.message : 'Không thể từ chối thiết bị.');
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  void _showEmployeeDevices(Map<String, dynamic> device) {
    final employeeId = _asInt(device['employeeId']);
    if (employeeId == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EmployeeDevicesSheet(
        employeeId: employeeId,
        employeeName: (device['employeeName'] ?? 'Mã $employeeId').toString(),
      ),
    );
  }

  int? _asInt(dynamic value) => value is num ? value.toInt() : int.tryParse('$value');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Duyệt thiết bị chấm công'),
        actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _devices.isEmpty
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!, textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton(onPressed: _load, child: const Text('Thử lại')),
                ])))
              : _devices.isEmpty
                  ? const Center(child: Text('Không có thiết bị nào đang chờ phê duyệt.'))
                  : RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: [
                      if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!, style: const TextStyle(color: AppColors.error))),
                      for (final device in _devices) _deviceCard(device),
                    ])),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 3,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Tổng quan'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Nhân viên'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Lịch'),
          NavigationDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: Icon(Icons.fact_check), label: 'Duyệt'),
          NavigationDestination(icon: Icon(Icons.more_horiz), selectedIcon: Icon(Icons.more_horiz), label: 'Khác'),
        ],
        onDestinationSelected: (index) {
          if (index == 0) context.go(RouteNames.home);
          if (index == 1) context.go(RouteNames.managerEmployees);
          if (index == 2) context.go(RouteNames.managerSchedule);
          if (index == 3) context.go(RouteNames.managerApprovals);
          if (index == 4) showManagerMoreMenu(context);
        },
      ),
    );
  }

  Widget _deviceCard(Map<String, dynamic> device) {
    final id = _asInt(device['deviceId']);
    final busy = id != null && _busy.contains(id);
    return Card(
      margin: const EdgeInsets.only(bottom: 12), elevation: 0,
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.phone_android, color: AppColors.primary), const SizedBox(width: 8), Expanded(child: Text((device['deviceLabel'] ?? 'Thiết bị chưa đặt tên').toString(), style: const TextStyle(fontWeight: FontWeight.w700))), const Chip(label: Text('PENDING'))]),
        const SizedBox(height: 8),
        Text('Nhân viên: ${device['employeeName'] ?? 'Không có tên'}'),
        Text('Mã nhân viên: ${device['employeeId'] ?? '—'}'),
        Text('Nền tảng: ${device['platform'] ?? '—'}'),
        Text('Gửi yêu cầu: ${device['requestedAt'] ?? '—'}'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: busy ? null : () => _reject(device), child: const Text('Từ chối'))),
          const SizedBox(width: 10),
          Expanded(child: FilledButton(onPressed: busy ? null : () => _approve(device), child: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Phê duyệt'))),
        ]),
        const SizedBox(height: 4),
        Align(alignment: Alignment.centerLeft, child: TextButton.icon(
          onPressed: _asInt(device['employeeId']) == null ? null : () => _showEmployeeDevices(device),
          icon: const Icon(Icons.devices_outlined, size: 18),
          label: const Text('Xem tất cả thiết bị của nhân viên'),
        )),
      ])),
    );
  }
}

String _deviceStatusLabel(String? status) => switch (status) {
      'PENDING' => 'Chờ duyệt',
      'ACTIVE' => 'Đang dùng',
      'REJECTED' => 'Đã từ chối',
      'REVOKED' => 'Đã thu hồi',
      _ => status ?? 'Không rõ',
    };

/// Mọi thiết bị của một nhân viên (GET /attendance/devices/employees/{id}), kèm nút thu hồi
/// cho thiết bị đang dùng. Thu hồi bắt buộc có lý do, máy chủ sẽ gửi lý do đó cho nhân viên.
class _EmployeeDevicesSheet extends ConsumerStatefulWidget {
  const _EmployeeDevicesSheet({required this.employeeId, required this.employeeName});

  final int employeeId;
  final String employeeName;

  @override
  ConsumerState<_EmployeeDevicesSheet> createState() => _EmployeeDevicesSheetState();
}

class _EmployeeDevicesSheetState extends ConsumerState<_EmployeeDevicesSheet> {
  List<Map<String, dynamic>> _devices = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(employeeRepositoryProvider)
          .getEmployeeAttendanceDevices(widget.employeeId);
      if (mounted) setState(() => _devices = result);
    } catch (error) {
      if (mounted) {
        setState(() => _error =
            error is ApiException ? error.message : 'Không tải được thiết bị của nhân viên.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int? _asInt(dynamic value) => value is num ? value.toInt() : int.tryParse('$value');

  Future<void> _revoke(Map<String, dynamic> device) async {
    final deviceId = _asInt(device['deviceId']);
    if (deviceId == null) return;
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, updateDialog) => AlertDialog(
          title: const Text('Thu hồi thiết bị'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            maxLength: 300,
            onChanged: (_) => updateDialog(() {}),
            decoration: const InputDecoration(
              labelText: 'Lý do thu hồi',
              hintText: 'Nhân viên sẽ nhận được lý do này',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: controller.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Thu hồi'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (!mounted || reason == null || reason.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(employeeRepositoryProvider)
          .revokeAttendanceDevice(deviceId: deviceId, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Đã thu hồi thiết bị.')));
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() => _error =
            error is ApiException ? error.message : 'Không thể thu hồi thiết bị.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _deviceRow(Map<String, dynamic> device) {
    final status = device['status']?.toString();
    final reason = (device['reason'] ?? '').toString();
    final showReason = reason.isNotEmpty && (status == 'REVOKED' || status == 'REJECTED');
    final canRevoke = status == 'ACTIVE' && _asInt(device['deviceId']) != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(
                  (device['deviceLabel'] ?? 'Thiết bị chưa đặt tên').toString(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Chip(label: Text(_deviceStatusLabel(status))),
            ]),
            const SizedBox(height: 4),
            Text(
              'Nền tảng: ${device['platform'] ?? '—'} · Gửi lúc: ${formatDate(device['requestedAt'])}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            if (device['approvedAt'] != null)
              Text(
                'Phê duyệt: ${formatDate(device['approvedAt'])}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            if (showReason)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Lý do: $reason', style: const TextStyle(fontSize: 12)),
              ),
            if (canRevoke) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _revoke(device),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                  child: const Text('Thu hồi'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thiết bị của ${widget.employeeName}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Mới nhất trước. Chỉ thiết bị đang dùng mới có nút thu hồi.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: AppColors.error)),
              ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_devices.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Nhân viên chưa có thiết bị nào.')),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [for (final device in _devices) _deviceRow(device)],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
