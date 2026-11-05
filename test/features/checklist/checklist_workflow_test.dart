import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_coffee_shop_flutter/app/router/module_registry.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_providers.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/data/session_controller.dart';
import 'package:hrm_coffee_shop_flutter/features/workspace/presentation/record_actions.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';
import '../../support/resource_fixtures.dart';
import '../../support/test_support.dart';

void main() {
  testWidgets(
      'Cleaning work explains redo and enables submission only after required evidence is ready',
      (tester) async {
    final container = ProviderContainer(overrides: [
      sessionProvider.overrideWith(() => FixedSession(const SessionState(
          user: employeeUser, workspace: Workspace.employee))),
      resourceRepositoryProvider.overrideWith(
          (ref) => FixtureRepository(ref.read(authenticatedApiProvider))),
    ]);
    addTearDown(container.dispose);
    Widget screen({required bool complete, required bool evidence}) =>
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
              home: Scaffold(
                  body: SingleChildScrollView(
                      child: RecordActions(
            spec: module('my-checklists'),
            row: {
              'taskId': 10,
              'employeeId': 12,
              'status': 'IN_PROGRESS',
              'managerStatus': 'REJECTED',
              'reviewNote': 'Quầy chưa sạch',
              'items': [
                {
                  'runItemId': 20,
                  'itemName': 'Lau quầy',
                  'isRequired': true,
                  'requiresEvidence': true,
                  'isCompleted': complete,
                  'hasEvidence': evidence,
                }
              ],
            },
          )))),
        );
    await tester.pumpWidget(screen(complete: false, evidence: false));
    await tester.pumpAndSettle();
    expect(find.textContaining('Quầy chưa sạch'), findsOneWidget);
    expect(find.text('Đã hoàn thành 0/1 mục'), findsOneWidget);
    expect(find.text('Gửi checklist để duyệt'), findsNothing);
    await tester.pumpWidget(screen(complete: true, evidence: false));
    await tester.pumpAndSettle();
    expect(find.text('Gửi checklist để duyệt'), findsNothing);
    await tester.pumpWidget(screen(complete: true, evidence: true));
    await tester.pumpAndSettle();
    expect(find.text('Gửi checklist để duyệt'), findsOneWidget);
    expect(find.text('Đã hoàn thành 1/1 mục'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
