import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_endpoints.dart';

Future<void> openEvidence(BuildContext context, String url) async {
  final uri = Uri.parse(ApiEndpoints.baseUrl).resolve(url);
  if (!['http', 'https'].contains(uri.scheme)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL bằng chứng không hợp lệ.')),
      );
    }
    return;
  }
  if (!await launchUrl(uri, mode: LaunchMode.platformDefault) &&
      context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Không mở được tệp. Tải lại chi tiết để lấy liên kết mới.',
        ),
      ),
    );
  }
}
