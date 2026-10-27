import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/router/route_names.dart';
import '../../../app/theme/app_colors.dart';

class EmployeeCheckInPage extends StatefulWidget {
  const EmployeeCheckInPage({super.key});

  @override
  State<EmployeeCheckInPage> createState() => _EmployeeCheckInPageState();
}

class _EmployeeCheckInPageState extends State<EmployeeCheckInPage> {
  static const _storeLatitude = 10.7769;
  static const _storeLongitude = 106.7009;
  static const _allowedRadiusMeters = 30.0;
  static const _maxAccuracyMeters = 25.0;

  Position? _position;
  Uint8List? _photoBytes;
  String? _errorMessage;
  bool _isLoadingLocation = false;
  bool _isLoadingPhoto = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLocation());
  }

  bool get _hasValidLocation {
    final position = _position;
    if (position == null) return false;

    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      _storeLatitude,
      _storeLongitude,
    );
    return distance <= _allowedRadiusMeters &&
        position.accuracy <= _maxAccuracyMeters;
  }

  double get _distanceMeters => _position == null
      ? 0
      : Geolocator.distanceBetween(
          _position!.latitude,
          _position!.longitude,
          _storeLatitude,
          _storeLongitude,
        );

  Future<void> _loadLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _errorMessage = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw const LocationServiceDisabledException();
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw PermissionDeniedException('Quyền vị trí chưa được cấp');
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      if (!mounted) return;
      setState(() => _position = position);
    } on LocationServiceDisabledException {
      _showError('GPS đang tắt. Hãy bật vị trí và thử lại.');
    } on PermissionDeniedException {
      _showError('Bạn cần cho phép truy cập vị trí để chấm công.');
    } catch (_) {
      _showError('Không thể lấy vị trí. Hãy di chuyển ra nơi thoáng rồi thử lại.');
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _takePhoto() async {
    setState(() {
      _isLoadingPhoto = true;
      _errorMessage = null;
    });

    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 78,
        maxWidth: 1600,
      );
      if (photo == null) return;

      final bytes = await photo.readAsBytes();
      if (!mounted) return;
      setState(() => _photoBytes = bytes);
    } catch (_) {
      _showError('Không thể mở camera. Hãy kiểm tra quyền truy cập camera.');
    } finally {
      if (mounted) setState(() => _isLoadingPhoto = false);
    }
  }

  Future<void> _submit() async {
    if (!_hasValidLocation) {
      setState(() => _errorMessage = 'Vị trí chưa thỏa điều kiện chấm công.');
      return;
    }
    if (_photoBytes == null) {
      setState(() => _errorMessage = 'Vui lòng chụp ảnh xác minh.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    setState(() => _isSubmitting = false);
    context.go(RouteNames.home);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã check-in thành công')),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _errorMessage = message);
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _hasValidLocation && _photoBytes != null && !_isSubmitting;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Quay lại',
          onPressed: () => context.go(RouteNames.home),
          icon: const Icon(Icons.arrow_back),
        ),
        centerTitle: true,
        title: const Text('Check-in'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  const _ShiftLabel(),
                  const SizedBox(height: 14),
                  _LocationPreview(
                    position: _position,
                    distanceMeters: _distanceMeters,
                    allowedRadiusMeters: _allowedRadiusMeters,
                    isLoading: _isLoadingLocation,
                    isValid: _hasValidLocation,
                    onRefresh: _loadLocation,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Text(
                        'Ảnh xác minh',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
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
                    onCapture: _takePhoto,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _photoBytes == null
                        ? 'Chụp rõ khuôn mặt để xác minh chấm công.'
                        : 'Ảnh xác minh đã sẵn sàng.',
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
              hasLocation: _hasValidLocation,
              hasPhoto: _photoBytes != null,
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _ShiftLabel extends StatelessWidget {
  const _ShiftLabel();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.access_time, size: 17, color: AppColors.textSecondary),
        const SizedBox(width: 7),
        const Expanded(
          child: Text(
            'Ca sáng · 07:00 - 15:00',
            style: TextStyle(fontWeight: FontWeight.w600),
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
    required this.position,
    required this.distanceMeters,
    required this.allowedRadiusMeters,
    required this.isLoading,
    required this.isValid,
    required this.onRefresh,
  });

  final Position? position;
  final double distanceMeters;
  final double allowedRadiusMeters;
  final bool isLoading;
  final bool isValid;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final statusColor = position == null
        ? AppColors.textSecondary
        : isValid
            ? const Color(0xFF287A48)
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
              position == null
                  ? Icons.gps_not_fixed
                  : isValid
                      ? Icons.check_circle
                      : Icons.location_off,
              color: statusColor,
              size: 17,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                position == null
                    ? 'Đang xác định vị trí GPS...'
                    : isValid
                        ? 'Trong phạm vi ${distanceMeters.toStringAsFixed(0)} m'
                        : 'Ngoài phạm vi ${allowedRadiusMeters.toStringAsFixed(0)} m',
                style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            if (position != null)
              Text(
                '±${position!.accuracy.toStringAsFixed(0)} m',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
          ],
        ),
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
                    Text('Canh khuôn mặt vào giữa khung hình', style: TextStyle(fontSize: 11, color: Color(0xFF76533E))),
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
                    : Icon(photoBytes == null ? Icons.photo_camera : Icons.replay, size: 17),
                label: Text(photoBytes == null ? 'Chụp ảnh' : 'Chụp lại'),
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

