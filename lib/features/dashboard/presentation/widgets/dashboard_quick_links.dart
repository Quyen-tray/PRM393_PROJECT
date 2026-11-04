import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hrm_coffee_shop_flutter/app/router/module_registry.dart';

class DashboardQuickLinks extends StatelessWidget {
  const DashboardQuickLinks(this.keys, {super.key});
  final List<String> keys;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, size) => Wrap(
          spacing: 12,
          runSpacing: 12,
          children: keys.map((key) {
            final spec = module(key);
            return SizedBox(
              width: size.maxWidth < 500
                  ? (size.maxWidth - 24) / 3
                  : (size.maxWidth - 36) / 4,
              child: Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.push(spec.listRoute),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 20,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          spec.icon,
                          color: Theme.of(context).colorScheme.primary,
                          size: 28,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          spec.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
}
