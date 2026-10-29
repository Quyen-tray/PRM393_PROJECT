import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../data/mock/admin_demo_data.dart';
import '../../../shared/widgets/app_widgets.dart';
import 'widgets/admin_scaffold.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context) => AdminScaffold(
        title: 'Tổng quan quản trị',
        selectedIndex: 0,
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const Text(
              AdminDemoData.demoDate,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final (value, label) in AdminDemoData.stats)
                      SizedBox(
                        width: width,
                        child: AppPanel(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  value,
                                  style: const TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                                Text(
                                  label,
                                  style: const TextStyle(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            AppPanel(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nhân viên theo tháng',
                      style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 16),
                    const SizedBox(
                      height: 180,
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _LineChartPainter(
                          AdminDemoData.monthLabels,
                          AdminDemoData.monthValues,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      'Cần xử lý',
                      style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    ),
                  ),
                  ...divided([
                    for (final (text, count) in AdminDemoData.todos)
                      ListTile(
                        title: Text(text),
                        trailing: Text(
                          '$count',
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      );
}

class _LineChartPainter extends CustomPainter {
  const _LineChartPainter(this.labels, this.values);

  final List<String> labels;
  final List<int> values;

  @override
  void paint(Canvas canvas, Size size) {
    const labelHeight = 24.0;
    final chartHeight = size.height - labelHeight;
    final step = size.width / labels.length;
    double yOf(num value) => chartHeight - chartHeight * value / 20;

    final gridPaint = Paint()..color = AppColors.border;
    for (var g = 0; g <= 20; g += 5) {
      canvas.drawLine(Offset(0, yOf(g)), Offset(size.width, yOf(g)), gridPaint);
    }

    final points = [
      for (var i = 0; i < values.length; i++)
        Offset(step * i + step / 2, yOf(values[i])),
    ];
    canvas.drawPath(
      Path()..addPolygon(points, false),
      Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );

    final dotPaint = Paint()..color = AppColors.accent;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 4.5, dotPaint);
      textPainter.text = TextSpan(
        text: labels[i],
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(points[i].dx - textPainter.width / 2, size.height - 18),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) => false;
}
