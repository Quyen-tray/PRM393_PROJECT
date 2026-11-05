import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrm_coffee_shop_flutter/features/workspace/presentation/module_page.dart';
import 'package:hrm_coffee_shop_flutter/app/router/module_registry.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/data/session_controller.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_providers.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';
import '../../support/test_support.dart';

class ReviewRepository extends ResourceRepository {
  ReviewRepository(super.api);
  final queries = <Json>[];
  @override
  Future<dynamic> read(String path, [Json query = const {}]) async {
    queries.add(query);
    return {
      'items': [
        {
          'requestId': 1,
          'requestType':
              query['status'] == '' ? 'Đơn đã duyệt' : 'Đơn đang chờ',
          'status': query['status'] == '' ? 'APPROVED' : 'PENDING'
        }
      ],
      'page': 0,
      'totalPages': 1,
      'totalElements': 1
    };
  }
}

void main() {
  for (final key in ['explanations', 'overtime']) {
    testWidgets('$key All filter explicitly clears the pending default',
        (tester) async {
      late ReviewRepository repository;
      final container = ProviderContainer(overrides: [
        sessionProvider.overrideWith(() => FixedSession(const SessionState(
            user: CurrentUser(
                id: 2,
                name: 'Manager',
                email: 'm@test',
                roles: {'STORE_MANAGER'},
                permissions: {}),
            workspace: Workspace.manager))),
        resourceRepositoryProvider.overrideWith((ref) =>
            repository = ReviewRepository(ref.read(authenticatedApiProvider))),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: Scaffold(body: ModulePage(module(key))))));
      await tester.pumpAndSettle();
      expect(repository.queries.last['status'], 'PENDING');
      await tester.tap(find.text('Bộ lọc và sắp xếp'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tất cả'));
      await tester.pumpAndSettle();
      expect(repository.queries.last.containsKey('status'), true);
      expect(repository.queries.last['status'], '');
      expect(tester.takeException(), isNull);
    });
  }
}
