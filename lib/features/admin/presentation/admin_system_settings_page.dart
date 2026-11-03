import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/presentation/sign_out_flow.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/repositories/employee_providers.dart';
import 'widgets/admin_bottom_navigation.dart';
import 'widgets/admin_more_menu.dart';

enum _FieldKind { text, integer, decimal }

/// Một trường cấu hình. [inStore] nghĩa là trường nằm trong object store (name, address, latitude, longitude).
class _Field {
  const _Field(this.key, this.label, this.kind, {this.inStore = false});

  final String key;
  final String label;
  final _FieldKind kind;
  final bool inStore;
}

/// Một nhóm cấu hình trên màn hình, có thể mở ra để sửa.
class _Section {
  const _Section({
    required this.title,
    required this.icon,
    required this.fields,
    required this.summary,
    this.note,
  });

  final String title;
  final IconData icon;
  final List<_Field> fields;
  final String Function(Map<String, dynamic> settings) summary;
  final String? note;
}

String _text(Object? value, [String fallback = '—']) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

int _intOf(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

final _sections = <_Section>[
  _Section(
    title: 'Thông tin cửa hàng',
    icon: Icons.store_outlined,
    fields: const [
      _Field('name', 'Tên cửa hàng', _FieldKind.text, inStore: true),
      _Field('address', 'Địa chỉ', _FieldKind.text, inStore: true),
    ],
    summary: (s) {
      final store = _mapOf(s['store']);
      return '${_text(store['name'])} · ${_text(store['address'])}';
    },
  ),
  _Section(
    title: 'GPS và bán kính chấm công',
    icon: Icons.location_on_outlined,
    fields: const [
      _Field('latitude', 'Vĩ độ cửa hàng', _FieldKind.decimal, inStore: true),
      _Field(
        'longitude',
        'Kinh độ cửa hàng',
        _FieldKind.decimal,
        inStore: true,
      ),
      _Field(
        'attendanceRadiusMeters',
        'Bán kính chấm công (m)',
        _FieldKind.integer,
      ),
      _Field(
        'gpsMaxAccuracyMeters',
        'Sai số GPS tối đa (m)',
        _FieldKind.integer,
      ),
    ],
    summary: (s) =>
        'Bán kính ${_text(s['attendanceRadiusMeters'])} m · sai số tối đa ${_text(s['gpsMaxAccuracyMeters'])} m',
    note:
        'Máy chủ kiểm tra giới hạn của từng trường. Thông báo lỗi sẽ hiện nếu giá trị không hợp lệ.',
  ),
  _Section(
    title: 'Chính sách chấm công',
    icon: Icons.access_time_outlined,
    fields: const [
      _Field(
        'checkInEarlyMinutes',
        'Cho check-in sớm (phút)',
        _FieldKind.integer,
      ),
      _Field('graceMinutes', 'Thời gian ân hạn (phút)', _FieldKind.integer),
      _Field(
        'monthlyGraceLimit',
        'Số lần ân hạn tối đa mỗi tháng',
        _FieldKind.integer,
      ),
      _Field(
        'photoRetentionMonths',
        'Thời hạn lưu ảnh chấm công (tháng)',
        _FieldKind.integer,
      ),
    ],
    summary: (s) =>
        'Check-in sớm ${_text(s['checkInEarlyMinutes'])} phút · ân hạn ${_text(s['graceMinutes'])} phút · '
        'lưu ảnh ${_text(s['photoRetentionMonths'])} tháng',
    note:
        'Số lần ân hạn tối đa mỗi tháng áp dụng cho quy định đi muộn. Hệ thống không tự phạt tiền hay trừ lương từ sự kiện chưa xác minh.',
  ),
  _Section(
    title: 'Thông báo nhắc việc',
    icon: Icons.notifications_outlined,
    fields: const [
      _Field(
        'lateReminderIntervalMinutes',
        'Khoảng cách giữa các lần nhắc muộn (phút)',
        _FieldKind.integer,
      ),
      _Field('maxLateReminders', 'Số lần nhắc muộn tối đa', _FieldKind.integer),
      _Field(
        'shiftReminderMinutes',
        'Nhắc trước giờ ca (phút)',
        _FieldKind.integer,
      ),
      _Field(
        'checklistDueSoonMinutes',
        'Nhắc checklist sắp đến hạn (phút)',
        _FieldKind.integer,
      ),
    ],
    summary: (s) =>
        'Nhắc muộn mỗi ${_text(s['lateReminderIntervalMinutes'])} phút · tối đa ${_text(s['maxLateReminders'])} lần',
  ),
];

Map<String, dynamic> _mapOf(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

/// Cấu hình cửa hàng (PATCH /admin/store-settings) và quy tắc nhắc việc (/admin/reminder-rules).
class AdminSystemSettingsPage extends ConsumerStatefulWidget {
  const AdminSystemSettingsPage({super.key});

  @override
  ConsumerState<AdminSystemSettingsPage> createState() =>
      _AdminSystemSettingsPageState();
}

class _AdminSystemSettingsPageState
    extends ConsumerState<AdminSystemSettingsPage> {
  Map<String, dynamic> _settings = {};
  List<Map<String, dynamic>> _rules = [];
  bool _loading = true;
  String? _error;

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
        repo.getStoreSettings(),
        repo.getReminderRules(),
      ]);
      if (!mounted) return;
      setState(() {
        _settings = results[0] as Map<String, dynamic>;
        _rules = results[1] as List<Map<String, dynamic>>;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Không tải được cấu hình hệ thống.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _valueOf(_Field field) {
    final source = field.inStore ? _mapOf(_settings['store']) : _settings;
    return source[field.key]?.toString() ?? '';
  }

  Future<void> _editSection(_Section section) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _SectionDialog(section: section, valueOf: _valueOf),
    );
    if (result == null || !mounted) return;

    // Chỉ gửi các trường thực sự thay đổi.
    final changes = <String, dynamic>{};
    for (final field in section.fields) {
      final entered = result[field.key];
      if (entered == null || entered == _valueOf(field)) continue;
      changes[field.key] = switch (field.kind) {
        _FieldKind.text => entered,
        _FieldKind.integer => int.parse(entered),
        _FieldKind.decimal => double.parse(entered.replaceAll(',', '.')),
      };
    }
    if (changes.isEmpty) return;

    try {
      final saved = await ref
          .read(employeeRepositoryProvider)
          .updateStoreSettings(changes);
      if (!mounted) return;
      setState(() => _settings = saved);
      _showMessage('Đã lưu cấu hình.');
    } catch (error) {
      _showMessage(
        error is ApiException ? error.message : 'Không lưu được cấu hình.',
      );
    }
  }

  Future<void> _editRule(Map<String, dynamic> rule) async {
    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (_) => _RuleDialog(rule: rule),
    );
    if (result == null || !mounted) return;
    try {
      final saved = await ref
          .read(employeeRepositoryProvider)
          .updateReminderRule(
            _text(rule['ruleId'], ''),
            leadMinutes: result['leadMinutes']!,
            intervalMinutes: result['intervalMinutes']!,
            maxAttempts: result['maxAttempts']!,
          );
      if (!mounted) return;
      setState(() {
        final index = _rules.indexWhere(
          (item) => item['ruleId'] == rule['ruleId'],
        );
        if (index != -1) _rules[index] = saved;
      });
      _showMessage('Đã lưu quy tắc nhắc việc.');
    } catch (error) {
      _showMessage(
        error is ApiException
            ? error.message
            : 'Không lưu được quy tắc nhắc việc.',
      );
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Cấu hình hệ thống'),
        leading: IconButton(
          tooltip: 'Quay lại Dashboard Admin',
          onPressed: () => context.go(RouteNames.adminHome),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
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
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                children: [
                  for (final section in _sections) ...[
                    _SettingsCard(
                      title: section.title,
                      subtitle: section.summary(_settings),
                      icon: section.icon,
                      onTap: () => _editSection(section),
                    ),
                    const SizedBox(height: 9),
                  ],
                  _SettingsCard(
                    title: 'Quy tắc nhắc việc',
                    subtitle: '${_rules.length} quy tắc',
                    icon: Icons.alarm_outlined,
                    onTap: () {},
                    expandable: true,
                  ),
                  for (final rule in _rules)
                    Padding(
                      padding: const EdgeInsets.only(top: 9),
                      child: _RuleTile(
                        rule: rule,
                        onTap: () => _editRule(rule),
                      ),
                    ),
                ],
              ),
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
            showAdminMoreMenu(
              context,
              onSignOut: () => signOutAndReturnToLogin(context, ref),
            );
          }
        },
      ),
    );
  }
}

class _SectionDialog extends StatefulWidget {
  const _SectionDialog({required this.section, required this.valueOf});

  final _Section section;
  final String Function(_Field field) valueOf;

  @override
  State<_SectionDialog> createState() => _SectionDialogState();
}

class _SectionDialogState extends State<_SectionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers = {
    for (final field in widget.section.fields)
      field.key: TextEditingController(text: widget.valueOf(field)),
  };

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _validate(_Field field, String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Không được để trống.';
    switch (field.kind) {
      case _FieldKind.text:
        return null;
      case _FieldKind.integer:
        final parsed = int.tryParse(text);
        if (parsed == null) return 'Nhập một số nguyên.';
        if (parsed < 0) return 'Không được âm.';
        return null;
      case _FieldKind.decimal:
        if (double.tryParse(text.replaceAll(',', '.')) == null) {
          return 'Nhập một số hợp lệ.';
        }
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.section.title),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final field in widget.section.fields) ...[
              TextFormField(
                controller: _controllers[field.key],
                keyboardType: switch (field.kind) {
                  _FieldKind.text => TextInputType.text,
                  _FieldKind.integer => TextInputType.number,
                  _FieldKind.decimal => const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                },
                decoration: InputDecoration(
                  labelText: field.label,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) => _validate(field, value),
              ),
              const SizedBox(height: 12),
            ],
            if (widget.section.note != null)
              Text(
                widget.section.note!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.pop(context, {
              for (final field in widget.section.fields)
                field.key: _controllers[field.key]!.text.trim(),
            });
          },
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}

class _RuleDialog extends StatefulWidget {
  const _RuleDialog({required this.rule});

  final Map<String, dynamic> rule;

  @override
  State<_RuleDialog> createState() => _RuleDialogState();
}

class _RuleDialogState extends State<_RuleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _lead = TextEditingController(
    text: _text(widget.rule['leadMinutes'], '0'),
  );
  late final _interval = TextEditingController(
    text: _text(widget.rule['intervalMinutes'], '0'),
  );
  late final _attempts = TextEditingController(
    text: _text(widget.rule['maxAttempts'], '0'),
  );

  @override
  void dispose() {
    _lead.dispose();
    _interval.dispose();
    _attempts.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null) return 'Nhập một số nguyên.';
    if (parsed < 0) return 'Không được âm.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_text(widget.rule['description'], 'Quy tắc nhắc việc')),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _lead,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Nhắc trước (phút)',
                border: OutlineInputBorder(),
              ),
              validator: _validate,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _interval,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Khoảng cách giữa các lần nhắc (phút)',
                border: OutlineInputBorder(),
              ),
              validator: _validate,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _attempts,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Số lần nhắc tối đa',
                border: OutlineInputBorder(),
              ),
              validator: _validate,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.pop(context, {
              'leadMinutes': int.parse(_lead.text.trim()),
              'intervalMinutes': int.parse(_interval.text.trim()),
              'maxAttempts': int.parse(_attempts.text.trim()),
            });
          },
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({required this.rule, required this.onTap});

  final Map<String, dynamic> rule;
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        title: Text(
          _text(rule['description'], 'Quy tắc'),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        subtitle: Text(
          'Nhắc trước ${_intOf(rule['leadMinutes'])} phút · mỗi ${_intOf(rule['intervalMinutes'])} phút · '
          'tối đa ${_intOf(rule['maxAttempts'])} lần',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: AppColors.textSecondary,
        ),
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
    this.expandable = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool expandable;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDE8E3)),
      ),
      child: ListTile(
        onTap: expandable ? null : onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
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
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
        trailing: expandable
            ? const Icon(Icons.expand_more, color: AppColors.textSecondary)
            : const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      ),
    );
  }
}
