import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart' show CameraLensDirection;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';
import '../../../data/mock/demo_data.dart';
import '../../../shared/presentation/camera_capture_page.dart';

class EmployeeCheckInPage extends StatefulWidget {
  const EmployeeCheckInPage({super.key});

  @override
  State<EmployeeCheckInPage> createState() => _EmployeeCheckInPageState();
}

class _EmployeeCheckInPageState extends State<EmployeeCheckInPage> {
  static const _maxAccuracyMeters = 25.0;

  Position? _position;
  Uint8List? _photoBytes;
  String? _errorMessage;
  bool _isLoadingLocation = false;
  bool _isLoadingPhoto = false;
  bool _isSubmitting = false;

  bool get _hasGpsFix => _position != null;

  double? get _distanceMeters {
    final position = _position;
    if (position == null) return null;
    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      DemoData.storeLatitude,
      DemoData.storeLongitude,
    );
  }

  bool get _hasValidLocation {
    final position = _position;
    final distance = _distanceMeters;
    return position != null &&
        distance != null &&
        distance <= DemoData.attendancePolicy.storeRadiusMeters &&
        position.accuracy <= _maxAccuracyMeters;
  }

  String get _locationMessage {
    final position = _position;
    final distance = _distanceMeters;
    if (_isLoadingLocation) return 'Đang xác định vị trí GPS...';
    if (position == null || distance == null) return 'Chưa lấy được vị trí GPS';
    if (position.accuracy > _maxAccuracyMeters) {
      return 'Sai số GPS quá lớn (${position.accuracy.toStringAsFixed(0)} m)';
    }
    if (_hasValidLocation) {
      return 'Trong khu vực cửa hàng (${distance.toStringAsFixed(0)} m)';
    }
    return 'Ngoài bán kính cửa hàng (${distance.toStringAsFixed(0)} m)';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refreshLocation());
    });
  }

  Future<void> _refreshLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _position = null;
      _errorMessage = null;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const FormatException('Bật dịch vụ định vị của thiết bị rồi thử lại.');
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
          throw const FormatException('Cần cấp quyền vị trí để check-in.');
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
        setState(() => _errorMessage = kIsWeb
            ? 'Chrome chưa trả vị trí. Hãy cho phép vị trí cho trang web; nếu đang giả lập điện thoại, đặt vị trí trong DevTools > Sensors > Location rồi cập nhật lại.'
            : 'Điện thoại chưa trả vị trí. Hãy bật dịch vụ vị trí, cấp quyền cho ứng dụng rồi thử cập nhật ở nơi thoáng.');
      }
    } on LocationServiceDisabledException {
      if (mounted) {
        setState(() => _errorMessage = 'Dịch vụ định vị đang tắt. Hãy bật GPS.');
      }
    } on PermissionDeniedException {
      if (mounted) {
        setState(() => _errorMessage = kIsWeb
            ? 'Bạn cần cho phép vị trí cho trang web trong Chrome để check-in.'
            : 'Bạn cần cấp quyền vị trí cho ứng dụng trong cài đặt Android để check-in.');
      }
    } on FormatException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message.toString());
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Không thể lấy GPS. Hãy thử cập nhật lại.');
      }
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _capturePhoto() async {
    setState(() {
      _isLoadingPhoto = true;
      _errorMessage = null;
    });

    try {
      final photo = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(
          builder: (_) => const CameraCapturePage(
            preferredDirection: CameraLensDirection.front,
            title: 'Ảnh xác minh',
            instruction: 'Đưa khuôn mặt vào giữa khung hình rồi chụp.',
          ),
        ),
      );
      if (!mounted) return;
      if (photo != null) setState(() => _photoBytes = photo);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Không thể mở camera để chụp ảnh.');
      }
    } finally {
      if (mounted) setState(() => _isLoadingPhoto = false);
    }
  }

  Future<void> _submit() async {
    final position = _position;
    final distance = _distanceMeters;
    if (position == null) {
      setState(() => _errorMessage = 'Hãy lấy vị trí GPS thật trước khi check-in.');
      return;
    }
    if (position.accuracy > _maxAccuracyMeters) {
      setState(() => _errorMessage =
          'Sai số GPS là ${position.accuracy.toStringAsFixed(0)} m; cần không quá ${_maxAccuracyMeters.toStringAsFixed(0)} m.');
      return;
    }
    if (distance == null ||
        distance > DemoData.attendancePolicy.storeRadiusMeters) {
      setState(() => _errorMessage =
          'Bạn đang ngoài bán kính ${DemoData.attendancePolicy.storeRadiusMeters} m của cửa hàng.');
      return;
    }
    if (_photoBytes == null) {
      setState(() => _errorMessage = 'Hãy chụp ảnh xác minh bằng camera.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    setState(() => _isSubmitting = false);
    context.go(RouteNames.employeeHome);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã check-in thành công')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _hasValidLocation &&
        _photoBytes != null &&
        !_isLoadingLocation &&
        !_isLoadingPhoto &&
        !_isSubmitting;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Quay lại',
          onPressed: () => context.go(RouteNames.employeeHome),
          icon: const Icon(Icons.arrow_back),
        ),
        centerTitle: true,
        title: const Text('Check-in'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [
                      _ShiftLabel(shift: DemoData.currentShift),
                      const SizedBox(height: 14),
                      _LocationPreview(
                        accuracyMeters: _position?.accuracy,
                        isLoading: _isLoadingLocation,
                        hasGpsFix: _hasGpsFix,
                        isValid: _hasValidLocation,
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
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
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
                        isLoading: _isLoadingPhoto,
                        onCapture: _capturePhoto,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _photoBytes == null
                            ? 'Chưa có ảnh. Hãy chụp trực tiếp bằng camera.'
                            : 'Ảnh xác minh đã chụp trực tiếp.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        _ErrorBanner(message: _errorMessage!),
                      ],
                    ],
                  ),
                ),
                _CheckInFooter(
                  canSubmit: canSubmit,
                  isSubmitting: _isSubmitting,
                  hasLocation: _hasGpsFix,
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

class _ShiftLabel extends StatelessWidget {
  const _ShiftLabel({required this.shift});

  final DemoShiftAssignment shift;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.access_time, size: 17, color: AppColors.textSecondary),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            '${shift.shiftName} · ${shift.startTime} - ${shift.endTime}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1D9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'Chưa check-in',
            style: TextStyle(color: Color(0xFF946442), fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _LocationPreview extends StatelessWidget {
  const _LocationPreview({
    required this.accuracyMeters,
    required this.isLoading,
    required this.hasGpsFix,
    required this.isValid,
    required this.statusMessage,
    required this.coordinatesLabel,
    required this.onRefresh,
  });

  final double? accuracyMeters;
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.storefront_outlined, size: 15, color: AppColors.primary),
                        SizedBox(width: 6),
                        Text('HRM Coffee Shop', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
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
                style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              accuracyMeters == null
                  ? '±-- m'
                  : '±${accuracyMeters!.toStringAsFixed(0)} m',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ],
        ),
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
        Rect.fromLTWH(size.width * 0.66, size.height * 0.08, size.width * 0.28, size.height * 0.30),
        const Radius.circular(12),
      ),
      parkPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.04, size.height * 0.58, size.width * 0.24, size.height * 0.30),
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
        ..cubicTo(size.width * 0.30, size.height * 0.30, size.width * 0.60, size.height * 0.18, size.width * 0.95, size.height * 0.50),
      Path()
        ..moveTo(size.width * 0.16, size.height * 0.98)
        ..cubicTo(size.width * 0.35, size.height * 0.70, size.width * 0.60, size.height * 0.72, size.width * 0.88, size.height * 0.02),
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
      ..cubicTo(size.width * 0.42, size.height * 0.30, size.width * 0.57, size.height * 0.66, size.width * 0.47, size.height + 10);
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
    return AspectRatio(
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
                      child: Icon(Icons.person, size: 56, color: Color(0xFF76533E)),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Ảnh sẽ hiện sau khi chụp trực tiếp bằng camera.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF76533E)),
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
            Positioned(
              right: 10,
              bottom: 10,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF76503A),
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: isLoading ? null : onCapture,
                icon: isLoading
                    ? const SizedBox.square(dimension: 17, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(hasPhoto ? Icons.replay : Icons.photo_camera, size: 17),
                label: Text(hasPhoto ? 'Chụp lại' : 'Chụp ảnh'),
              ),
            ),
          ],
        ),
      ),
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
      canvas.drawLine(origin, origin.translate(horizontal * cornerLength, 0), paint);
      canvas.drawLine(origin, origin.translate(0, vertical * cornerLength), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CheckInFooter extends StatelessWidget {
  const _CheckInFooter({
    required this.canSubmit,
    required this.isSubmitting,
    required this.hasLocation,
    required this.hasPhoto,
    required this.onSubmit,
  });

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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: canSubmit ? onSubmit : null,
                child: isSubmitting
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Xác nhận check-in', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
        Text('$label ${isReady ? 'đã sẵn sàng' : 'đang chờ'}', style: const TextStyle(fontSize: 11)),
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
          Expanded(child: Text(message, style: const TextStyle(color: AppColors.error))),
        ],
      ),
    );
  }
}

