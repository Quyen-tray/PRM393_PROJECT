import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Khung trắng có viền, dùng cho khối nội dung.
class AppPanel extends StatelessWidget {
  const AppPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      );
}

/// Chèn đường kẻ giữa các phần tử trong danh sách.
List<Widget> divided(List<Widget> items) => [
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) const Divider(height: 1, color: AppColors.border),
        items[i],
      ],
    ];

class StatusTag extends StatelessWidget {
  const StatusTag(
    this.text, {
    super.key,
    this.color = AppColors.primary,
    this.background = const Color(0xFFF0E6DF),
  });

  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          text,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );
}

void showAppSnack(BuildContext context, String message) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(message)));
