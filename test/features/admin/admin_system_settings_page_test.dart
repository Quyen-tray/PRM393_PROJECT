import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hrm_coffee_shop_flutter/data/repositories/employee_providers.dart';
import 'package:hrm_coffee_shop_flutter/data/repositories/employee_repository.dart';
import 'package:hrm_coffee_shop_flutter/features/admin/presentation/admin_system_settings_page.dart';

void main() {
  final originalGeolocator = GeolocatorPlatform.instance;

  tearDown(() {
    GeolocatorPlatform.instance = originalGeolocator;
  });

  testWidgets('admin captures GPS and saves store coordinates', (tester) async {
    GeolocatorPlatform.instance = _GpsGeolocator();
    final repository = _SettingsRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [employeeRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: AdminSystemSettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('GPS và bán kính chấm công'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lấy GPS hiện tại'));
    await tester.pumpAndSettle();

    expect(find.text('Độ chính xác GPS: ±8 m'), findsOneWidget);
    final fields = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .toList();
    expect(fields.first.controller!.text, '10.7800000');
    expect(fields[1].controller!.text, '106.7100000');

    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();

    expect(repository.savedChanges, {'latitude': 10.78, 'longitude': 106.71});
    expect(find.textContaining('Tọa độ 10.780000, 106.710000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _GpsGeolocator extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.denied;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => Position.fromMap({
    'latitude': 10.78,
    'longitude': 106.71,
    'accuracy': 8.0,
    'altitude': 0.0,
    'altitude_accuracy': 1.0,
    'heading': 0.0,
    'heading_accuracy': 1.0,
    'speed': 0.0,
    'speed_accuracy': 0.0,
  });
}

class _SettingsRepository implements EmployeeRepository {
  Map<String, dynamic> settings = {
    'store': {
      'name': 'HRM Coffee Shop',
      'address': 'Hồ Chí Minh',
      'latitude': 10.7769,
      'longitude': 106.7009,
    },
    'attendanceRadiusMeters': 50,
    'gpsMaxAccuracyMeters': 50,
  };
  Map<String, dynamic>? savedChanges;

  @override
  Future<Map<String, dynamic>> getStoreSettings() async => settings;

  @override
  Future<List<Map<String, dynamic>>> getReminderRules() async => [];

  @override
  Future<Map<String, dynamic>> getAttendancePolicies() async => settings;

  @override
  Future<Map<String, dynamic>> updateStoreSettings(
    Map<String, dynamic> changes,
  ) async {
    savedChanges = Map<String, dynamic>.from(changes);
    settings = {
      ...settings,
      'store': {
        ...Map<String, dynamic>.from(settings['store'] as Map),
        ...changes,
      },
    };
    return settings;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
