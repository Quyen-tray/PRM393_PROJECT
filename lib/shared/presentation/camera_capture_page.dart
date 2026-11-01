import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

class CameraCapturePage extends StatefulWidget {
  const CameraCapturePage({
    required this.preferredDirection,
    this.title = 'Chụp ảnh',
    this.instruction = 'Căn chỉnh hình ảnh rồi nhấn nút chụp.',
    super.key,
  });

  final CameraLensDirection preferredDirection;
  final String title;
  final String instruction;

  @override
  State<CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends State<CameraCapturePage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isInitializing = true;
  bool _isTakingPicture = false;
  String? _errorMessage;
  int _generation = 0;
  Future<void>? _initialization;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initializeCamera());
  }

  Future<void> _initializeCamera() async {
    final activeInitialization = _initialization;
    if (activeInitialization != null) return activeInitialization;

    final initialization = _initializeCameraOnce();
    _initialization = initialization;
    try {
      await initialization;
    } finally {
      if (identical(_initialization, initialization)) {
        _initialization = null;
      }
    }
  }

  Future<void> _initializeCameraOnce() async {
    final generation = ++_generation;
    if (mounted) {
      setState(() {
        _isInitializing = true;
        _errorMessage = null;
      });
    }

    CameraController? newController;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('NoCamera', 'Không tìm thấy camera trên thiết bị.');
      }

      final orderedCameras = [
        ...cameras.where(
          (camera) => camera.lensDirection == widget.preferredDirection,
        ),
        ...cameras.where(
          (camera) => camera.lensDirection != widget.preferredDirection,
        ),
      ];
      CameraException? lastCameraError;

      for (final camera in orderedCameras) {
        final candidate = CameraController(
          camera,
          ResolutionPreset.medium,
          enableAudio: false,
        );
        newController = candidate;
        try {
          await candidate.initialize();

          if (!mounted || generation != _generation) {
            await candidate.dispose();
            return;
          }

          setState(() => _controller = candidate);
          return;
        } on CameraException catch (error) {
          lastCameraError = error;
          await candidate.dispose();
          newController = null;

          // A permission failure applies to the camera API, so trying another
          // lens cannot help. Other failures may be specific to one device.
          if (_isPermissionError(error)) break;
          if (!mounted || generation != _generation) return;
        }
      }

      throw lastCameraError ??
          CameraException('CameraUnavailable', 'Không thể mở camera.');
    } on CameraException catch (error) {
      if (newController != null) await newController.dispose();
      if (mounted && generation == _generation) {
        setState(() => _errorMessage = _cameraErrorMessage(error));
      }
    } catch (_) {
      if (newController != null) await newController.dispose();
      if (mounted && generation == _generation) {
        setState(() => _errorMessage = 'Không thể mở camera. Hãy thử lại.');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _isInitializing = false);
      }
    }
  }

  String _cameraErrorMessage(CameraException error) {
    final code = error.code.toLowerCase();
    final description = error.description?.toLowerCase() ?? '';
    if (_isPermissionError(error)) {
      return 'Bạn chưa cấp quyền camera. Hãy cho phép camera rồi thử lại.';
    }
    if (code.contains('notreadable') || description.contains('hardware error')) {
      return 'Camera đang bận hoặc trình duyệt không truy cập được thiết bị. Hãy đóng ứng dụng đang dùng camera, kiểm tra quyền camera trong trình duyệt rồi thử lại.';
    }
    if (code.contains('notfound') || code.contains('nocamera')) {
      return 'Không tìm thấy camera. Hãy kết nối camera rồi thử lại.';
    }
    if (code.contains('security') || code.contains('secure')) {
      return 'Trình duyệt đang chặn camera. Hãy mở ứng dụng bằng HTTPS hoặc localhost và cấp quyền camera.';
    }
    return error.description ?? 'Không thể mở camera. Hãy thử lại.';
  }

  bool _isPermissionError(CameraException error) {
    final code = error.code.toLowerCase();
    return code.contains('denied') || code.contains('permission');
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _isTakingPicture) {
      return;
    }

    setState(() {
      _isTakingPicture = true;
      _errorMessage = null;
    });

    try {
      final image = await controller.takePicture();
      final bytes = await image.readAsBytes();
      if (mounted) Navigator.of(context).pop<Uint8List>(bytes);
    } on CameraException catch (error) {
      if (mounted) setState(() => _errorMessage = _cameraErrorMessage(error));
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Không thể chụp ảnh. Hãy thử lại.');
      }
    } finally {
      if (mounted) setState(() => _isTakingPicture = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // On web, Chrome can report `inactive` while the permission prompt is
    // open. Disposing during that transition can race camera initialization.
    if (kIsWeb && state == AppLifecycleState.inactive) return;

    final shouldReleaseCamera = state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        (!kIsWeb && state == AppLifecycleState.inactive);
    if (shouldReleaseCamera) {
      _generation++;
      final controller = _controller;
      _controller = null;
      if (controller != null) unawaited(controller.dispose());
      if (mounted) setState(() => _isInitializing = true);
    } else if (state == AppLifecycleState.resumed && _controller == null) {
      unawaited(_restoreCamera());
    }
  }

  Future<void> _restoreCamera() async {
    await _initializeCamera();
    // If a pending initialization was invalidated while the page was hidden,
    // start a fresh attempt after that request has fully settled.
    if (mounted && _controller == null) await _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    final controller = _controller;
    if (controller != null) unawaited(controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _isInitializing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : _errorMessage != null
                        ? _CameraErrorState(
                            message: _errorMessage!,
                            onRetry: _initializeCamera,
                          )
                        : controller == null || !controller.value.isInitialized
                            ? _CameraErrorState(
                                message: 'Camera chưa sẵn sàng.',
                                onRetry: _initializeCamera,
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: AspectRatio(
                                  aspectRatio: controller.value.aspectRatio,
                                  child: CameraPreview(controller),
                                ),
                              ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
              child: Column(
                children: [
                  Text(
                    widget.instruction,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    button: true,
                    label: 'Chụp ảnh trực tiếp',
                    child: IconButton.filled(
                      onPressed: controller != null &&
                              controller.value.isInitialized &&
                              !_isTakingPicture
                          ? _takePicture
                          : null,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.primary,
                        fixedSize: const Size(68, 68),
                      ),
                      icon: _isTakingPicture
                          ? const SizedBox.square(
                              dimension: 26,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.camera_alt, size: 30),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraErrorState extends StatelessWidget {
  const _CameraErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.no_photography_outlined, color: Colors.white70, size: 42),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }
}
