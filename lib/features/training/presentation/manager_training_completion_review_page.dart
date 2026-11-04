import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/presentation/sign_out_flow.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/repositories/employee_providers.dart';
import '../../admin/presentation/widgets/admin_bottom_navigation.dart';
import '../../admin/presentation/widgets/admin_more_menu.dart';
import '../../../shared/widgets/employee_bottom_navigation.dart';
import '../../home/presentation/widgets/manager_bottom_navigation.dart';

class ManagerTrainingCompletionReviewPage extends ConsumerStatefulWidget {
  const ManagerTrainingCompletionReviewPage({
    super.key,
    this.returnRoute = RouteNames.home,
    this.isAdmin = false,
  });

  final String returnRoute;
  final bool isAdmin;

  @override
  ConsumerState<ManagerTrainingCompletionReviewPage> createState() =>
      _ManagerTrainingCompletionReviewPageState();
}

class _ManagerTrainingCompletionReviewPageState
    extends ConsumerState<ManagerTrainingCompletionReviewPage> {
  List<Map<String, dynamic>> _requests = [];
  final Set<int> _busy = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final requests = await ref
          .read(employeeRepositoryProvider)
          .getPendingTrainingCompletions();
      if (mounted) setState(() => _requests = requests);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Không tải được danh sách khóa học cần xác nhận hoàn thành.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int? _requestId(Map<String, dynamic> request) =>
      (request['employeeTrainingId'] as num?)?.toInt();

  Future<void> _approve(Map<String, dynamic> request) async {
    final id = _requestId(request);
    if (id == null || _busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      await ref.read(employeeRepositoryProvider).approveTrainingCompletion(id);
      if (!mounted) return;
      _message('Đã duyệt hoàn thành khóa học.');
      await _load();
    } catch (error) {
      if (mounted) {
        _message(
          error is ApiException
              ? error.message
              : 'Không thể duyệt hoàn thành khóa học.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _markNotComplete(Map<String, dynamic> request) async {
    final id = _requestId(request);
    if (id == null || _busy.contains(id)) return;
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _RejectCompletionDialog(),
    );
    if (!mounted || reason == null) return;

    setState(() => _busy.add(id));
    try {
      await ref
          .read(employeeRepositoryProvider)
          .markTrainingNotComplete(id, reason);
      if (!mounted) return;
      _message('Đã ghi nhận khóa học chưa hoàn thành.');
      await _load();
    } catch (error) {
      if (mounted) {
        _message(
          error is ApiException
              ? error.message
              : 'Không thể ghi nhận trạng thái khóa học.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Quay lại',
          onPressed: () => context.go(widget.returnRoute),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Duyệt hoàn thành khóa học'),
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
          : _error != null && _requests.isEmpty
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
          : _requests.isEmpty
          ? const Center(
              child: Text('Không có khóa học thực hành cần xác nhận.'),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  for (final request in _requests) _requestCard(request),
                ],
              ),
            ),
      bottomNavigationBar: widget.isAdmin
          ? AdminBottomNavigation(
              selectedIndex: 3,
              onDestinationSelected: (index) {
                if (index == 0) context.go(RouteNames.adminHome);
                if (index == 1) context.go(RouteNames.adminAccounts);
                if (index == 2) context.go(RouteNames.adminPositions);
                if (index == 3) context.go(RouteNames.adminTraining);
                if (index == 4) {
                  showAdminMoreMenu(
                    context,
                    onSignOut: () => signOutAndReturnToLogin(context, ref),
                  );
                }
              },
            )
          : widget.returnRoute == RouteNames.employeeHome
          ? const EmployeeBottomNavigation(selectedIndex: 0)
          : const ManagerBottomNavigation(selectedIndex: 3),
    );
  }

  Widget _requestCard(Map<String, dynamic> request) {
    final id = _requestId(request);
    final busy = id != null && _busy.contains(id);
    final enrolledAt = request['enrolledAt']?.toString();
    final employeeName = (request['employeeName'] ?? 'Nhân viên').toString();
    final courseName = (request['courseName'] ?? 'Khóa học').toString();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.school_outlined, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    courseName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const Chip(label: Text('CẦN XÁC NHẬN')),
              ],
            ),
            const SizedBox(height: 8),
            Text('Nhân viên: $employeeName'),
            Text('Mã nhân viên: ${request['employeeCode'] ?? '—'}'),
            Text('Ghi danh: ${formatDate(enrolledAt)}'),
            if ((request['reviewNote'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Lần xác nhận trước: ${request['reviewNote']}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : () => _markNotComplete(request),
                    child: const Text('Chưa hoàn thành'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : () => _approve(request),
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Xác nhận hoàn thành'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RejectCompletionDialog extends StatefulWidget {
  const _RejectCompletionDialog();

  @override
  State<_RejectCompletionDialog> createState() =>
      _RejectCompletionDialogState();
}

class _RejectCompletionDialogState extends State<_RejectCompletionDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Ghi nhận chưa hoàn thành'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: 500,
      maxLines: 3,
      onChanged: (_) => setState(() {}),
      decoration: const InputDecoration(
        labelText: 'Nhận xét cho nhân viên',
        border: OutlineInputBorder(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () {
          final value = _controller.text.trim();
          if (value.isNotEmpty) Navigator.pop(context, value);
        },
        child: const Text('Ghi nhận'),
      ),
    ],
  );
}
