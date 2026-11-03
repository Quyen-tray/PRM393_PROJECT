import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/presentation/sign_out_flow.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../data/repositories/employee_providers.dart';
import 'admin_checklist_template_editor_page.dart';
import 'widgets/admin_bottom_navigation.dart';
import 'widgets/admin_more_menu.dart';

int _intOf(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

/// Quản lý mẫu checklist. Mỗi bản ghi của API là một phiên bản; các phiên bản cùng mã
/// được gom thành một mẫu. Chỉ một phiên bản của mỗi mã được hoạt động.
class AdminChecklistManagementPage extends ConsumerStatefulWidget {
  const AdminChecklistManagementPage({super.key});

  @override
  ConsumerState<AdminChecklistManagementPage> createState() =>
      _AdminChecklistManagementPageState();
}

class _AdminChecklistManagementPageState
    extends ConsumerState<AdminChecklistManagementPage> {
  List<Map<String, dynamic>> _versions = [];
  bool _loading = true;
  bool _acting = false;
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
      final rows = await ref
          .read(employeeRepositoryProvider)
          .getAdminChecklistTemplates();
      if (mounted) setState(() => _versions = rows);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is ApiException
            ? error.message
            : 'Không tải được mẫu checklist. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Các mẫu, mỗi mã một nhóm, sắp theo tên. Phiên bản đại diện là phiên bản đang hoạt động,
  /// nếu chưa có thì là phiên bản mới nhất.
  Map<String, List<Map<String, dynamic>>> get _groups {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final row in _versions) {
      final code = (row['checklistCode'] ?? '').toString();
      groups.putIfAbsent(code, () => []).add(row);
    }
    for (final list in groups.values) {
      list.sort((a, b) => _intOf(b['version']).compareTo(_intOf(a['version'])));
    }
    return groups;
  }

  Map<String, dynamic> _representative(List<Map<String, dynamic>> versions) =>
      versions.firstWhere((v) => v['isActive'] == true,
          orElse: () => versions.first);

  Future<void> _openEditor([Map<String, dynamic>? template]) async {
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute(
          builder: (_) => AdminChecklistTemplateEditorPage(template: template)),
    );
    if (message != null && mounted) {
      _showMessage(message);
      await _load();
    }
  }

  Future<void> _activate(Map<String, dynamic> version) async {
    final name =
        (version['checklistName'] ?? version['checklistCode']).toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Kích hoạt phiên bản?'),
        content: Text(
          'Kích hoạt v${version['version']} cho "$name". '
          'Các phiên bản khác cùng mã sẽ ngừng hoạt động.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Kích hoạt')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _acting = true);
    try {
      await ref
          .read(employeeRepositoryProvider)
          .activateAdminChecklistTemplate(_intOf(version['templateId']));
      _showMessage('Đã kích hoạt phiên bản checklist.');
      await _load();
    } catch (error) {
      _showMessage(error is ApiException
          ? error.message
          : 'Không kích hoạt được phiên bản.');
    } finally {
      if (mounted) setState(() => _acting = false);
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
    final sortedCodes = _groups.keys.toList()
      ..sort((a, b) => _representative(_groups[a]!)['checklistName']
          .toString()
          .compareTo(_representative(_groups[b]!)['checklistName'].toString()));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Quản lý checklist'),
          leading: IconButton(
            tooltip: 'Quay lại Dashboard Admin',
            onPressed: () => context.go(RouteNames.adminHome),
            icon: const Icon(Icons.arrow_back),
          ),
          actions: [
            IconButton(
              tooltip: 'Tải lại',
              onPressed: _loading || _acting ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: const TabBar(
              tabs: [Tab(text: 'Template'), Tab(text: 'Phiên bản')]),
        ),
        body: _loading && _versions.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _versions.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton(
                              onPressed: _load, child: const Text('Thử lại')),
                        ],
                      ),
                    ),
                  )
                : TabBarView(
                    children: [
                      _TemplatesTab(
                        codes: sortedCodes,
                        groups: _groups,
                        representative: _representative,
                        onTap: (versions) =>
                            _openEditor(_representative(versions)),
                        onRefresh: _load,
                      ),
                      _VersionsTab(
                        versions: _versions,
                        busy: _acting,
                        onActivate: _activate,
                        onRefresh: _load,
                      ),
                    ],
                  ),
        floatingActionButton: FloatingActionButton(
          tooltip: 'Tạo mẫu mới',
          onPressed: _loading || _acting ? null : () => _openEditor(),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          child: const Icon(Icons.add),
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
      ),
    );
  }
}

class _TemplatesTab extends StatelessWidget {
  const _TemplatesTab({
    required this.codes,
    required this.groups,
    required this.representative,
    required this.onTap,
    required this.onRefresh,
  });

  final List<String> codes;
  final Map<String, List<Map<String, dynamic>>> groups;
  final Map<String, dynamic> Function(List<Map<String, dynamic>>)
      representative;
  final void Function(List<Map<String, dynamic>> versions) onTap;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (codes.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 160),
            Center(child: Text('Chưa có mẫu checklist nào.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        itemCount: codes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 9),
        itemBuilder: (context, index) {
          final versions = groups[codes[index]]!;
          final shown = representative(versions);
          final hasActive = versions.any((v) => v['isActive'] == true);
          return _TemplateCard(
            name: (shown['checklistName'] ?? codes[index]).toString(),
            code: codes[index],
            type: checklistTypeLabel(shown['checklistType']?.toString()),
            itemCount: ((shown['items'] as List?) ?? const []).length,
            versionLabel: hasActive
                ? 'Đang dùng v${shown['version']}'
                : 'Chưa có phiên bản kích hoạt (v${shown['version']} mới nhất)',
            warning: !hasActive,
            managerApproval: shown['managerApprovalRequired'] == true,
            onTap: () => onTap(versions),
          );
        },
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.name,
    required this.code,
    required this.type,
    required this.itemCount,
    required this.versionLabel,
    required this.warning,
    required this.managerApproval,
    required this.onTap,
  });

  final String name;
  final String code;
  final String type;
  final int itemCount;
  final String versionLabel;
  final bool warning;
  final bool managerApproval;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                '$code · $type · $itemCount công việc',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Text(
                versionLabel,
                style: TextStyle(
                  color: warning ? AppColors.error : AppColors.secondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (managerApproval)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Quản lý duyệt sau khi nộp',
                    style:
                        TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VersionsTab extends StatelessWidget {
  const _VersionsTab({
    required this.versions,
    required this.busy,
    required this.onActivate,
    required this.onRefresh,
  });

  final List<Map<String, dynamic>> versions;
  final bool busy;
  final ValueChanged<Map<String, dynamic>> onActivate;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final sorted = [...versions]..sort((a, b) {
        final byCode = (a['checklistCode'] ?? '')
            .toString()
            .compareTo((b['checklistCode'] ?? '').toString());
        return byCode != 0
            ? byCode
            : _intOf(b['version']).compareTo(_intOf(a['version']));
      });

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        itemCount: sorted.length,
        separatorBuilder: (_, __) => const SizedBox(height: 9),
        itemBuilder: (context, index) {
          final version = sorted[index];
          final active = version['isActive'] == true;
          final itemCount = ((version['items'] as List?) ?? const []).length;
          return Card(
            color: AppColors.surface,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${version['checklistName'] ?? version['checklistCode']} · v${version['version']}',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${version['checklistCode']} · $itemCount công việc',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          active ? 'Đang hoạt động' : 'Chưa kích hoạt',
                          style: TextStyle(
                            color: active
                                ? AppColors.secondary
                                : AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!active)
                    FilledButton.tonal(
                      onPressed: busy ? null : () => onActivate(version),
                      child: const Text('Kích hoạt'),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
