import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/operations/data/operations_repository.dart';
import '../network/api_exception.dart';
import 'business_labels.dart';

class ErrorPanel extends StatelessWidget {
  const ErrorPanel(this.error, {this.retry, super.key});
  final Object error;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context) {
    final apiError = error is ApiException ? error as ApiException : null;
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .errorContainer
                .withValues(alpha: .45),
            borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(apiError?.statusCode == 403
                ? Icons.lock_outline
                : Icons.error_outline),
            const SizedBox(width: 8),
            Expanded(
                child: Text(
                    apiError?.statusCode == 403
                        ? 'Không đủ quyền'
                        : apiError?.statusCode == 404
                            ? 'Dữ liệu không còn tồn tại'
                            : 'Chưa thể hoàn tất',
                    style: const TextStyle(fontWeight: FontWeight.w700)))
          ]),
          const SizedBox(height: 8),
          Text(apiError?.message ??
              'Không thể hoàn tất thao tác. Hãy thử lại hoặc tải lại dữ liệu.'),
          if (apiError != null)
            ...apiError.details.entries.map((e) => Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text('${fieldLabels[e.key] ?? e.key}: ${e.value}'))),
          if (retry != null)
            TextButton.icon(
                onPressed: retry,
                icon: const Icon(Icons.refresh),
                label: const Text('Tải lại')),
        ]));
  }
}

class ResourceView extends ConsumerWidget {
  const ResourceView(this.query, {required this.builder, super.key});
  final ResourceQuery query;
  final Widget Function(dynamic data) builder;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(resourceProvider(query)).when(
          loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator())),
          error: (error, _) => ErrorPanel(error,
              retry: () => ref.invalidate(resourceProvider(query))),
          data: builder);
}

class InfoCard extends StatelessWidget {
  const InfoCard(this.data, {this.title, this.omit = const {}, super.key});
  final Json data;
  final String? title;
  final Set<String> omit;
  @override
  Widget build(BuildContext context) {
    final entries = data.entries
        .where((e) =>
            !omit.contains(e.key) &&
            fieldLabels.containsKey(e.key) &&
            e.value is! List &&
            e.value is! Map)
        .toList();
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(18),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (title != null) ...[
                Text(title!, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12)
              ],
              ...entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: LayoutBuilder(builder: (context, size) {
                    final label = Text(fieldLabels[e.key]!,
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant));
                    final value = Text(valueText(e.key, e.value),
                        style: const TextStyle(fontWeight: FontWeight.w600));
                    return size.maxWidth < 380
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [label, value])
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                SizedBox(
                                    width: size.maxWidth * .43, child: label),
                                Expanded(child: value)
                              ]);
                  }))),
              ...data.entries
                  .where((e) => e.value is Map && !omit.contains(e.key))
                  .map((e) =>
                      InfoCard(json(e.value), title: fieldLabels[e.key])),
            ])));
  }
}

class EmptyPanel extends StatelessWidget {
  const EmptyPanel(
      {this.message = 'Chưa có dữ liệu trong bộ lọc này.', super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(32),
      child: Column(children: [
        Icon(Icons.inbox_outlined,
            size: 46, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center)
      ]));
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {this.action, super.key});
  final String title;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(2, 22, 2, 10),
      child: Row(children: [
        Expanded(
            child: Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700))),
        if (action != null) action!
      ]));
}

class PageBody extends StatelessWidget {
  const PageBody({required this.children, this.onRefresh, super.key});
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  @override
  Widget build(BuildContext context) {
    final list = ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children)))
        ]);
    return onRefresh == null
        ? list
        : RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}
