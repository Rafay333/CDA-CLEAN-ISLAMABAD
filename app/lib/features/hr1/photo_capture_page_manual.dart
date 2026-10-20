import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

class PhotoCaptureResultManual {
  const PhotoCaptureResultManual({this.bytes, this.error});

  final Uint8List? bytes;
  final String? error;

  bool get cancelled => bytes == null && (error == null || error!.isEmpty);
}

/// One photo. Registration can use the front or back camera and requires one clear face.
class PhotoCapturePageManual extends StatefulWidget {
  const PhotoCapturePageManual({
    super.key,
    required this.title,
    required this.lens,
    required this.requireClearFace,
    required this.allowSwitch,
  });

  final String title;
  final CameraLensDirection lens;
  final bool requireClearFace;
  final bool allowSwitch;

  static Future<PhotoCaptureResultManual> open(
    BuildContext context, {
    required String title,
    required CameraLensDirection lens,
    required bool requireClearFace,
    bool allowSwitch = true,
  }) async {
    final result = await Navigator.of(context).push<PhotoCaptureResultManual>(
      MaterialPageRoute(
        builder: (_) => PhotoCapturePageManual(
          title: title,
          lens: lens,
          requireClearFace: requireClearFace,
          allowSwitch: allowSwitch,
        ),
      ),
    );
    return result ?? const PhotoCaptureResultManual();
  }

  @override
  State<PhotoCapturePageManual> createState() => _PhotoCapturePageManualState();
}

class _PhotoCapturePageManualState extends State<PhotoCapturePageManual> {
  CameraController? _camera;
  CameraLensDirection _lens = CameraLensDirection.front;
  String _info = 'Starting camera...';
  bool _busy = false;
  String? _blocked;

  @override
  void initState() {
    super.initState();
    _lens = widget.lens;
    _start(_lens);
  }

  @override
  void dispose() {
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _start(CameraLensDirection lens) async {
    final previous = _camera;
    _camera = null;
    await previous?.dispose();
    if (!mounted) return;
    setState(() {
      _info = 'Starting camera...';
      _blocked = null;
    });
    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) {
        setState(() => _blocked = 'No camera was found on this phone.');
        return;
      }
      final camera = cameras.cast<CameraDescription?>().firstWhere(
            (item) => item!.lensDirection == lens,
            orElse: () => cameras.first,
          )!;
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      try {
        await controller.setFocusMode(FocusMode.auto);
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {}
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = controller;
        _lens = camera.lensDirection;
        _info = widget.requireClearFace
            ? 'One clear face, filling the frame.'
            : 'Take one selfie.';
      });
    } on CameraException catch (error) {
      if (!mounted) return;
      final denied = error.code == 'CameraAccessDenied' || error.code == 'CameraAccessDeniedWithoutPrompt';
      setState(() {
        _blocked = denied
            ? 'Camera permission is required. Allow the camera and try again.'
            : 'The camera could not be started.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _blocked = 'The camera could not be started.');
    }
  }

  Future<void> _shoot() async {
    final camera = _camera;
    if (camera == null || _busy || !camera.value.isInitialized) return;
    setState(() {
      _busy = true;
      _info = widget.requireClearFace ? 'Checking the face...' : 'Saving the photo...';
    });
    try {
      final shot = await camera.takePicture();
      final bytes = await File(shot.path).readAsBytes();
      if (bytes.length < 1000) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _info = 'The photo was not taken. Try again.';
        });
        return;
      }
      if (widget.requireClearFace) {
        final problem = await _faceProblem(bytes);
        if (problem != null) {
          if (!mounted) return;
          setState(() {
            _busy = false;
            _info = problem;
          });
          return;
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop(PhotoCaptureResultManual(bytes: bytes));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _info = 'The photo was not taken. Try again.';
      });
    }
  }

  /// Returns a message when the photo should be retaken.
  /// A detector failure does not block saving: the camera file is still kept.
  Future<String?> _faceProblem(Uint8List bytes) async {
    File? probe;
    final detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.fast,
        minFaceSize: 0.08,
      ),
    );
    try {
      probe = await _faceProbe(bytes);
      if (probe == null) return null;
      final faces = await detector.processImage(InputImage.fromFilePath(probe.path));
      if (faces.isEmpty) {
        return 'No clear face found. Face the camera in good light and try again.';
      }
      if (faces.length > 1) {
        return 'More than one face is in the photo. Take it again with only this person.';
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      await detector.close();
      final file = probe;
      if (file != null) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
  }

  /// Smaller PNG for the face detector. The original JPEG is what gets uploaded.
  Future<File?> _faceProbe(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 640);
      final frame = await codec.getNextFrame();
      final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      codec.dispose();
      if (png == null || png.lengthInBytes < 100) return null;
      final file = File('${Directory.systemTemp.path}/hr-face-${DateTime.now().microsecondsSinceEpoch}.png');
      await file.writeAsBytes(
        png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
        flush: true,
      );
      return file;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(PhotoCaptureResultManual(error: _blocked)),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      style: AppType.section.copyWith(color: Colors.white, fontSize: 18),
                    ),
                  ),
                  if (widget.allowSwitch)
                    IconButton(
                      onPressed: _busy
                          ? null
                          : () => _start(
                                _lens == CameraLensDirection.front
                                    ? CameraLensDirection.back
                                    : CameraLensDirection.front,
                              ),
                      icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white),
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: _blocked != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _blocked!,
                          textAlign: TextAlign.center,
                          style: AppType.body.copyWith(color: Colors.white),
                        ),
                      ),
                    )
                  : camera == null || !camera.value.isInitialized
                      ? const Center(child: CircularProgressIndicator(color: Colors.white))
                      : ClipRect(
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: camera.value.previewSize?.height ?? 1,
                              height: camera.value.previewSize?.width ?? 1,
                              child: CameraPreview(camera),
                            ),
                          ),
                        ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                children: [
                  Text(
                    _info,
                    textAlign: TextAlign.center,
                    style: AppType.body.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  if (_blocked == null)
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.white,
                        foregroundColor: const Color(0xFF12304A),
                        minimumSize: const Size(160, 52),
                      ),
                      onPressed: _busy || camera == null ? null : _shoot,
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Take photo'),
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
