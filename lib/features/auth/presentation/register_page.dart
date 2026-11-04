import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Quay lại đăng nhập',
          onPressed: () => context.go(RouteNames.login),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Cấp tài khoản'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.admin_panel_settings_outlined, size: 52),
                const SizedBox(height: 16),
                Text(
                  'Tài khoản do quản trị viên cấp',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Hệ thống không mở đăng ký công khai. Vui lòng liên hệ quản trị viên để tạo tài khoản và cấp đúng địa chỉ Gmail trước khi đăng nhập.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
