import 'package:flutter/material.dart';
<<<<<<< HEAD

import '../../../app/theme/app_colors.dart';
import '../../../data/mock/admin_demo_data.dart';
import '../../../shared/widgets/app_widgets.dart';
import 'widgets/admin_scaffold.dart';
=======
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../data/mock/demo_data.dart';
import 'widgets/admin_bottom_navigation.dart';
import 'widgets/admin_more_menu.dart';
>>>>>>> 5c3baa370fcab08f7ffb19b4b696471f7d945ae6

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

<<<<<<< HEAD
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
=======
  static const _metrics = <_AdminMetric>[
    _AdminMetric(
      label: 'Tổng nhân viên',
      value: DemoData.adminTotalEmployees,
      icon: Icons.people_alt_outlined,
      color: Color(0xFF2196F3),
    ),
    _AdminMetric(
      label: 'Tài khoản hoạt động',
      value: DemoData.adminActiveAccounts,
      icon: Icons.verified_user_outlined,
      color: Color(0xFF28A765),
    ),
    _AdminMetric(
      label: 'Khóa học',
      value: DemoData.adminCourseCount,
      icon: Icons.school_outlined,
      color: Color(0xFFE39A2F),
    ),
    _AdminMetric(
      label: 'Checklist',
      value: DemoData.adminChecklistTemplateCount,
      icon: Icons.fact_check_outlined,
      color: Color(0xFFE75B59),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(Icons.coffee, color: Color(0xFFF1D2A6)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'HRM COFFEE SHOP',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(Icons.settings_outlined, color: Colors.white),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Dashboard Admin',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Quản trị hệ thống · ${DemoData.storeName}',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900 ? 4 : 2;
                final tileWidth =
                    (constraints.maxWidth - 10 * (columns - 1)) / columns;

                return GridView.count(
                  crossAxisCount: columns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: tileWidth / 112,
                  children: [
                    for (final metric in _metrics)
                      _AdminMetricCard(metric: metric),
>>>>>>> 5c3baa370fcab08f7ffb19b4b696471f7d945ae6
                  ],
                );
              },
            ),
<<<<<<< HEAD
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
=======
            const SizedBox(height: 22),
            const Text(
              'Nhân viên theo tháng',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            _EmployeeTrendCard(
              values: DemoData.adminMonthlyEmployeeCounts,
              labels: DemoData.adminDashboardMonthLabels,
            ),
          ],
        ),
      ),
      bottomNavigationBar: AdminBottomNavigation(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index == 1) {
            context.go(RouteNames.adminAccounts);
            return;
          }
          if (index == 2) {
            context.go(RouteNames.adminPositions);
            return;
          }
          if (index == 3) {
            context.go(RouteNames.adminTraining);
            return;
          }
          if (index == 0) return;
          showAdminMoreMenu(context);
        },
      ),
    );
  }
}

class _AdminMetric {
  const _AdminMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;
}

class _AdminMetricCard extends StatelessWidget {
  const _AdminMetricCard({required this.metric});

  final _AdminMetric metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDE8E3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: metric.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(metric.icon, color: metric.color, size: 19),
          ),
          Text(
            '${metric.value}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            metric.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeTrendCard extends StatelessWidget {
  const _EmployeeTrendCard({
    required this.values,
    required this.labels,
  });

  final List<int> values;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDE8E3)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 170,
            width: double.infinity,
            child: CustomPaint(
              painter: _EmployeeTrendPainter(values: values),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final label in labels)
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmployeeTrendPainter extends CustomPainter {
  const _EmployeeTrendPainter({required this.values});

>>>>>>> 5c3baa370fcab08f7ffb19b4b696471f7d945ae6
  final List<int> values;

  @override
  void paint(Canvas canvas, Size size) {
<<<<<<< HEAD
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
=======
    const left = 8.0;
    const right = 8.0;
    const top = 8.0;
    const bottom = 8.0;
    const maxValue = 20.0;

    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;

    final gridPaint = Paint()
      ..color = const Color(0xFFEDE8E3)
      ..strokeWidth = 1;

    for (var row = 0; row < 4; row++) {
      final y = top + chartHeight * row / 3;
      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - right, y),
        gridPaint,
      );
    }

    if (values.length < 2) return;

    final points = <Offset>[
      for (var index = 0; index < values.length; index++)
        Offset(
          left + chartWidth * index / (values.length - 1),
          top + chartHeight * (1 - values[index] / maxValue),
        ),
    ];

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      linePath.lineTo(point.dx, point.dy);
    }

    final linePaint = Paint()
      ..color = const Color(0xFF39A1E8)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawPath(linePath, linePaint);

    final pointPaint = Paint()..color = const Color(0xFF39A1E8);
    for (final point in points) {
      canvas.drawCircle(point, 4, pointPaint);
>>>>>>> 5c3baa370fcab08f7ffb19b4b696471f7d945ae6
    }
  }

  @override
<<<<<<< HEAD
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) => false;
=======
  bool shouldRepaint(covariant _EmployeeTrendPainter oldDelegate) {
    return oldDelegate.values != values;
  }
>>>>>>> 5c3baa370fcab08f7ffb19b4b696471f7d945ae6
}
