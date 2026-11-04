import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_coffee_shop_flutter/core/presentation/resource_widgets.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/presentation/record_form.dart';
import 'package:hrm_coffee_shop_flutter/core/location/location_service.dart';
import 'package:hrm_coffee_shop_flutter/features/store/domain/store_fields.dart';

class StoreSettingsPage extends ConsumerStatefulWidget {
  const StoreSettingsPage({super.key});
  @override
  ConsumerState<StoreSettingsPage> createState() => _StoreSettingsPageState();
}

class _StoreSettingsPageState extends ConsumerState<StoreSettingsPage> {
  bool locating = false;
  Object? error;
  @override
  Widget build(BuildContext context) => PageBody(
        children: [
          const SectionTitle('Vị trí quán và chính sách chấm công'),
          const Text(
            'Tọa độ đã lưu sẽ được dùng để kiểm tra GPS của nhân viên. Có thể lấy GPS ngay tại quán, xem lại vị trí và lưu trước khi đổi tài khoản để chấm công.',
          ),
          ResourceView(
            const ResourceQuery('/admin/store-settings'),
            builder: (data) {
              final row = {...json(data), ...json(json(data)['store'])};
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => editRecord(
                          context,
                          ref,
                          title: 'Cấu hình cửa hàng',
                          fields: storeFields,
                          initial: row,
                          path: '/admin/store-settings',
                          method: 'PATCH',
                        ),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Chỉnh sửa cấu hình'),
                      ),
                      FilledButton.icon(
                        onPressed: locating
                            ? null
                            : () async {
                                setState(() {
                                  locating = true;
                                  error = null;
                                });
                                try {
                                  final p = await actualLocation();
                                  if (context.mounted) {
                                    await editRecord(
                                      context,
                                      ref,
                                      title: 'Xác nhận vị trí quán từ GPS',
                                      fields: const [
                                        FieldSpec(
                                          'latitude',
                                          'Vĩ độ',
                                          kind: FieldKind.decimal,
                                          required: true,
                                          min: -90,
                                          max: 90,
                                        ),
                                        FieldSpec(
                                          'longitude',
                                          'Kinh độ',
                                          kind: FieldKind.decimal,
                                          required: true,
                                          min: -180,
                                          max: 180,
                                        ),
                                        FieldSpec(
                                          'attendanceRadiusMeters',
                                          'Bán kính chấm công (m)',
                                          kind: FieldKind.integer,
                                          required: true,
                                          min: 1,
                                        ),
                                      ],
                                      initial: {
                                        ...row,
                                        'latitude': p.latitude,
                                        'longitude': p.longitude,
                                      },
                                      path: '/admin/store-settings',
                                      method: 'PATCH',
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) setState(() => error = e);
                                } finally {
                                  if (mounted) setState(() => locating = false);
                                }
                              },
                        icon: locating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.my_location),
                        label: const Text('Dùng GPS tại quán'),
                      ),
                    ],
                  ),
                  InfoCard(row),
                ],
              );
            },
          ),
          if (error != null) ErrorPanel(error!),
        ],
      );
}
