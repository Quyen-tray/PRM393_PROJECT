import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_coffee_shop_flutter/core/presentation/resource_widgets.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/data/session_controller.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/presentation/record_form.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = ref.watch(sessionProvider).user!;
    return PageBody(
      children: [
        ResourceView(
          const ResourceQuery('/users/me'),
          builder: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InfoCard(json(data), title: 'Tài khoản cá nhân'),
              TextButton.icon(
                onPressed: () async {
                  final changed = await editRecord(
                    context,
                    ref,
                    title: 'Cập nhật thông tin cá nhân',
                    fields: const [
                      FieldSpec('displayName', 'Tên hiển thị', required: true),
                      FieldSpec('phoneNumber', 'Số điện thoại'),
                    ],
                    initial: json(data),
                    path: '/users/me',
                    method: 'PATCH',
                  );
                  if (changed == true) {
                    await ref.read(sessionProvider.notifier).loadProfile();
                  }
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Chỉnh sửa thông tin'),
              ),
            ],
          ),
        ),
        if (u.employeeId != null)
          ResourceView(
            const ResourceQuery('/employees/me'),
            builder: (data) => InfoCard(json(data), title: 'Hồ sơ nhân viên'),
          ),
        const SectionTitle('Vai trò hiện tại'),
        Wrap(
          spacing: 8,
          children: u.roles.map((r) => Chip(label: Text(roleName(r)))).toList(),
        ),
      ],
    );
  }
}
