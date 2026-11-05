import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hrm_coffee_shop_flutter/app/app.dart';
import 'package:hrm_coffee_shop_flutter/core/network/api_providers.dart';
import 'package:hrm_coffee_shop_flutter/features/auth/data/session_controller.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';
import '../../support/resource_fixtures.dart';
import '../../support/test_support.dart';

class ManagerRepository extends FixtureRepository {
  ManagerRepository(super.api);
  final paths = <String>[];
  @override
  Future<dynamic> read(String path, [Json query = const {}]) async {
    paths.add(path);
    return switch (path) {
      '/dashboard/manager/overview' => {
          'attendanceToday': {
            'scheduledShifts': 8,
            'checkedInOnTime': 4,
            'late': 2,
            'absent': 1,
            'missingCheckOuts': 1
          }
        },
      '/dashboard/manager/employee-status' => {
          'profileStatus': {'COMPLETE': 3, 'INCOMPLETE': 2},
          'trainingStatus': {'COMPLETE': 2, 'MISSING': 3},
          'skillAssessmentStatus': {'ASSESSED': 4, 'NOT_ASSESSED': 1},
        },
      '/dashboard/manager/operations' => {
          'totalChecklists': 4,
          'byStatus': {'APPROVED': 2, 'SUBMITTED': 1, 'REJECTED': 1},
          'completionRatePercent': 50
        },
      '/dashboard/manager/attendance' => {
          'checkedInOnTime': 12,
          'late': 3,
          'absent': 1,
          'lateMinutesTotal': 25
        },
      '/dashboard/manager/rewards-penalties' => {
          'approvedRewards': 2,
          'approvedPenalties': 1,
          'pendingDecisions': 1,
          'rewardTotal': 200000,
          'penaltyTotal': 50000
        },
      _ => super.read(path, query),
    };
  }
}

void main() {
  for (final rewardPermission in [true, false]) {
    testWidgets(
        'Manager charts use API values, respect reward permission and link back to attendance ($rewardPermission)',
        (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late ManagerRepository repository;
      final container = ProviderContainer(overrides: [
        sessionProvider.overrideWith(() => FixedSession(SessionState(
            user: CurrentUser(
                id: 2,
                name: 'Quản lý',
                email: 'manager@test',
                roles: const {
                  'STORE_MANAGER'
                },
                permissions: {
                  'DASHBOARD_MANAGER',
                  'EMPLOYEE_VIEW',
                  'ATTENDANCE_VIEW_ALL',
                  'CHECKLIST_VIEW',
                  if (rewardPermission) 'REWARD_VIEW'
                }),
            workspace: Workspace.manager))),
        resourceRepositoryProvider.overrideWith((ref) =>
            repository = ManagerRepository(ref.read(authenticatedApiProvider))),
      ]);
      addTearDown(container.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container, child: const BeanHubApp()));
      await tester.pumpAndSettle();
      expect(find.text('Đào tạo bắt buộc'), findsOneWidget);
      expect(find.text('Đánh giá kỹ năng'), findsOneWidget);
      expect(find.text('25 phút đi muộn'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsWidgets);
      expect(repository.paths.contains('/dashboard/manager/rewards-penalties'),
          rewardPermission);
      expect(find.text('Thưởng và phạt trong tháng'),
          rewardPermission ? findsOneWidget : findsNothing);
      final details = find.byTooltip('Xem chi tiết Tình hình chấm công');
      await tester.ensureVisible(details);
      await tester.tap(details);
      await tester.pumpAndSettle();
      expect(repository.paths, contains('/attendance'));
      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();
      expect(find.text('Tình hình chấm công'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
