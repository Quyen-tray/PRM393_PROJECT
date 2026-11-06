import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_coffee_shop_flutter/app/router/module_registry.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_providers.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/data/session_controller.dart';
import 'package:hrm_coffee_shop_flutter/features/workspace/presentation/module_page.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';
import '../../support/resource_fixtures.dart';
import '../../support/test_support.dart';

class ScheduleRepository extends FixtureRepository {
  ScheduleRepository(super.api, {required this.paged}) {
    final today = DateUtils.dateOnly(DateTime.now());
    final monday = today.subtract(Duration(days: today.weekday - 1));
    rows = List.generate(21, (i) {
      final start = monday.add(Duration(days: i ~/ 3, hours: 7 + i % 3));
      return {
        // IDs intentionally run opposite to work dates.
        'assignmentId': 100 - i,
        'employeeName': 'Lịch ${100 - i}',
        'workDate': start.toIso8601String().substring(0, 10),
        'plannedStartAt': start.toIso8601String(),
        'plannedEndAt': start.add(const Duration(hours: 2)).toIso8601String(),
        'workShift': {'shiftName': 'Ca làm'},
        'status': 'PUBLISHED',
      };
    });
  }
  final bool paged;
  late final List<Json> rows;
  final queries = <Json>[];

  @override
  Future<dynamic> read(String path, [Json query = const {}]) async {
    if (!path.startsWith('/shift-assignments')) return super.read(path, query);
    queries.add({...query});
    if (!paged) return rows;
    final sorted =
        query['sort'] == 'plannedStartAt,desc' ? rows.reversed.toList() : rows;
    final size = query['size'] as int;
    return {
      'items': sorted.take(size).toList(),
      'page': 0,
      'totalPages': 2,
      'totalElements': rows.length,
    };
  }
}

void main() {
  for (final key in ['my-schedule', 'assignments']) {
    testWidgets(
        '$key defaults to newest dates before pagination and can switch to oldest',
        (tester) async {
      tester.view.physicalSize = const Size(850, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late ScheduleRepository repository;
      final container = ProviderContainer(overrides: [
        sessionProvider.overrideWith(() => FixedSession(const SessionState(
              user: CurrentUser(
                  id: 1,
                  name: 'Manager',
                  email: 'manager@test',
                  roles: {'STORE_MANAGER', 'EMPLOYEE'},
                  permissions: {},
                  employeeId: 12),
              workspace: Workspace.manager,
            ))),
        resourceRepositoryProvider.overrideWith((ref) => repository =
            ScheduleRepository(ref.read(authenticatedApiProvider),
                paged: key == 'assignments')),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: Scaffold(body: ModulePage(module(key))))));
      await tester.pumpAndSettle();
      List<String> visibleRows() => tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((tile) => tile.title)
          .whereType<Text>()
          .map((text) => text.data ?? '')
          .where((title) => title.startsWith('Lịch '))
          .toList();
      expect(repository.queries.last['sort'], 'plannedStartAt,desc');
      expect(visibleRows(), [for (int id = 80; id < 100; id++) 'Lịch $id']);
      await tester.tap(find.text('Bộ lọc và sắp xếp'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mới nhất trước'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cũ nhất trước').last);
      await tester.pumpAndSettle();
      expect(repository.queries.last['sort'], 'plannedStartAt,asc');
      expect(visibleRows(), [for (int id = 100; id > 80; id--) 'Lịch $id']);
      expect(tester.takeException(), isNull);
    });
  }
}
