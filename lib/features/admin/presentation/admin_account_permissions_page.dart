import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/repositories/employee_providers.dart';

/// Tên tập quyền HR trong PermissionSets của backend. HR là tập quyền, không phải role (SRS 1.2).
const _hrSetName = 'HR';

const _roleLabels = <String, String>{
  'SYSTEM_ADMIN': 'System Admin',
  'STORE_MANAGER': 'Quản lý cửa hàng',
  'OPERATIONS_DIRECTOR': 'Giám đốc vận hành',
  'EMPLOYEE': 'Nhân viên',
};

/// Cấp hoặc thu hồi tập quyền HR cho một tài khoản (GET/PUT /api/v1/admin/users/{id}/permissions).
///
/// Máy chủ thay TOÀN BỘ quyền gán trực tiếp mỗi lần lưu. Vì vậy:
/// - Khi cấp HR: gửi lại toàn bộ quyền gán trực tiếp hiện có và thêm permissionSets ["HR"].
/// - Khi thu hồi HR: gửi quyền gán trực tiếp trừ các quyền thuộc tập HR, permissionSets rỗng.
/// Quyền gán riêng ngoài tập HR luôn được giữ nguyên.
class AdminAccountPermissionsPage extends ConsumerStatefulWidget {
  const AdminAccountPermissionsPage({required this.userId, this.displayName, this.email, super.key});

  final int? userId;
  final String? displayName;
  final String? email;

  @override
  ConsumerState<AdminAccountPermissionsPage> createState() => _AdminAccountPermissionsPageState();
}

class _AdminAccountPermissionsPageState extends ConsumerState<AdminAccountPermissionsPage> {
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  /// Mã quyền -> tên hiển thị (từ danh mục).
  Map<String, String> _names = {};

  /// Các mã quyền thuộc tập HR theo máy chủ.
  Set<String> _hrMembers = {};

  List<String> _roles = [];
  Set<String> _direct = {};
  Set<String> _effective = {};

  /// Trạng thái đã lưu và trạng thái đang chọn trên công tắc.
  bool _hrSaved = false;
  bool _hrOn = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = widget.userId;
    if (userId == null) {
      setState(() {
        _loading = false;
        _loadError = 'Tài khoản không hợp lệ.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final repo = ref.read(employeeRepositoryProvider);
      final results = await Future.wait<Map<String, dynamic>>([
        repo.getPermissionCatalog(),
        repo.getUserPermissions(userId),
      ]);
      if (!mounted) return;
      final catalog = results[0];
      final user = results[1];

      final names = <String, String>{
        for (final item in (catalog['permissions'] as List? ?? const []).whereType<Map>())
          _s(item['code']): _s(item['name']),
      };
      final sets = catalog['permissionSets'] is Map
          ? Map<String, dynamic>.from(catalog['permissionSets'] as Map)
          : <String, dynamic>{};
      final hrMembers = _strings(sets[_hrSetName]);
      final direct = _strings(user['direct']);
      final hrSaved = hrMembers.isNotEmpty && direct.containsAll(hrMembers);

      setState(() {
        _names = names;
        _hrMembers = hrMembers;
        _direct = direct;
        _effective = _strings(user['effective']);
        _roles = _strings(user['roles']).toList()..sort();
        _hrSaved = hrSaved;
        _hrOn = hrSaved;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Không tải được quyền của tài khoản.';
        _loading = false;
      });
    }
  }

  bool get _dirty => _hrOn != _hrSaved;

  /// Có một phần quyền HR gán riêng nhưng chưa đủ tập: bật công tắc sẽ cấp đủ.
  bool get _hrPartial => !_hrSaved && _direct.any(_hrMembers.contains);

  Future<void> _save() async {
    final userId = widget.userId;
    if (_saving || !_dirty || userId == null) return;

    final turningOn = _hrOn;
    final message = turningOn
        ? 'Cấp tập quyền HR (${_hrMembers.length} quyền) cho tài khoản này?'
        : 'Thu hồi tập quyền HR? Các quyền HR gán trực tiếp sẽ bị gỡ; quyền khác được giữ nguyên.';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Xác nhận')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Máy chủ thay toàn bộ quyền gán trực tiếp: phải gửi lại mọi quyền cần giữ.
    final codes = turningOn ? _direct : _direct.difference(_hrMembers);
    setState(() => _saving = true);
    try {
      final result = await ref.read(employeeRepositoryProvider).setUserPermissions(
            userId,
            permissions: codes.toList()..sort(),
            permissionSets: turningOn ? [_hrSetName] : <String>[],
          );
      if (!mounted) return;
      final direct = _strings(result['direct']);
      setState(() {
        _direct = direct;
        _effective = _strings(result['effective']);
        _hrSaved = _hrMembers.isNotEmpty && direct.containsAll(_hrMembers);
        _hrOn = _hrSaved;
        _saving = false;
      });
      _snack('Đã cập nhật quyền của tài khoản.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Không lưu được quyền. Vui lòng thử lại.');
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.displayName?.trim();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Phân quyền tài khoản'),
        leading: IconButton(
          tooltip: 'Quay lại',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_loadError!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: const Text('Thử lại')),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _card(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (name == null || name.isEmpty) ? 'Chưa có tên' : name,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(widget.email ?? '—', style: const TextStyle(color: AppColors.textSecondary)),
                          const SizedBox(height: 6),
                          Text(
                            _roles.isEmpty
                                ? 'Chưa có vai trò'
                                : 'Vai trò: ${_roles.map((r) => _roleLabels[r] ?? r).join(', ')}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    _card(
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Tập quyền HR', style: TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          _hrMembers.isEmpty
                              ? 'Máy chủ không trả về tập quyền HR.'
                              : _hrPartial
                                  ? 'Đang có một phần quyền HR. Bật để cấp đủ ${_hrMembers.length} quyền.'
                                  : '${_hrMembers.length} quyền. Nhân sự: xem, sửa hồ sơ, điểm danh, duyệt...',
                        ),
                        value: _hrOn,
                        onChanged: (_saving || _hrMembers.isEmpty) ? null : (value) => setState(() => _hrOn = value),
                      ),
                    ),
                    _card(
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('Các quyền trong tập HR'),
                        children: [
                          for (final code in (_hrMembers.toList()..sort()))
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(_names[code] ?? code),
                              subtitle: Text(code, style: const TextStyle(fontSize: 11)),
                            ),
                        ],
                      ),
                    ),
                    _card(
                      _otherDirectPermissions(),
                    ),
                    _card(
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text('Quyền hiệu lực: ${_effective.length}'),
                        subtitle: const Text('Gồm quyền theo vai trò và quyền gán riêng.'),
                        children: [
                          for (final code in (_effective.toList()..sort()))
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(_names[code] ?? code),
                              subtitle: Text(code, style: const TextStyle(fontSize: 11)),
                            ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(4, 4, 4, 12),
                      child: Text(
                        'Lưu sẽ thay toàn bộ quyền gán riêng của tài khoản bằng danh sách trên. Ứng dụng đã giữ lại các quyền ngoài tập HR.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: _loading || _loadError != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  onPressed: (_dirty && !_saving) ? _save : null,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Lưu thay đổi'),
                ),
              ),
            ),
    );
  }

  Widget _otherDirectPermissions() {
    final others = _direct.difference(_hrMembers).toList()..sort();
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text('Quyền gán riêng khác: ${others.length}'),
      subtitle: const Text('Không thuộc tập HR, được giữ nguyên khi lưu.'),
      children: [
        if (others.isEmpty)
          const ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text('Không có.'))
        else
          for (final code in others)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(_names[code] ?? code),
              subtitle: Text(code, style: const TextStyle(fontSize: 11)),
            ),
      ],
    );
  }

  Widget _card(Widget child) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: child,
      ),
    );
  }
}

// ---------- Tiện ích ----------

String _s(Object? value) => value?.toString().trim() ?? '';

Set<String> _strings(Object? value) =>
    value is List ? value.whereType<String>().toSet() : <String>{};
