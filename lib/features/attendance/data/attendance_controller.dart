import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_providers.dart';
import '../../../core/storage/session_store.dart';
import '../../auth/data/session_controller.dart';
import '../../operations/data/operations_repository.dart';

class AttendanceState {
  const AttendanceState(
      {this.shift,
      this.store,
      this.device,
      this.position,
      this.photo,
      this.pending,
      this.busy = false,
      this.message,
      this.error});
  final Json? shift, store, device, pending;
  final Position? position;
  final Uint8List? photo;
  final bool busy;
  final String? message;
  final Object? error;
  bool get checkout =>
      shift?['attendanceId'] != null &&
      shift?['attendanceStatus'] == 'CHECKED_IN';
}

final attendanceControllerProvider =
    AsyncNotifierProvider.autoDispose<AttendanceController, AttendanceState>(
        AttendanceController.new);

class AttendanceController extends AsyncNotifier<AttendanceState> {
  @override
  Future<AttendanceState> build() async {
    ref.watch(dataRevisionProvider);
    final api = ref.watch(operationsRepositoryProvider);
    final result = await Future.wait([
      api.read('/attendance/me/current'),
      api.read('/stores/current'),
      api.read('/attendance/devices/current')
    ]);
    final userId = ref.read(sessionProvider).user!.id;
    final stored =
        await ref.read(sessionStoreProvider).read('attendance-pending-$userId');
    return AttendanceState(
        shift: result[0] == null ? null : json(result[0]),
        store: json(result[1]),
        device: result[2] == null ? null : json(result[2]),
        pending: stored == null ? null : json(jsonDecode(stored)));
  }

  void setPhoto(Uint8List photo) {
    final old = state.asData?.value;
    if (old == null) return;
    state = AsyncData(AttendanceState(
        shift: old.shift,
        store: old.store,
        device: old.device,
        position: old.position,
        photo: photo,
        pending: old.pending));
  }

  Future<void> locate() async {
    final old = state.asData?.value;
    if (old == null || old.busy) return;
    state = AsyncData(AttendanceState(
        shift: old.shift,
        store: old.store,
        device: old.device,
        photo: old.photo,
        pending: old.pending,
        busy: true));
    try {
      final position = await actualLocation();
      state = AsyncData(AttendanceState(
          shift: old.shift,
          store: old.store,
          device: old.device,
          photo: old.photo,
          pending: old.pending,
          position: position));
    } catch (e) {
      state = AsyncData(AttendanceState(
          shift: old.shift,
          store: old.store,
          device: old.device,
          photo: old.photo,
          pending: old.pending,
          error: e));
    }
  }

  Future<void> submit({bool retry = false}) async {
    final old = state.asData?.value;
    if (old == null || old.busy) return;
    final userId = ref.read(sessionProvider).user!.id;
    final storage = ref.read(sessionStoreProvider);
    final api = ref.read(authenticatedApiProvider);
    Json? pending = old.pending;
    state = AsyncData(AttendanceState(
        shift: old.shift,
        store: old.store,
        device: old.device,
        photo: old.photo,
        position: old.position,
        pending: pending,
        busy: true));
    try {
      if (!retry || pending == null) {
        if (old.shift == null || old.device?['status'] != 'ACTIVE') {
          throw const ApiException(
              message:
                  'Ca hoặc thiết bị chưa sẵn sàng. Hãy tải lại thông tin.');
        }
        if (old.photo == null) {
          throw const ApiException(
              message: 'Cần chụp ảnh trước khi chấm công.');
        }
        // Measure just before submitting, so a slow upload cannot make the GPS sample stale.
        final photoKey =
            await api.upload(old.photo!, 'image/jpeg', 'ATTENDANCE');
        final p = await actualLocation();
        final checkout = old.shift!['canCheckOut'] == true;
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
            'capturedAt': p.timestamp.toUtc().toIso8601String()
          },
          'photoEvidence': {
            'storageKey': photoKey,
            'cameraPermissionGranted': true
          },
          'idempotencyKey': randomKey()
        };
        pending = {
          'path': checkout ? '/attendance/check-out' : '/attendance/check-in',
          'body': body
        };
        await storage.write('attendance-pending-$userId', jsonEncode(pending));
      }
      final body = json(pending['body']);
      await api.data('POST', pending['path'] as String,
          body: body, headers: {'Idempotency-Key': body['idempotencyKey']});
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
            .read(operationsRepositoryProvider)
            .read('/attendance/me/current');
      } catch (error) {
        reloadError = error;
      }
      state = AsyncData(AttendanceState(
          shift: current == null ? null : json(current),
          store: old.store,
          device: old.device,
          message: message,
          error: reloadError));
      ref.read(dataRevisionProvider.notifier).changed();
    } catch (e) {
      // Definitive validation/state failures permit a new capture; ambiguous network failures retain the exact operation.
      if (e is ApiException &&
          [400, 403, 404, 409, 422].contains(e.statusCode)) {
        await storage.delete('attendance-pending-$userId');
        pending = null;
      }
      state = AsyncData(AttendanceState(
          shift: old.shift,
          store: old.store,
          device: old.device,
          photo: old.photo,
          position: old.position,
          pending: pending,
          error: e));
    }
  }
}

Future<Position> actualLocation() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const ApiException(
        message:
            'GPS đang tắt. Hãy bật dịch vụ vị trí trong cài đặt thiết bị.');
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.deniedForever) {
    throw const ApiException(
        message:
            'Quyền vị trí đã bị tắt. Mở cài đặt ứng dụng để cấp lại quyền.');
  }
  if (permission == LocationPermission.denied) {
    throw const ApiException(
        message: 'Cần quyền vị trí để kiểm tra khoảng cách tới cửa hàng.');
  }
  return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 25)));
}
