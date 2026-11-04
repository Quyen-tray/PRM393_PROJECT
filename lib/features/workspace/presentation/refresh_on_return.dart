import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/router/navigation_observer.dart';
import '../../operations/data/operations_repository.dart';

class RefreshOnReturn extends ConsumerStatefulWidget {
  const RefreshOnReturn({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<RefreshOnReturn> createState() => _RefreshOnReturnState();
}

class _RefreshOnReturnState extends ConsumerState<RefreshOnReturn>
    with RouteAware {
  RouteObserver<ModalRoute<dynamic>>? observer;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    observer = ref.read(shellObserverProvider);
    if (route != null) observer!.subscribe(this, route);
  }

  @override
  void didPopNext() {
    Future.microtask(() {
      if (mounted) ref.read(dataRevisionProvider.notifier).changed();
    });
  }

  @override
  void dispose() {
    observer?.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
