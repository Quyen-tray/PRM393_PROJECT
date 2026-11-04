import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hrm_coffee_shop_flutter/core/presentation/resource_widgets.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/domain/module_spec.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/presentation/record_summary.dart';

class LinkedResourceList extends ConsumerWidget {
  const LinkedResourceList(
    this.path,
    this.spec, {
    required this.title,
    this.navigable = true,
    super.key,
  });
  final String path, title;
  final ModuleSpec spec;
  final bool navigable;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(title),
          ResourceView(
            ResourceQuery(path),
            builder: (data) {
              final rows = ResourcePage.parse(data).items;
              return rows.isEmpty
                  ? const EmptyPanel()
                  : Column(
                      children: rows
                          .map(
                            (r) => navigable
                                ? Card(
                                    child: ListTile(
                                      title: Text(rowTitle(spec, r)),
                                      subtitle: Text(rowSubtitle(spec, r)),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () => context.push(
                                        spec.recordRoute(recordId(spec, r)),
                                      ),
                                    ),
                                  )
                                : InfoCard(r),
                          )
                          .toList(),
                    );
            },
          ),
        ],
      );
}
