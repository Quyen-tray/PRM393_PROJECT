import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../data/mock/demo_data.dart';
import 'widgets/admin_bottom_navigation.dart';
import 'widgets/admin_more_menu.dart';

enum _SettingsSection { store, attendance, gps, violations, notifications }

class AdminSystemSettingsPage extends StatefulWidget {
  const AdminSystemSettingsPage({super.key});

  @override
  State<AdminSystemSettingsPage> createState() =>
      _AdminSystemSettingsPageState();
}

class _AdminSystemSettingsPageState extends State<AdminSystemSettingsPage> {
  late DemoAdminSystemSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = DemoData.adminSystemSettings;
  }

  String _summaryFor(_SettingsSection section) {
    return switch (section) {
      _SettingsSection.store =>
        '${_settings.storeName} · ${_settings.branchName}',
      _SettingsSection.attendance =>
        'Check-in sớm ${_settings.checkInEarlyMinutes} phút · '
            'Ân hạn ${_settings.graceMinutes} phút · '
            'Lưu ảnh ${_settings.photoRetentionMonths} tháng',
      _SettingsSection.gps =>
        '${_settings.latitude.toStringAsFixed(4)}, '
            '${_settings.longitude.toStringAsFixed(4)} · '
            'Bán kính ${_settings.radiusMeters} m',
      _SettingsSection.violations =>
        'Tối đa ${_settings.monthlyGraceLimit} lần ân hạn mỗi tháng',
      _SettingsSection.notifications =>
        'Mỗi ${_settings.reminderIntervalMinutes} phút · '
            'tối đa ${_settings.maxLateReminders} lần',
    };
  }

  Future<void> _showEditor(_SettingsSection section) async {
    final fields = _fieldsFor(section);
    final formKey = GlobalKey<FormState>();
    final controllers = <String, TextEditingController>{
      for (final field in fields)
        field.keyName: TextEditingController(text: field.initialValue),
    };

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_titleFor(section)),
        scrollable: true,
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final field in fields) ...[
                TextFormField(
                  controller: controllers[field.keyName],
                  keyboardType: field.isInteger
                      ? TextInputType.number
                      : field.isDecimal
                          ? const TextInputType.numberWithOptions(decimal: true)
                          : TextInputType.text,
                  decoration: InputDecoration(
                    labelText: field.label,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) => _validateField(field, value),
                ),
                if (field != fields.last) const SizedBox(height: 12),
              ],
              if (_descriptionFor(section).isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  _descriptionFor(section),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;

              Navigator.pop(
                dialogContext,
                {
                  for (final field in fields)
                    field.keyName: controllers[field.keyName]!.text.trim(),
                },
              );
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    for (final controller in controllers.values) {
      controller.dispose();
    }

    if (!mounted || result == null) return;

    int readInt(String key, int fallback) =>
        int.tryParse(result[key] ?? '') ?? fallback;
    double readDouble(String key, double fallback) =>
        double.tryParse((result[key] ?? '').replaceAll(',', '.')) ?? fallback;

    setState(() {
      _settings = _settings.copyWith(
        storeName: result['storeName'],
        branchName: result['branchName'],
        latitude: result.containsKey('latitude')
            ? readDouble('latitude', _settings.latitude)
            : null,
        longitude: result.containsKey('longitude')
            ? readDouble('longitude', _settings.longitude)
            : null,
        radiusMeters: result.containsKey('radiusMeters')
            ? readInt('radiusMeters', _settings.radiusMeters)
            : null,
        checkInEarlyMinutes: result.containsKey('checkInEarlyMinutes')
            ? readInt('checkInEarlyMinutes', _settings.checkInEarlyMinutes)
            : null,
        graceMinutes: result.containsKey('graceMinutes')
            ? readInt('graceMinutes', _settings.graceMinutes)
            : null,
        monthlyGraceLimit: result.containsKey('monthlyGraceLimit')
            ? readInt('monthlyGraceLimit', _settings.monthlyGraceLimit)
            : null,
        photoRetentionMonths: result.containsKey('photoRetentionMonths')
            ? readInt('photoRetentionMonths', _settings.photoRetentionMonths)
            : null,
        reminderIntervalMinutes: result.containsKey('reminderIntervalMinutes')
            ? readInt('reminderIntervalMinutes', _settings.reminderIntervalMinutes)
            : null,
        maxLateReminders: result.containsKey('maxLateReminders')
            ? readInt('maxLateReminders', _settings.maxLateReminders)
            : null,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã lưu cấu hình demo.')),
    );
  }

  List<_AdminSettingField> _fieldsFor(_SettingsSection section) {
    return switch (section) {
      _SettingsSection.store => [
          _AdminSettingField(
            keyName: 'storeName',
            label: 'Tên cửa hàng',
            initialValue: _settings.storeName,
          ),
          _AdminSettingField(
            keyName: 'branchName',
            label: 'Tên chi nhánh',
            initialValue: _settings.branchName,
          ),
        ],
      _SettingsSection.attendance => [
          _AdminSettingField(
            keyName: 'checkInEarlyMinutes',
            label: 'Cho check-in sớm (phút)',
            initialValue: '${_settings.checkInEarlyMinutes}',
            isInteger: true,
            minimum: 15,
            maximum: 30,
          ),
          _AdminSettingField(
            keyName: 'graceMinutes',
            label: 'Thời gian ân hạn (phút)',
            initialValue: '${_settings.graceMinutes}',
            isInteger: true,
            minimum: 3,
            maximum: 5,
          ),
          _AdminSettingField(
            keyName: 'photoRetentionMonths',
            label: 'Thời hạn lưu ảnh (tháng)',
            initialValue: '${_settings.photoRetentionMonths}',
            isInteger: true,
            minimum: 1,
            maximum: 120,
          ),
        ],
      _SettingsSection.gps => [
          _AdminSettingField(
            keyName: 'latitude',
            label: 'Vĩ độ cửa hàng',
            initialValue: '${_settings.latitude}',
            isDecimal: true,
            minimum: -90,
            maximum: 90,
          ),
          _AdminSettingField(
            keyName: 'longitude',
            label: 'Kinh độ cửa hàng',
            initialValue: '${_settings.longitude}',
            isDecimal: true,
            minimum: -180,
            maximum: 180,
          ),
          _AdminSettingField(
            keyName: 'radiusMeters',
            label: 'Bán kính GPS (m)',
            initialValue: '${_settings.radiusMeters}',
            isInteger: true,
            minimum: 15,
            maximum: 50,
          ),
        ],
      _SettingsSection.violations => [
          _AdminSettingField(
            keyName: 'monthlyGraceLimit',
            label: 'Số lần ân hạn tối đa mỗi tháng',
            initialValue: '${_settings.monthlyGraceLimit}',
            isInteger: true,
            minimum: 0,
            maximum: 31,
          ),
        ],
      _SettingsSection.notifications => [
          _AdminSettingField(
            keyName: 'reminderIntervalMinutes',
            label: 'Khoảng cách giữa các lần nhắc (phút)',
            initialValue: '${_settings.reminderIntervalMinutes}',
            isInteger: true,
            minimum: 5,
            maximum: 60,
          ),
          _AdminSettingField(
            keyName: 'maxLateReminders',
            label: 'Số lần nhắc tối đa',
            initialValue: '${_settings.maxLateReminders}',
            isInteger: true,
            minimum: 1,
            maximum: 3,
          ),
        ],
    };
  }

  String? _validateField(_AdminSettingField field, String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Trường này không được để trống.';
    }

    if (!field.isInteger && !field.isDecimal) return null;

    final parsed = field.isInteger
        ? int.tryParse(value.trim())?.toDouble()
        : double.tryParse(value.trim().replaceAll(',', '.'));

    if (parsed == null) return 'Vui lòng nhập một số hợp lệ.';
    if (field.minimum != null && parsed < field.minimum!) {
      return 'Giá trị tối thiểu là ${field.minimum}.';
    }
    if (field.maximum != null && parsed > field.maximum!) {
      return 'Giá trị tối đa là ${field.maximum}.';
    }
    return null;
  }

  String _titleFor(_SettingsSection section) {
    return switch (section) {
      _SettingsSection.store => 'Thông tin cửa hàng',
      _SettingsSection.attendance => 'Chính sách chấm công',
      _SettingsSection.gps => 'Cài đặt GPS',
      _SettingsSection.violations => 'Quy định vi phạm',
      _SettingsSection.notifications => 'Cấu hình thông báo',
    };
  }

  String _descriptionFor(_SettingsSection section) {
    return switch (section) {
      _SettingsSection.violations =>
        'Hệ thống không tự động phạt tiền hoặc trừ lương chỉ từ sự kiện chưa xác minh.',
      _SettingsSection.notifications =>
        'Giá trị ban đầu theo SRS: nhắc mỗi 5 phút, tối đa 3 lần.',
      _ => '',
    };
  }

  Future<void> _showBackupDialog() async {
    final shouldConfirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sao lưu dữ liệu'),
        content: const Text(
          'Đây là thao tác mô phỏng. Ứng dụng chưa tạo hoặc tải file sao lưu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Đóng'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (!mounted || shouldConfirm != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã ghi nhận thao tác sao lưu demo.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsRows = <(_SettingsSection, String, IconData)>[
      (_SettingsSection.store, 'Thông tin cửa hàng', Icons.store_outlined),
      (
        _SettingsSection.attendance,
        'Chính sách chấm công',
        Icons.access_time_outlined,
      ),
      (_SettingsSection.gps, 'Cài đặt GPS', Icons.location_on_outlined),
      (
        _SettingsSection.violations,
        'Quy định vi phạm',
        Icons.warning_amber_outlined,
      ),
      (
        _SettingsSection.notifications,
        'Cấu hình thông báo',
        Icons.notifications_outlined,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Cấu hình hệ thống'),
        leading: IconButton(
          tooltip: 'Quay lại Dashboard Admin',
          onPressed: () => context.go(RouteNames.adminHome),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        children: [
          for (final (section, title, icon) in settingsRows) ...[
            _SettingsCard(
              title: title,
              subtitle: _summaryFor(section),
              icon: icon,
              onTap: () => _showEditor(section),
            ),
            const SizedBox(height: 9),
          ],
          _SettingsCard(
            title: 'Sao lưu dữ liệu',
            subtitle: 'Thao tác demo; không tạo file thật',
            icon: Icons.backup_outlined,
            onTap: _showBackupDialog,
          ),
        ],
      ),
      bottomNavigationBar: AdminBottomNavigation(
        selectedIndex: 4,
        onDestinationSelected: (index) {
          if (index == 0) {
            context.go(RouteNames.adminHome);
          } else if (index == 1) {
            context.go(RouteNames.adminAccounts);
          } else if (index == 2) {
            context.go(RouteNames.adminPositions);
          } else if (index == 3) {
            context.go(RouteNames.adminTraining);
          } else {
            showAdminMoreMenu(context);
          }
        },
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDE8E3)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 5,
        ),
        leading: Icon(icon, color: AppColors.primary),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _AdminSettingField {
  const _AdminSettingField({
    required this.keyName,
    required this.label,
    required this.initialValue,
    this.isInteger = false,
    this.isDecimal = false,
    this.minimum,
    this.maximum,
  });

  final String keyName;
  final String label;
  final String initialValue;
  final bool isInteger;
  final bool isDecimal;
  final double? minimum;
  final double? maximum;
}
