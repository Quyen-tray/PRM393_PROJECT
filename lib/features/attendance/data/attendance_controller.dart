import 'package:hrm_coffee_shop_flutter/core/location/location_service.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_providers.dart';
import '../../../core/storage/session_store.dart';
import '../../auth/data/session_controller.dart';
import 'package:hrm_coffee_shop_flutter/shared/resources/data/resource_repository.dart';

class AttendanceState {
  const AttendanceState({
    this.shift,
    this.store,
    this.device,
    this.position,
    this.photo,
    this.pending,
    this.busy = false,
    this.message,
    this.error,
  });
  final Json? shift, store, device, pending;
  final Position? position;
  final Uint8List? photo;
  final bool busy;
  final String? message;
  final Object? error;
  bool get photoRequired => shift?['photoRequired'] != false;
  bool get finished =>
      ['CHECKED_OUT', 'FINALIZED'].contains(shift?['attendanceStatus']);
  List<Json> get shiftChoices =>
      ResourcePage.parse(shift?['shiftChoices']).items;
  bool get checkout =>
      shift?['attendanceId'] != null &&
      !['CHECKED_OUT', 'FINALIZED'].contains(shift?['attendanceStatus']);
}

class AttendanceSelection extends Notifier<int?> {
  @override
  int? build() {
    ref.watch(sessionProvider.select((session) => session.user?.id));
    return null;
  }

  void select(int? id) => state = id;
}

final selectedAttendanceAssignmentProvider =
    NotifierProvider<AttendanceSelection, int?>(AttendanceSelection.new);

final attendanceControllerProvider =
    AsyncNotifierProvider.autoDispose<AttendanceController, AttendanceState>(
  AttendanceController.new,
);

class AttendanceController extends AsyncNotifier<AttendanceState> {
  int? _lastAssignmentId;
  bool _refreshingStatus = false;
  Json get _selectionQuery => {
        if (ref.read(selectedAttendanceAssignmentProvider) != null)
          'assignmentId': ref.read(selectedAttendanceAssignmentProvider),
      };

  Future<List<dynamic>> _fetchStatus() {
    final api = ref.read(resourceRepositoryProvider);
    return Future.wait([
      api.read('/attendance/me/current', _selectionQuery),
      api.read('/stores/current'),
      api.read('/attendance/devices/current'),
    ]);
  }

  Future<void> refreshStatus() async {
    final old = state.asData?.value;
    if (old == null || old.busy || _refreshingStatus) return;
    final selection = ref.read(selectedAttendanceAssignmentProvider);
    _refreshingStatus = true;
    try {
      final result = await _fetchStatus();
      if (!ref.mounted ||
          selection != ref.read(selectedAttendanceAssignmentProvider)) {
        return;
      }
      final latest = state.asData?.value;
      if (latest == null || latest.busy) return;
      final shift = result[0] == null ? null : json(result[0]);
      final sameEvent =
          shift?['shiftAssignmentId'] == latest.shift?['shiftAssignmentId'] &&
              shift?['attendanceStatus'] == latest.shift?['attendanceStatus'];
      state = AsyncData(AttendanceState(
        shift: shift,
        store: json(result[1]),
        device: result[2] == null ? null : json(result[2]),
        photo: sameEvent ? latest.photo : null,
        position: latest.position,
        pending: latest.pending,
        message: latest.message,
        error: latest.error,
      ));
    } catch (_) {
      // Keep the capture and retry operation intact during background refresh.
    } finally {
      _refreshingStatus = false;
    }
  }

  @override
  Future<AttendanceState> build() async {
    final selection = ref.watch(selectedAttendanceAssignmentProvider);
    final message =
        _lastAssignmentId == selection ? state.asData?.value.message : null;
    _lastAssignmentId = selection;
    ref.watch(dataRevisionProvider);
    final api = ref.watch(resourceRepositoryProvider);
    final result = await Future.wait([
      api.read('/attendance/me/current', _selectionQuery),
      api.read('/stores/current'),
      api.read('/attendance/devices/current'),
    ]);
    final userId = ref.read(sessionProvider).user!.id;
    final stored =
        await ref.read(sessionStoreProvider).read('attendance-pending-$userId');
    return AttendanceState(
      shift: result[0] == null ? null : json(result[0]),
      store: json(result[1]),
      device: result[2] == null ? null : json(result[2]),
      pending: stored == null ? null : json(jsonDecode(stored)),
      message: message,
    );
  }

  void selectAssignment(int id) {
    final current = state.asData?.value;
    if (current?.busy == true || current?.pending != null) return;
    ref.read(selectedAttendanceAssignmentProvider.notifier).select(id);
  }

  void setPhoto(Uint8List photo) {
    final old = state.asData?.value;
    if (old == null) return;
    state = AsyncData(
      AttendanceState(
        shift: old.shift,
        store: old.store,
        device: old.device,
        position: old.position,
        photo: photo,
        pending: old.pending,
      ),
    );
  }

  Future<void> locate() async {
    final old = state.asData?.value;
    if (old == null || old.busy) return;
    state = AsyncData(
      AttendanceState(
        shift: old.shift,
        store: old.store,
        device: old.device,
        photo: old.photo,
        pending: old.pending,
        busy: true,
      ),
    );
    try {
      final position = await ref.read(locationProvider)();
      state = AsyncData(
        AttendanceState(
          shift: old.shift,
          store: old.store,
          device: old.device,
          photo: old.photo,
          pending: old.pending,
          position: position,
        ),
      );
    } catch (e) {
      state = AsyncData(
        AttendanceState(
          shift: old.shift,
          store: old.store,
          device: old.device,
          photo: old.photo,
          pending: old.pending,
          error: e,
        ),
      );
    }
  }

  Future<void> submit({bool retry = false}) async {
    final old = state.asData?.value;
    if (old == null || old.busy) return;
    if (old.pending != null && !retry) return;
    final userId = ref.read(sessionProvider).user!.id;
    final storage = ref.read(sessionStoreProvider);
    final api = ref.read(authenticatedApiProvider);
    Json? pending = old.pending;
    state = AsyncData(
      AttendanceState(
        shift: old.shift,
        store: old.store,
        device: old.device,
        photo: old.photo,
        position: old.position,
        pending: pending,
        busy: true,
      ),
    );
    try {
      if (!retry || pending == null) {
        if (old.shift == null || old.device?['status'] != 'ACTIVE') {
          throw const ApiException(
            message: 'Ca hoặc thiết bị chưa sẵn sàng. Hãy tải lại thông tin.',
          );
        }
        if (old.photoRequired && old.photo == null) {
          throw const ApiException(
            message: 'Cần chụp ảnh trước khi chấm công.',
          );
        }
        // Measure just before submitting, so a slow upload cannot make the GPS sample stale.
        final photoKey = old.photo == null
            ? null
            : await api.upload(
                old.photo!,
                'image/jpeg',
                'ATTENDANCE',
              );
        final p = await ref.read(locationProvider)();
        if (p.isMocked && old.shift?['mockLocationsAllowed'] == false) {
          throw const ApiException(
              code: 'GPS_MOCKED',
              message:
                  'Vị trí đang được giả lập. Hãy tắt giả lập vị trí hoặc gửi giải trình.');
        }
        final checkout = old.checkout;
        final body = <String, dynamic>{
          if (checkout)
            'attendanceId': old.shift!['attendanceId']
          else
            'shiftAssignmentId': old.shift!['shiftAssignmentId'],
          'deviceId': old.device!['deviceId'],
          'location': {
            'latitude': p.latitude,
            'longitude': p.longitude,
            'accuracyMeters': p.accuracy,
            'capturedAt': p.timestamp.toUtc().toIso8601String(),
            'isMocked': p.isMocked,
          },
          if (photoKey != null)
            'photoEvidence': {
              'storageKey': photoKey,
              'cameraPermissionGranted': true,
            },
          'idempotencyKey': randomKey(),
        };
        pending = {
          'path': checkout ? '/attendance/check-out' : '/attendance/check-in',
          'body': body,
        };
        await storage.write('attendance-pending-$userId', jsonEncode(pending));
      }
      final body = json(pending['body']);
      await api.data(
        'POST',
        pending['path'] as String,
        body: body,
        headers: {'Idempotency-Key': body['idempotencyKey']},
      );
      await storage.delete('attendance-pending-$userId');
      // Backend confirmation is the only success condition.
      final message = pending['path'] == '/attendance/check-in'
          ? 'Đã check-in thành công.'
          : 'Đã check-out thành công.';
      pending = null;
      Object? reloadError;
      dynamic current;
      try {
        current = await ref
            .read(resourceRepositoryProvider)
            .read('/attendance/me/current', _selectionQuery);
      } catch (error) {
        reloadError = error;
      }
      state = AsyncData(
        AttendanceState(
          shift: current == null ? null : json(current),
          store: old.store,
          device: old.device,
          message: message,
          error: reloadError,
        ),
      );
      ref.read(dataRevisionProvider.notifier).changed();
    } catch (e) {
      // Definitive validation/state failures permit a new capture; ambiguous network failures retain the exact operation.
      if (e is ApiException &&
          ([400, 403, 404, 409, 422].contains(e.statusCode) ||
              e.code == 'FACE_VERIFICATION_UNAVAILABLE')) {
        await storage.delete('attendance-pending-$userId');
        pending = null;
      }
      if (e is ApiException &&
          ['ATTENDANCE_ALREADY_CHECKED_IN', 'ATTENDANCE_ALREADY_CHECKED_OUT']
              .contains(e.code)) {
        try {
          final result = await _fetchStatus();
          if (!ref.mounted) return;
          state = AsyncData(AttendanceState(
            shift: result[0] == null ? null : json(result[0]),
            store: json(result[1]),
            device: result[2] == null ? null : json(result[2]),
            message: e.code == 'ATTENDANCE_ALREADY_CHECKED_IN'
                ? 'Ca này đã check-in. Có thể tiếp tục check-out.'
                : 'Ca này đã check-out.',
          ));
          return;
        } catch (_) {
          /* Show the original response if status reload is unavailable. */
        }
      }
      state = AsyncData(
        AttendanceState(
          shift: old.shift,
          store: old.store,
          device: old.device,
          photo: old.photo,
          position: old.position,
          pending: pending,
          error: e,
        ),
      );
    }
  }
}
