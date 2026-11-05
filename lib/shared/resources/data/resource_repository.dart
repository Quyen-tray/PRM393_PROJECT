import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_coffee_shop_flutter/core/network/authenticated_api.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_exception.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_providers.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/data/session_controller.dart';

typedef Json = Map<String, dynamic>;
Json json(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

class ResourcePage {
  const ResourcePage(
    this.items, {
    this.page = 0,
    this.totalPages = 1,
    this.total = 0,
  });
  final List<Json> items;
  final int page, totalPages, total;
  factory ResourcePage.parse(Object? value) {
    final map = json(value);
    final items = value is List
        ? value
        : map['items'] is List
            ? map['items'] as List
            : value == null
                ? []
                : [value];
    return ResourcePage(
      items.map(json).toList(),
      page: (map['page'] as num?)?.toInt() ?? 0,
      totalPages: (map['totalPages'] as num?)?.toInt() ?? 1,
      total: (map['totalElements'] as num?)?.toInt() ?? items.length,
    );
  }
}

class ResourceQuery {
  const ResourceQuery(this.path, [this.query = const {}]);
  final String path;
  final Json query;
  @override
  bool operator ==(Object other) =>
      other is ResourceQuery &&
      path == other.path &&
      jsonEncode(query) == jsonEncode(other.query);
  @override
  int get hashCode => Object.hash(path, jsonEncode(query));
}

class ResourceRepository {
  ResourceRepository(this.api);
  final AuthenticatedApi api;
  Future<dynamic> read(String path, [Json query = const {}]) =>
      api.data('GET', path, query: query);
  Future<dynamic> write(String method, String path, [Object? body]) =>
      api.data(method, path, body: body);
  Future<ResourcePage> list(String path, [Json query = const {}]) async =>
      ResourcePage.parse(await read(path, query));
}

final resourceRepositoryProvider = Provider(
  (ref) => ResourceRepository(ref.watch(authenticatedApiProvider)),
);

class DataRevision extends Notifier<int> {
  @override
  int build() => 0;
  void changed() => state++;
}

final dataRevisionProvider = NotifierProvider<DataRevision, int>(
  DataRevision.new,
);
final resourceProvider = FutureProvider.autoDispose
    .family<dynamic, ResourceQuery>(
  (ref, query) async {
    ref.watch(dataRevisionProvider);
    ref.watch(sessionProvider.select((s) => s.user));
    return ref.watch(resourceRepositoryProvider).read(query.path, query.query);
  },
  // Surface API failures immediately; ResourceView provides an explicit retry.
  retry: (retryCount, error) => error is ApiException
      ? null
      : ProviderContainer.defaultRetry(retryCount, error),
);

class OperationState {
  const OperationState({this.busy = const {}, this.errors = const {}});
  final Set<String> busy;
  final Map<String, Object> errors;
}

final operationProvider = NotifierProvider<OperationController, OperationState>(
  OperationController.new,
);

class OperationController extends Notifier<OperationState> {
  @override
  OperationState build() => const OperationState();
  Future<bool> run(String key, Future<void> Function() action) async {
    if (state.busy.contains(key)) return false;
    state = OperationState(
      busy: {...state.busy, key},
      errors: {...state.errors}..remove(key),
    );
    try {
      await action();
      ref.read(dataRevisionProvider.notifier).changed();
      state = OperationState(
        busy: {...state.busy}..remove(key),
        errors: {...state.errors}..remove(key),
      );
      return true;
    } catch (e) {
      state = OperationState(
        busy: {...state.busy}..remove(key),
        errors: {...state.errors, key: e},
      );
      return false;
    }
  }
}
