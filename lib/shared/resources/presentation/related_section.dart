import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RelatedSection extends StatelessWidget {
  const RelatedSection(
      {required this.title,
      required this.route,
      this.subtitle,
      this.icon = Icons.folder_open_outlined,
      super.key});
  final String title;
  final String? subtitle;
  final IconData icon;
  final String route;
  @override
  Widget build(BuildContext context) => Card(
          child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(route),
      ));
}
