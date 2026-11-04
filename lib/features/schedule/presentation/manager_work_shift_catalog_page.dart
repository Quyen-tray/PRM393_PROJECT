import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/repositories/employee_providers.dart';

class ManagerWorkShiftCatalogPage extends ConsumerStatefulWidget {
  const ManagerWorkShiftCatalogPage({super.key});

  @override
  ConsumerState<ManagerWorkShiftCatalogPage> createState() =>
      _ManagerWorkShiftCatalogPageState();
}

class _ManagerWorkShiftCatalogPageState
    extends ConsumerState<ManagerWorkShiftCatalogPage> {
  List<Map<String, dynamic>> _shifts = [];
  bool _loading = true;
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
      final data = await ref.read(employeeRepositoryProvider).getWorkShifts();
      if (mounted) setState(() => _shifts = data);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Không tải được danh mục ca.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit({Map<String, dynamic>? shift}) async {
    final code = TextEditingController(text: '${shift?['shiftCode'] ?? ''}');
    final name = TextEditingController(text: '${shift?['shiftName'] ?? ''}');
    final start = TextEditingController(text: _time(shift?['startTime']));
    final end = TextEditingController(text: _time(shift?['endTime']));
    final breakMinutes = TextEditingController(
      text: '${shift?['breakMinutes'] ?? 0}',
    );
    final early = TextEditingController(
      text: '${shift?['earlyCheckInMinutes'] ?? 0}',
    );
    final grace = TextEditingController(text: '${shift?['graceMinutes'] ?? 0}');
    final formKey = GlobalKey<FormState>();
    var active = shift?['isActive'] != false;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(shift == null ? 'Tạo ca làm' : 'Sửa ca làm'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _field(code, 'Mã ca', required: true),
                    _field(name, 'Tên ca', required: true),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            start,
                            'Bắt đầu (HH:mm)',
                            required: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _field(
                            end,
                            'Kết thúc (HH:mm)',
                            required: true,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            breakMinutes,
                            'Nghỉ (phút)',
                            numeric: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _field(
                            early,
                            'Check-in sớm (phút)',
                            numeric: true,
                          ),
                        ),
                      ],
                    ),
                    _field(grace, 'Ân hạn (phút)', numeric: true),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Đang hoạt động'),
                      value: active,
                      onChanged: (value) =>
                          setDialogState(() => active = value),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !mounted) return;
    final payload = <String, dynamic>{
      'shiftCode': code.text.trim(),
      'shiftName': name.text.trim(),
      'startTime': _apiTime(start.text.trim()),
      'endTime': _apiTime(end.text.trim()),
      'breakMinutes': int.parse(breakMinutes.text.trim()),
      'earlyCheckInMinutes': int.parse(early.text.trim()),
      'graceMinutes': int.parse(grace.text.trim()),
      'isActive': active,
    };
    try {
      final repo = ref.read(employeeRepositoryProvider);
      final id = (shift?['shiftId'] ?? shift?['workShiftId']) as num?;
      if (id == null) {
        await repo.createWorkShift(payload);
      } else {
        await repo.updateWorkShift(id.toInt(), payload);
      }
      await _load();
      _message('Đã lưu ca làm.');
    } catch (error) {
      _message(
        error is ApiException ? error.message : 'Không lưu được ca làm.',
      );
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool numeric = false,
  }) => TextFormField(
    controller: controller,
    keyboardType: numeric ? TextInputType.number : TextInputType.text,
    decoration: InputDecoration(labelText: label),
    validator: (value) {
      final text = value?.trim() ?? '';
      if (required && text.isEmpty) return 'Trường này bắt buộc.';
      if (numeric && (int.tryParse(text) == null || int.parse(text) < 0)) {
        return 'Nhập số nguyên không âm.';
      }
      if ((label.startsWith('Bắt đầu') || label.startsWith('Kết thúc')) &&
          !RegExp(r'^\d{2}:\d{2}$').hasMatch(text)) {
        return 'Dùng định dạng HH:mm.';
      }
      return null;
    },
  );

  String _time(Object? value) {
    final raw = value?.toString() ?? '';
    return raw.length >= 5 ? raw.substring(0, 5) : '';
  }

  String _apiTime(String value) => value.length == 5 ? '$value:00' : value;

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('Danh mục ca làm'),
      leading: IconButton(
        onPressed: () => context.go(RouteNames.managerSchedule),
        icon: const Icon(Icons.arrow_back),
      ),
      actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!),
                const SizedBox(height: 12),
                FilledButton(onPressed: _load, child: const Text('Thử lại')),
              ],
            ),
          )
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Quản lý mẫu ca trước khi xếp lịch. Ca đã được dùng nên nên chuyển sang ngừng hoạt động thay vì xóa.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                if (_shifts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(30),
                    child: Center(child: Text('Chưa có ca làm.')),
                  ),
                for (final shift in _shifts)
                  Card(
                    color: AppColors.surface,
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.schedule_outlined),
                      ),
                      title: Text(
                        '${shift['shiftName'] ?? 'Ca làm'}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${shift['shiftCode'] ?? ''} · ${_time(shift['startTime'])}–${_time(shift['endTime'])} · ${shift['isActive'] == false ? 'Ngừng hoạt động' : 'Đang hoạt động'}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Sửa ca',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _edit(shift: shift),
                      ),
                    ),
                  ),
              ],
            ),
          ),
    floatingActionButton: FloatingActionButton(
      onPressed: () => _edit(),
      child: const Icon(Icons.add),
    ),
  );
}
