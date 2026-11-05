import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_coffee_shop_flutter/core/presentation/resource_widgets.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/presentation/record_form.dart';

class AccountPermissionsEditor extends ConsumerWidget {
  const AccountPermissionsEditor(this.id, {super.key});
  final String id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ResourceView(
        ResourceQuery('/admin/users/$id/permissions'),
        builder: (current) => ResourceView(
          const ResourceQuery('/admin/users/permission-catalog'),
          builder: (data) {
            final grants = json(current);
            final catalog = json(data);
            final perms = ResourcePage.parse(catalog['permissions']).items;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quyền hiệu lực được máy chủ tổng hợp từ vai trò và quyền gán trực tiếp.',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      List<String>.from(
                        grants['effective'] as List? ?? [],
                      ).join(', '),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => editRecord(
                        context,
                        ref,
                        title: 'Cấp quyền trực tiếp',
                        fields: [
                          FieldSpec(
                            'permissions',
                            'Quyền trực tiếp',
                            kind: FieldKind.multiple,
                            options: perms.map((p) => '${p['code']}').toList(),
                          ),
                          FieldSpec(
                            'permissionSets',
                            'Bổ sung từ bộ quyền',
                            kind: FieldKind.multiple,
                            options:
                                json(catalog['permissionSets']).keys.toList(),
                          ),
                        ],
                        initial: {
                          'permissions': grants['direct'],
                          'permissionSets': <String>[],
                        },
                        path: '/admin/users/$id/permissions',
                        method: 'PUT',
                      ),
                      child: const Text('Chỉnh sửa quyền'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
}
