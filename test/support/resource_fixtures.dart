import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';

class FixtureRepository extends ResourceRepository {
  FixtureRepository(super.api);
  @override
  Future<dynamic> read(String path, [Json query = const {}]) async =>
      switch (path) {
        '/attendance/me/current' => {
            'shiftAssignmentId': 20,
            'shiftName': 'Ca hôm nay',
            'plannedStartAt': '2026-11-04T08:00:00+07:00',
            'plannedEndAt': '2026-11-04T16:00:00+07:00',
            'canCheckIn': false,
            'canCheckOut': false,
            'blockers': ['DEVICE_NOT_ACTIVE'],
          },
        '/attendance/devices/current' => null,
        '/stores/current' => {
            'name': 'Coffee test',
            'latitude': 21.0,
            'longitude': 105.0,
            'attendanceRadiusMeters': 100,
          },
        '/dashboard/employee/overview' => {
            'profileStatus': 'COMPLETE',
            'shiftEligibility': 'ELIGIBLE',
          },
        '/notifications/me/unread-count' => {'unreadCount': 0},
        '/dashboard/tasks' => {'pending': {}},
        _ => <dynamic>[],
      };
}

class RecordingRepository extends FixtureRepository {
  RecordingRepository(super.api);
  final List<Json> writes = [];
  @override
  Future<dynamic> write(String method, String path, [Object? body]) async {
    writes.add({'method': method, 'path': path, 'body': body});
    return null;
  }
}
