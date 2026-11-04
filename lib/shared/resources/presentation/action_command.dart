import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_coffee_shop_flutter/core/presentation/resource_widgets.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';

class ActionCommand extends ConsumerWidget {
  const ActionCommand(
    this.keyName,
    this.label,
    this.path, {
    this.body,
    this.method = 'POST',
    super.key,
  });
  final String keyName, label, path, method;
  final Object? body;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(operationProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton(
          onPressed: state.busy.contains(keyName)
              ? null
              : () =>
                  ref.read(operationProvider.notifier).run(keyName, () async {
                    await ref
                        .read(resourceRepositoryProvider)
                        .write(method, path, body);
                  }),
          child: Text(state.busy.contains(keyName) ? 'Đang xử lý…' : label),
        ),
        if (state.errors[keyName] != null) ErrorPanel(state.errors[keyName]!),
      ],
    );
  }
}
