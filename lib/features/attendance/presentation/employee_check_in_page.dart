import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:camera/camera.dart' show CameraLensDirection;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/repositories/employee_providers.dart';
import '../../../shared/presentation/camera_capture_page.dart';

/// Chấm công check-in/check-out. Giao diện theo bản gốc; dữ liệu, thiết bị và
/// kiểm tra điều kiện lấy từ API. Ngưỡng sai số GPS (`gpsMaxAccuracyMeters` của
/// `/stores/current`) dùng để cảnh báo trước; máy chủ vẫn là nơi quyết định khi check-in.
class EmployeeCheckInPage extends ConsumerStatefulWidget {
  const EmployeeCheckInPage({super.key});

  @override
  ConsumerState<EmployeeCheckInPage> createState() =>
      _EmployeeCheckInPageState();
}

class _EmployeeCheckInPageState extends ConsumerState<EmployeeCheckInPage>
    with WidgetsBindingObserver {
  Timer? _refreshTimer;
  bool _refreshing = false;
  Position? _position;
  Uint8List? _photoBytes;
  Map<String, dynamic>? _shift;
  Map<String, dynamic>? _store;
  List<Map<String, dynamic>> _devices = [];
  bool _loading = true;
  bool _loadingLocation = false;
  bool _loadingPhoto = false;
  bool _submitting = false;
  bool _registeringDevice = false;
  String? _error;
  String? _pendingIdempotencyKey;
  String? _pendingIdempotencyScope;

  /// Lỗi lấy GPS, tách riêng để việc cập nhật vị trí không xóa lỗi tải dữ liệu (`_error`).
  String? _locationError;

  Map<String, dynamic>? get _activeDevice {
    for (final device in _devices) {
      if (device['status'] == 'ACTIVE') return device;
    }
    return null;
  }

  Map<String, dynamic>? get _pendingDevice {
    for (final device in _devices) {
      if (device['status'] == 'PENDING') return device;
    }
    return null;
  }

  bool get _isCheckOut => _shift?['canCheckOut'] == true;
  bool get _canCheckIn => _shift?['canCheckIn'] == true;
  int? _asInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value');

  double? get _radiusMeters =>
      (_store?['attendanceRadiusMeters'] as num?)?.toDouble();

  /// Sai số GPS tối đa máy chủ chấp nhận khi chấm công (mét).
  double? get _maxAccuracyMeters =>
      (_store?['gpsMaxAccuracyMeters'] as num?)?.toDouble();

  bool get _accuracyTooLoose {
    final accuracy = _position?.accuracy;
    final limit = _maxAccuracyMeters;
    return accuracy != null && limit != null && accuracy > limit;
  }

  double? get _distanceMeters {
    final position = _position;
    final latitude = (_store?['latitude'] as num?)?.toDouble();
    final longitude = (_store?['longitude'] as num?)?.toDouble();
    if (position == null || latitude == null || longitude == null) return null;
    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      latitude,
      longitude,
    );
  }

  bool get _withinRadius {
    final distance = _distanceMeters;
    final radius = _radiusMeters;
    return distance != null && radius != null && distance <= radius;
  }

  String get _locationMessage {
    final position = _position;
    final distance = _distanceMeters;
    if (_loadingLocation) return 'Đang xác định vị trí GPS...';
    if (position == null) return 'Chưa lấy được vị trí GPS';
    if (distance == null) return 'Chưa xác định được khoảng cách tới cửa hàng';
    if (_withinRadius) {
      return 'Trong khu vực cửa hàng (${distance.toStringAsFixed(0)} m)';
    }
    return 'Ngoài bán kính cửa hàng (${distance.toStringAsFixed(0)} m)';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted &&
          !_loading &&
          !_submitting &&
          !_loadingPhoto &&
          !_registeringDevice &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        unawaited(_load(silent: true));
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Tải ca làm trước, rồi mới lấy GPS, để việc lấy GPS không xoá lỗi tải dữ liệu.
      unawaited(_load().then((_) => _refreshLocation()));
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        mounted &&
        !_submitting &&
        !_loadingPhoto &&
        !_registeringDevice) {
      unawaited(_load(silent: true));
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    setState(() {
      if (!silent) {
        _loading = true;
        _error = null;
      }
    });
    try {
      final repository = ref.read(employeeRepositoryProvider);
      final values = await Future.wait<Object?>([
        repository.getCurrentShift(),
        repository.getMyAttendanceDevices(),
        repository.getCurrentStore(),
      ]);
      if (!mounted) return;
      setState(() {
        _shift = values[0] as Map<String, dynamic>?;
        _devices = values[1] as List<Map<String, dynamic>>;
        _store = values[2] as Map<String, dynamic>?;
      });
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      _refreshing = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  String _message(Object error) => error is ApiException
      ? error.message
      : 'Không thể tải dữ liệu chấm công. Vui lòng thử lại.';

  Future<void> _registerDevice() async {
    if (kIsWeb) {
      setState(
        () => _error =
            'Đăng ký thiết bị chấm công chỉ hỗ trợ ứng dụng Android/iOS.',
      );
      return;
    }
    setState(() {
      _registeringDevice = true;
      _error = null;
    });
    try {
      final plugin = DeviceInfoPlugin();
      late String platform;
      late String fingerprint;
      late String label;
      if (defaultTargetPlatform == TargetPlatform.android) {
        final info = await plugin.androidInfo;
        platform = 'ANDROID';
        fingerprint = await ref
            .read(employeeRepositoryProvider)
            .getOrCreateAttendanceDeviceFingerprint();
        label = '${info.manufacturer} ${info.model}'.trim();
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final info = await plugin.iosInfo;
        platform = 'IOS';
        fingerprint = await ref
            .read(employeeRepositoryProvider)
            .getOrCreateAttendanceDeviceFingerprint();
        label = '${info.name} ${info.model}'.trim();
      } else {
        throw const FormatException(
          'Chỉ hỗ trợ đăng ký trên Android hoặc iOS.',
        );
      }
      if (fingerprint.length < 8) {
        throw const FormatException('Không đọc được mã định danh thiết bị.');
      }
      final registered = await ref
          .read(employeeRepositoryProvider)
          .registerAttendanceDevice(
            fingerprint: fingerprint,
            platform: platform,
            label: label.isEmpty ? platform : label,
          );
      await _load();
      if (mounted) {
        _show(
          registered['status'] == 'ACTIVE'
              ? 'Thiết bị này đã được duyệt.'
              : 'Đã gửi yêu cầu đăng ký thiết bị. Chờ quản lý phê duyệt.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _registeringDevice = false);
    }
  }

  Future<void> _refreshLocation() async {
    setState(() {
      _loadingLocation = true;
      _position = null;
      _locationError = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const FormatException(
          'Bật dịch vụ định vị của thiết bị rồi thử lại.',
        );
      }
      if (!kIsWeb) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.deniedForever) {
          throw const FormatException(
            'Quyền vị trí đã bị từ chối vĩnh viễn. Hãy cấp quyền trong cài đặt thiết bị.',
          );
        }
        if (permission == LocationPermission.denied) {
          throw const FormatException('Cần cấp quyền vị trí để chấm công.');
        }
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          // geolocator_web forwards this Duration to the browser API with an
          // incorrect unit conversion. Enforce the web timeout below instead.
          timeLimit: kIsWeb ? null : const Duration(seconds: 8),
        ),
      ).timeout(const Duration(seconds: 12));
      if (!mounted) return;
      setState(() => _position = position);
    } on TimeoutException {
      if (mounted) {
        setState(
          () => _locationError = kIsWeb
              ? 'Chrome chưa trả vị trí. Hãy cho phép vị trí cho trang web; nếu đang giả lập điện thoại, đặt vị trí trong DevTools > Sensors > Location rồi cập nhật lại.'
              : 'Điện thoại chưa trả vị trí. Hãy bật dịch vụ vị trí, cấp quyền cho ứng dụng rồi thử cập nhật ở nơi thoáng.',
        );
      }
    } on LocationServiceDisabledException {
      if (mounted) {
        setState(
          () => _locationError = 'Dịch vụ định vị đang tắt. Hãy bật GPS.',
        );
      }
    } on PermissionDeniedException {
      if (mounted) {
        setState(
          () => _locationError = kIsWeb
              ? 'Bạn cần cho phép vị trí cho trang web trong Chrome để check-in.'
              : 'Bạn cần cấp quyền vị trí cho ứng dụng trong cài đặt Android để check-in.',
        );
      }
    } on FormatException catch (error) {
      if (mounted) setState(() => _locationError = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _locationError = 'Không thể lấy GPS. Hãy thử cập nhật lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  Future<void> _capturePhoto() async {
    setState(() {
      _loadingPhoto = true;
      _error = null;
    });
    try {
      final photo = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(
          builder: (_) => const CameraCapturePage(
            preferredDirection: CameraLensDirection.front,
            title: 'Ảnh xác minh chấm công',
            instruction: 'Đưa khuôn mặt vào giữa khung hình rồi chụp.',
          ),
        ),
      );
      if (mounted && photo != null) setState(() => _photoBytes = photo);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Không thể mở camera để chụp ảnh. Hãy kiểm tra quyền camera.',
        );
      }
    } finally {
      if (mounted) setState(() => _loadingPhoto = false);
    }
  }

  String _idempotencyKey({required bool checkOut, required int targetId}) {
    final scope = '${checkOut ? 'checkout' : 'checkin'}:$targetId';
    if (_pendingIdempotencyKey == null || _pendingIdempotencyScope != scope) {
      _pendingIdempotencyScope = scope;
      _pendingIdempotencyKey =
          '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    }
    return _pendingIdempotencyKey!;
  }

  void _clearPendingIdempotencyKey() {
    _pendingIdempotencyKey = null;
    _pendingIdempotencyScope = null;
  }

  Future<void> _submit() async {
    final device = _activeDevice;
    final shiftId = _asInt(_shift?['shiftAssignmentId']);
    final attendanceId = _asInt(_shift?['attendanceId']);
    if (device == null) {
      setState(() => _error = 'Thiết bị chưa được quản lý phê duyệt.');
      return;
    }
    final photoBytes = _photoBytes;
    if (photoBytes == null) {
      setState(() => _error = 'Hãy chụp ảnh xác minh bằng camera.');
      return;
    }
    if (_isCheckOut && attendanceId == null) {
      setState(
        () => _error = 'Không tìm thấy mã bản ghi chấm công để check-out.',
      );
      return;
    }
    if (!_isCheckOut && (shiftId == null || !_canCheckIn)) {
      setState(
        () => _error =
            'Ca làm hiện tại chưa đủ điều kiện check-in. Hãy kiểm tra các điều kiện bên dưới.',
      );
      return;
    }
    final wasCheckOut = _isCheckOut;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      // Lấy lại vị trí ngay trước khi gửi để không dùng GPS đã cũ khi người
      // dùng chụp ảnh hoặc xem lại điều kiện chấm công.
      await _refreshLocation();
      if (!mounted) return;
      final position = _position;
      if (position == null) {
        setState(
          () => _error = _locationError ?? 'Hãy lấy vị trí GPS rồi thử lại.',
        );
        return;
      }
      if (!_withinRadius) {
        final radius = _radiusMeters;
        final radiusLabel = radius == null
            ? 'cho phép'
            : '${radius.toStringAsFixed(0)} m';
        setState(
          () => _error = 'Bạn đang ngoài bán kính $radiusLabel của cửa hàng.',
        );
        return;
      }
      if (_accuracyTooLoose) {
        setState(
          () => _error =
              'Sai số GPS quá lớn. Hãy cập nhật vị trí ở nơi thoáng rồi thử lại.',
        );
        return;
      }
      final repository = ref.read(employeeRepositoryProvider);
      final storageKey = await repository.uploadImage(
        bytes: photoBytes,
        purpose: 'ATTENDANCE',
      );
      final capturedAt = position.timestamp.toUtc().toIso8601String();
      if (wasCheckOut) {
        await repository.checkOut(
          attendanceId: attendanceId!,
          deviceId: _asInt(device['deviceId'])!,
          latitude: position.latitude,
          longitude: position.longitude,
          accuracyMeters: position.accuracy,
          capturedAt: capturedAt,
          photoStorageKey: storageKey,
          idempotencyKey: _idempotencyKey(
            checkOut: true,
            targetId: attendanceId,
          ),
        );
      } else {
        await repository.checkIn(
          shiftAssignmentId: shiftId!,
          deviceId: _asInt(device['deviceId'])!,
          latitude: position.latitude,
          longitude: position.longitude,
          accuracyMeters: position.accuracy,
          capturedAt: capturedAt,
          photoStorageKey: storageKey,
          idempotencyKey: _idempotencyKey(checkOut: false, targetId: shiftId),
        );
      }
      if (!mounted) return;
      _clearPendingIdempotencyKey();
      setState(() => _photoBytes = null);
      _show(wasCheckOut ? 'Check-out thành công.' : 'Check-in thành công.');
      context.go(RouteNames.employeeHome);
    } catch (error) {
      if (error is ApiException &&
          error.statusCode != null &&
          error.statusCode! < 500) {
        _clearPendingIdempotencyKey();
      }
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _show(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final device = _activeDevice;
    final pending = _pendingDevice;
    final shift = _shift;
    final blockers = _blockerLabelsOf(shift);
    final ruleAllows = _isCheckOut || _canCheckIn;
    final canSubmit =
        !_loading &&
        !_loadingLocation &&
        !_loadingPhoto &&
        !_submitting &&
        !_registeringDevice &&
        device != null &&
        shift != null &&
        ruleAllows &&
        _withinRadius &&
        !_accuracyTooLoose &&
        _photoBytes != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Quay lại',
          onPressed: () => context.go(RouteNames.employeeHome),
          icon: const Icon(Icons.arrow_back),
        ),
        centerTitle: true,
        title: Text(_isCheckOut ? 'Check-out' : 'Check-in'),
        actions: [
          IconButton(
            tooltip: 'Tải lại ca làm',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          children: [
                            _ShiftLabel(shift: shift),
                            if (shift != null && !ruleAllows)
                              const Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: Text(
                                  'Chưa đủ điều kiện chấm công theo quy tắc máy chủ.',
                                  style: TextStyle(
                                    color: AppColors.error,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            for (final label in blockers)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '• $label',
                                  style: const TextStyle(
                                    color: AppColors.error,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 14),
                            _DeviceCard(
                              activeDevice: device,
                              pendingDevice: pending,
                              registering: _registeringDevice,
                              onRegister: _registerDevice,
                            ),
                            const SizedBox(height: 14),
                            _LocationPreview(
                              accuracyMeters: _position?.accuracy,
                              accuracyLimitMeters: _maxAccuracyMeters,
                              accuracyTooLoose: _accuracyTooLoose,
                              isLoading: _loadingLocation,
                              hasGpsFix: _position != null,
                              isValid: _withinRadius,
                              statusMessage: _locationMessage,
                              coordinatesLabel: _position == null
                                  ? null
                                  : '${_position!.latitude.toStringAsFixed(6)}, '
                                        '${_position!.longitude.toStringAsFixed(6)}',
                              onRefresh: _refreshLocation,
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Text(
                                  'Ảnh xác minh',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const Spacer(),
                                const Text(
                                  'BẮT BUỘC',
                                  style: TextStyle(
                                    color: Color(0xFF946442),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 9),
                            _SelfiePreview(
                              photoBytes: _photoBytes,
                              isLoading: _loadingPhoto,
                              onCapture: _capturePhoto,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _photoBytes == null
                                  ? 'Chưa có ảnh. Hãy chụp trực tiếp bằng camera.'
                                  : 'Ảnh xác minh đã chụp trực tiếp.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                            if (_locationError != null) ...[
                              const SizedBox(height: 12),
                              _ErrorBanner(message: _locationError!),
                            ],
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              _ErrorBanner(message: _error!),
                            ],
                          ],
                        ),
                      ),
                      _CheckInFooter(
                        label: _isCheckOut
                            ? 'Xác nhận check-out'
                            : 'Xác nhận check-in',
                        canSubmit: canSubmit,
                        isSubmitting: _submitting,
                        hasLocation: _position != null,
                        hasPhoto: _photoBytes != null,
                        onSubmit: _submit,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

List<String> _blockerLabelsOf(Map<String, dynamic>? shift) {
  final blockers = shift?['blockers'];
  if (blockers is! List) return const [];
  return blockers.map((item) {
    if (item == 'CHECK_IN_TOO_EARLY') {
      return 'Check-in mở lúc ${formatTimeOfDay(shift?['checkInOpensAt'])} '
          'ngày ${formatDate(shift?['checkInOpensAt'])}.';
    }
    return _blockerLabel(item.toString());
  }).toList();
}

String _blockerLabel(String code) => switch (code) {
  'DEVICE_NOT_ACTIVE' => 'Thiết bị chưa được duyệt hoặc không còn hoạt động',
  'EMPLOYEE_NOT_ACTIVE' => 'Hồ sơ nhân viên chưa ở trạng thái đang làm việc.',
  'CHECK_IN_WINDOW_CLOSED' => 'Ca đã kết thúc. Hãy gửi giải trình chấm công.',
  'TRAINING_REQUIREMENT_NOT_MET' =>
    'Tiến độ đào tạo không chặn nhận ca; hãy tải lại trạng thái ca.',
  _ => code,
};

class _ShiftLabel extends StatelessWidget {
  const _ShiftLabel({required this.shift});

  final Map<String, dynamic>? shift;

  @override
  Widget build(BuildContext context) {
    final current = shift;
    if (current == null) {
      return const Row(
        children: [
          Icon(Icons.access_time, size: 17, color: AppColors.textSecondary),
          SizedBox(width: 7),
          Expanded(
            child: Text(
              'Hiện chưa có ca làm trong khung thời gian chấm công.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      );
    }
    final status = attendanceStatusLabel(
      current['attendanceStatus']?.toString(),
    );
    return Row(
      children: [
        const Icon(Icons.access_time, size: 17, color: AppColors.textSecondary),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            '${current['shiftName'] ?? 'Ca làm'} · '
            '${formatTimeOfDay(current['plannedStartAt'])} - ${formatTimeOfDay(current['plannedEndAt'])}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1D9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            status,
            style: const TextStyle(color: Color(0xFF946442), fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.activeDevice,
    required this.pendingDevice,
    required this.registering,
    required this.onRegister,
  });

  final Map<String, dynamic>? activeDevice;
  final Map<String, dynamic>? pendingDevice;
  final bool registering;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final approved = activeDevice;
    final pending = pendingDevice;
    final String message;
    final Color color;
    if (approved != null) {
      final label =
          approved['deviceLabel'] ?? approved['platform'] ?? 'Thiết bị';
      message = 'Đã duyệt: $label';
      color = AppColors.secondary;
    } else if (pending != null) {
      message = 'Yêu cầu đăng ký đang chờ quản lý phê duyệt.';
      color = const Color(0xFFB7791F);
    } else {
      message = 'Cần đăng ký và được quản lý phê duyệt trước khi chấm công.';
      color = AppColors.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9E6E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.phone_android_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Thiết bị chấm công',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          if (pending != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trạng thái yêu cầu ${approved == null ? 'đăng ký' : 'đổi máy'}: ${pending['status'] ?? 'PENDING'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (approved != null)
                    const Text(
                      'Thiết bị đang dùng vẫn hoạt động đến khi quản lý duyệt máy mới.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          if (pending == null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: registering ? null : onRegister,
              icon: registering
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.phonelink_setup),
              label: Text(
                approved == null
                    ? 'Đăng ký thiết bị này'
                    : 'Yêu cầu đổi thiết bị',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CheckInFooter extends StatelessWidget {
  const _CheckInFooter({
    required this.label,
    required this.canSubmit,
    required this.isSubmitting,
    required this.hasLocation,
    required this.hasPhoto,
    required this.onSubmit,
  });

  final String label;
  final bool canSubmit;
  final bool isSubmitting;
  final bool hasLocation;
  final bool hasPhoto;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE9E6E1))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _CheckStatus(label: 'GPS', isReady: hasLocation),
                const SizedBox(width: 18),
                _CheckStatus(label: 'Ảnh', isReady: hasPhoto),
              ],
            ),
            const SizedBox(height: 9),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF76503A),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFD6C7BB),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: canSubmit ? onSubmit : null,
                child: isSubmitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationPreview extends StatelessWidget {
  const _LocationPreview({
    required this.accuracyMeters,
    required this.accuracyLimitMeters,
    required this.accuracyTooLoose,
    required this.isLoading,
    required this.hasGpsFix,
    required this.isValid,
    required this.statusMessage,
    required this.coordinatesLabel,
    required this.onRefresh,
  });

  final double? accuracyMeters;
  final double? accuracyLimitMeters;
  final bool accuracyTooLoose;
  final bool isLoading;
  final bool hasGpsFix;
  final bool isValid;
  final String statusMessage;
  final String? coordinatesLabel;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final statusColor = isValid
        ? const Color(0xFF287A48)
        : isLoading || !hasGpsFix
        ? AppColors.textSecondary
        : AppColors.error;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 150,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const CustomPaint(painter: _MapPainter()),
                if (hasGpsFix)
                  Center(
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.16),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: Color(0xFF2586C2),
                        size: 27,
                      ),
                    ),
                  ),
                Positioned(
                  left: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.storefront_outlined,
                          size: 15,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'HRM Coffee Shop',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 9,
                  right: 9,
                  child: IconButton.filledTonal(
                    tooltip: 'Cập nhật vị trí',
                    onPressed: isLoading ? null : onRefresh,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.95),
                      foregroundColor: AppColors.textPrimary,
                      fixedSize: const Size(38, 38),
                    ),
                    icon: isLoading
                        ? const SizedBox.square(
                            dimension: 17,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location, size: 19),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Icon(
              isLoading
                  ? Icons.gps_not_fixed
                  : isValid
                  ? Icons.check_circle
                  : hasGpsFix
                  ? Icons.location_off
                  : Icons.gps_off,
              color: statusColor,
              size: 17,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                statusMessage,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              accuracyMeters == null
                  ? '±-- m'
                  : '±${accuracyMeters!.toStringAsFixed(0)} m',
              style: TextStyle(
                color: accuracyTooLoose
                    ? AppColors.error
                    : AppColors.textSecondary,
                fontSize: 11,
                fontWeight: accuracyTooLoose
                    ? FontWeight.w700
                    : FontWeight.w400,
              ),
            ),
          ],
        ),
        if (accuracyTooLoose &&
            accuracyMeters != null &&
            accuracyLimitMeters != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Sai số GPS ±${accuracyMeters!.toStringAsFixed(0)} m vượt ngưỡng '
              '${accuracyLimitMeters!.toStringAsFixed(0)} m của cửa hàng. '
              'Máy chủ có thể từ chối khi check-in; hãy đứng nơi thoáng rồi cập nhật vị trí.',
              style: const TextStyle(
                color: Color(0xFF946442),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        if (coordinatesLabel != null) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'GPS: $coordinatesLabel',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MapPainter extends CustomPainter {
  const _MapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = const Color(0xFFE9EFE8);
    canvas.drawRect(Offset.zero & size, background);

    final parkPaint = Paint()..color = const Color(0xFFD5E5D2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.66,
          size.height * 0.08,
          size.width * 0.28,
          size.height * 0.30,
        ),
        const Radius.circular(12),
      ),
      parkPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.04,
          size.height * 0.58,
          size.width * 0.24,
          size.height * 0.30,
        ),
        const Radius.circular(12),
      ),
      parkPaint,
    );

    final minorRoad = Paint()
      ..color = Colors.white
      ..strokeWidth = 9
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final roadPaths = [
      Path()
        ..moveTo(size.width * 0.08, size.height * 0.18)
        ..cubicTo(
          size.width * 0.30,
          size.height * 0.30,
          size.width * 0.60,
          size.height * 0.18,
          size.width * 0.95,
          size.height * 0.50,
        ),
      Path()
        ..moveTo(size.width * 0.16, size.height * 0.98)
        ..cubicTo(
          size.width * 0.35,
          size.height * 0.70,
          size.width * 0.60,
          size.height * 0.72,
          size.width * 0.88,
          size.height * 0.02,
        ),
      Path()
        ..moveTo(size.width * 0.02, size.height * 0.48)
        ..lineTo(size.width * 0.98, size.height * 0.72),
    ];
    for (final path in roadPaths) {
      canvas.drawPath(path, minorRoad);
    }

    final mainRoad = Paint()
      ..color = const Color(0xFFD8CCB5)
      ..strokeWidth = 15
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final mainRoadPath = Path()
      ..moveTo(size.width * 0.50, -10)
      ..cubicTo(
        size.width * 0.42,
        size.height * 0.30,
        size.width * 0.57,
        size.height * 0.66,
        size.width * 0.47,
        size.height + 10,
      );
    canvas.drawPath(mainRoadPath, mainRoad);
    canvas.drawPath(mainRoadPath, minorRoad..strokeWidth = 8);

    final labelPainter = TextPainter(
      text: const TextSpan(
        text: 'Đường Nguyễn Huệ',
        style: TextStyle(color: Color(0xFF718071), fontSize: 9),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    labelPainter.paint(canvas, Offset(size.width * 0.68, size.height * 0.52));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SelfiePreview extends StatelessWidget {
  const _SelfiePreview({
    required this.photoBytes,
    required this.isLoading,
    required this.onCapture,
  });

  final Uint8List? photoBytes;
  final bool isLoading;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoBytes != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 1.28,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (photoBytes != null)
                  Image.memory(photoBytes!, fit: BoxFit.cover)
                else
                  Container(
                    color: const Color(0xFFF0E8DF),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 43,
                          backgroundColor: Color(0xFFE2D0BF),
                          child: Icon(
                            Icons.person,
                            size: 56,
                            color: Color(0xFF76533E),
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Ảnh sẽ hiện sau khi chụp trực tiếp bằng camera.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF76533E),
                          ),
                        ),
                      ],
                    ),
                  ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: CustomPaint(painter: _FaceFramePainter()),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF76503A),
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: isLoading ? null : onCapture,
            icon: isLoading
                ? const SizedBox.square(
                    dimension: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(hasPhoto ? Icons.replay : Icons.photo_camera, size: 17),
            label: Text(hasPhoto ? 'Chụp lại' : 'Chụp ảnh'),
          ),
        ),
      ],
    );
  }
}

class _FaceFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const cornerLength = 20.0;
    final corners = [
      (Offset.zero, 1.0, 1.0),
      (Offset(size.width, 0), -1.0, 1.0),
      (Offset(0, size.height), 1.0, -1.0),
      (Offset(size.width, size.height), -1.0, -1.0),
    ];
    for (final corner in corners) {
      final origin = corner.$1;
      final horizontal = corner.$2;
      final vertical = corner.$3;
      canvas.drawLine(
        origin,
        origin.translate(horizontal * cornerLength, 0),
        paint,
      );
      canvas.drawLine(
        origin,
        origin.translate(0, vertical * cornerLength),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CheckStatus extends StatelessWidget {
  const _CheckStatus({required this.label, required this.isReady});

  final String label;
  final bool isReady;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isReady ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isReady ? AppColors.secondary : AppColors.textSecondary,
          size: 15,
        ),
        const SizedBox(width: 5),
        Text(
          '$label ${isReady ? 'đã sẵn sàng' : 'đang chờ'}',
          style: const TextStyle(fontSize: 11),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFECE9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE9B8B2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
