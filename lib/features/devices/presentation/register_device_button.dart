import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_providers.dart';
import 'package:hrm_coffee_shop_flutter/core/presentation/resource_widgets.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/presentation/record_form.dart';

class RegisterDeviceButton extends ConsumerWidget {
  const RegisterDeviceButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = 'register-device';
    final state = ref.watch(operationProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilledButton.icon(
          onPressed: state.busy.contains(key)
              ? null
              : () async {
                  String? platform;
                  String label = '';
                  if (!kIsWeb &&
                      defaultTargetPlatform == TargetPlatform.android) {
                    platform = 'ANDROID';
                    final info = await DeviceInfoPlugin().androidInfo;
                    label = '${info.manufacturer} ${info.model}';
                  }
                  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
                    platform = 'IOS';
                    label = (await DeviceInfoPlugin().iosInfo).name;
                  }
                  if (!context.mounted) return;
                  if (platform == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Đăng ký thiết bị chấm công hỗ trợ Android và iOS. Dùng ứng dụng trên điện thoại hoặc Android Emulator.',
                        ),
                      ),
                    );
                    return;
                  }
                  final credential =
                      ref.read(authenticatedApiProvider).vault.deviceCredential;
                  await editRecord(
                    context,
                    ref,
                    title: 'Đăng ký thiết bị chấm công',
                    fields: const [
                      FieldSpec('deviceLabel', 'Tên thiết bị', required: true),
                    ],
                    initial: {'deviceLabel': label},
                    path: '/attendance/devices/register',
                    fixed: {
                      'deviceFingerprint': credential,
                      'platform': platform,
                    },
                  );
                },
          icon: const Icon(Icons.add_to_home_screen),
          label: const Text('Đăng ký máy đang dùng'),
        ),
        if (state.errors[key] != null) ErrorPanel(state.errors[key]!),
      ],
    );
  }
}
