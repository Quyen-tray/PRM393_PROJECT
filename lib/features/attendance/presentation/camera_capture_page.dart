import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../../core/presentation/resource_widgets.dart';

class CameraCapturePage extends StatefulWidget {
  const CameraCapturePage({this.forChecklist = false, super.key});
  final bool forChecklist;
  @override
  State<CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends State<CameraCapturePage>
    with WidgetsBindingObserver {
  CameraController? controller;
  List<CameraDescription> cameras = [];
  int index = 0, generation = 0;
  bool busy = true;
  Object? error;
  Uint8List? photo;
  Future<void> _serial = Future.value();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initialize();
  }

  Future<void> initialize({bool switchCamera = false}) async {
    final request = ++generation;
    setState(() {
      busy = true;
      error = null;
    });
    _serial = _serial.catchError((_) {}).then((_) async {
      final old = controller;
      controller = null;
      await old?.dispose();
      if (!mounted || request != generation) return;
      try {
        cameras = await availableCameras();
        if (cameras.isEmpty) {
          throw CameraException(
              'NO_CAMERA', 'Không tìm thấy camera trên thiết bị.');
        }
        if (switchCamera) {
          index = (index + 1) % cameras.length;
        } else {
          final front = cameras.indexWhere((c) =>
              c.lensDirection ==
              (widget.forChecklist
                  ? CameraLensDirection.back
                  : CameraLensDirection.front));
          index = front < 0 ? 0 : front;
        }
        final next = CameraController(cameras[index], ResolutionPreset.medium,
            enableAudio: false);
        await next.initialize();
        if (!mounted || request != generation) {
          await next.dispose();
          return;
        }
        controller = next;
        setState(() => busy = false);
      } catch (e) {
        if (mounted && request == generation) {
          setState(() {
            busy = false;
            error = e;
          });
        }
      }
    });
    await _serial;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      generation++;
      final old = controller;
      controller = null;
      _serial = _serial.catchError((_) {}).then((_) async {
        await old?.dispose();
      });
    }
    if (state == AppLifecycleState.resumed && photo == null) initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    generation++;
    final old = controller;
    controller = null;
    _serial = _serial.catchError((_) {}).then((_) async {
      await old?.dispose();
    });
    super.dispose();
  }

  Future<void> capture() async {
    if (busy || controller == null) return;
    setState(() => busy = true);
    try {
      final file = await controller!.takePicture();
      final bytes = await file.readAsBytes();
      if (mounted) setState(() => photo = bytes);
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(widget.forChecklist
              ? 'Ảnh minh chứng công việc'
              : 'Ảnh chấm công'),
          actions: [
            if (photo == null && cameras.length > 1)
              IconButton(
                  tooltip: 'Đổi camera',
                  onPressed: busy ? null : () => initialize(switchCamera: true),
                  icon: const Icon(Icons.cameraswitch_outlined))
          ]),
      body: SafeArea(
          child: Column(children: [
        Expanded(
            child: Center(
                child: photo != null
                    ? Image.memory(photo!, fit: BoxFit.contain)
                    : controller?.value.isInitialized == true
                        ? AspectRatio(
                            aspectRatio: controller!.value.aspectRatio,
                            child: CameraPreview(controller!))
                        : busy
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : error != null
                                ? Padding(
                                    padding: const EdgeInsets.all(20),
                                    child:
                                        ErrorPanel(error!, retry: initialize))
                                : const SizedBox.shrink())),
        if (error != null && controller != null)
          Padding(padding: const EdgeInsets.all(12), child: ErrorPanel(error!)),
        Padding(
            padding: EdgeInsets.all(16),
            child: Text(
                widget.forChecklist
                    ? 'Chụp rõ khu vực và kết quả công việc để quản lý kiểm tra.'
                    : 'Chụp rõ mặt để lưu bằng chứng chấm công.',
                style: const TextStyle(color: Colors.white70))),
        Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: photo == null
                ? FilledButton.tonalIcon(
                    onPressed: busy ? null : capture,
                    icon: busy
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.camera_alt, size: 32),
                    label: Text(busy ? 'Đang chụp…' : 'Chụp ảnh'))
                : Wrap(spacing: 16, children: [
                    OutlinedButton(
                        onPressed: () => setState(() => photo = null),
                        child: const Text('Chụp lại',
                            style: TextStyle(color: Colors.white))),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, photo),
                        child: const Text('Dùng ảnh này'))
                  ])),
      ])));
}
